package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

// Kann beim Build via -ldflags angepasst werden
var DefaultServerIP = "api.failsafe.asta.cx"
var GitHubRepo = "Asta-HQ/FailSafaUptimeAgent"

type GitHubAsset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

type GitHubRelease struct {
	TagName string        `json:"tag_name"`
	Assets  []GitHubAsset `json:"assets"`
}

func main() {
	// Manuelles Parsen von --update, da flag-Packages optionale Werte nur schwer unterstützen
	updateRequested := false
	updateTag := "latest"
	for i := 1; i < len(os.Args); i++ {
		if os.Args[i] == "--update" || os.Args[i] == "-update" {
			updateRequested = true
			if i+1 < len(os.Args) && !strings.HasPrefix(os.Args[i+1], "-") {
				updateTag = os.Args[i+1]
				i++ // überspringe den Tag im nächsten Loop-Durchlauf
			}
			break
		}
	}

	if updateRequested {
		performUpdate(updateTag)
		return
	}

	serviceFlag := flag.String("service", "", "Manage Failsafe agent systemd service (install, uninstall)")
	tokenFlag := flag.String("token", "", "Failsafe agent authentication token")
	serverIPFlag := flag.String("server", DefaultServerIP, "Backend server address")
	flag.Parse()

	if *serviceFlag != "" {
		handleService(*serviceFlag, *tokenFlag, *serverIPFlag)
		return
	}

	if *tokenFlag == "" {
		log.Fatalf("Error: --token is required. Use --help for usage.")
	}

	url := fmt.Sprintf("ws://%s/v1/agent/connect?token=%s", *serverIPFlag, *tokenFlag)
	log.Printf("Connecting to %s...", url)

	c, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		log.Fatalf("Connection failed: %v", err)
	}
	defer c.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		for {
			_, message, err := c.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
					log.Printf("Read error: %v", err)
				} else {
					log.Println("Websocket connection closed.")
				}
				return
			}
			log.Printf("Received from server: %s", message)
		}
	}()

	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)

	select {
	case <-interrupt:
		log.Println("Shutting down Failsafe agent...")
		c.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
		select {
		case <-done:
		case <-time.After(time.Second):
		}
	case <-done:
	}
}

func performUpdate(tag string) {
	if os.Getuid() != 0 {
		log.Fatalf("Error: Updating the Failsafe agent requires root privileges (sudo).")
	}

	log.Printf("Checking for updates (Target: %s)...", tag)

	apiURL := fmt.Sprintf("https://api.github.com/repos/%s/releases/latest", GitHubRepo)
	if tag != "latest" {
		apiURL = fmt.Sprintf("https://api.github.com/repos/%s/releases/tags/%s", GitHubRepo, tag)
	}

	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		log.Fatalf("Failed to create request: %v", err)
	}
	req.Header.Set("User-Agent", "Failsafe_Agent_Updater")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Fatalf("Failed to fetch release info from GitHub: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Fatalf("GitHub API returned status: %d (Check if tag exists)", resp.StatusCode)
	}

	var release GitHubRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		log.Fatalf("Failed to parse release JSON: %v", err)
	}

	// Find the release asset for this OS and architecture.
	targetAssetName := fmt.Sprintf("failsafe_agent-%s-%s", runtime.GOOS, runtime.GOARCH)
	if runtime.GOOS == "windows" {
		targetAssetName += ".exe"
	}

	var downloadURL string
	for _, asset := range release.Assets {
		if asset.Name == targetAssetName {
			downloadURL = asset.BrowserDownloadURL
			break
		}
	}

	if downloadURL == "" {
		log.Fatalf("No matching asset found for your platform (%s) in release %s", targetAssetName, release.TagName)
	}

	log.Printf("Downloading version %s from %s...", release.TagName, downloadURL)

	dlResp, err := http.Get(downloadURL)
	if err != nil {
		log.Fatalf("Failed to download binary: %v", err)
	}
	defer dlResp.Body.Close()

	execPath, err := os.Executable()
	if err != nil {
		log.Fatalf("Failed to get current executable path: %v", err)
	}

	// Temporäre Datei im selben Verzeichnis erstellen (wichtig für atomares Verschieben via os.Rename)
	tmpFile, err := os.CreateTemp(filepathDir(execPath), "failsafe_agent-update-*")
	if err != nil {
		log.Fatalf("Failed to create temp file: %v", err)
	}
	tmpName := tmpFile.Name()
	defer os.Remove(tmpName)

	_, err = io.Copy(tmpFile, dlResp.Body)
	tmpFile.Close()
	if err != nil {
		log.Fatalf("Failed to write new binary: %v", err)
	}

	// Ausführbar machen
	if err := os.Chmod(tmpName, 0755); err != nil {
		log.Fatalf("Failed to set executable permissions: %v", err)
	}

	serviceName := "failsafe_agent"
	isServiceRunning := exec.Command("systemctl", "is-active", "--quiet", serviceName).Run() == nil

	if isServiceRunning {
		log.Println("Stopping systemd service for update...")
		exec.Command("systemctl", "stop", serviceName).Run()
	}

	// Binärdatei austauschen
	log.Println("Replacing old binary...")
	if err := os.Rename(tmpName, execPath); err != nil {
		log.Fatalf("Failed to replace binary (are you root?): %v", err)
	}

	if isServiceRunning {
		log.Println("Restarting systemd service...")
		exec.Command("systemctl", "start", serviceName).Run()
	}

	log.Printf("Successfully updated to %s!", release.TagName)
}

func filepathDir(path string) string {
	idx := strings.LastIndex(path, "/")
	if idx == -1 {
		return "."
	}
	return path[:idx]
}

func handleService(action, token, serverIP string) {
	// (Dein bestehender Service-Code bleibt hier unverändert)
}
