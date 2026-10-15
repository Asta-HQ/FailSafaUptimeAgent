#!/usr/bin/env bash
set -e

mkdir -p dist
SRC_PATH="src/main.go"
BINARY_NAME="failsafe_agent"

# Hier kannst du deine feste Server-IP / Domain definieren, die einkompiliert wird
TARGET_IP="${FAILSAFE_AGENT_SERVER:-localhost:4400}"

if [ "$1" == "--release" ]; then
    echo "Building release binaries for multiple platforms (Target IP: $TARGET_IP)..."

    LDFLAGS="-X main.DefaultServerIP=$TARGET_IP -s -w"

    echo "-> Building for Linux (amd64)..."
    GOOS=linux GOARCH=amd64 go build -ldflags="$LDFLAGS" -o dist/${BINARY_NAME}-linux-amd64 $SRC_PATH

    echo "-> Building for Linux (arm64)..."
    GOOS=linux GOARCH=arm64 go build -ldflags="$LDFLAGS" -o dist/${BINARY_NAME}-linux-arm64 $SRC_PATH

    echo "-> Building for Windows (amd64)..."
    GOOS=windows GOARCH=amd64 go build -ldflags="$LDFLAGS" -o dist/${BINARY_NAME}-windows-amd64.exe $SRC_PATH

    echo "All binaries built in dist/"

elif [ "$1" == "--debug" ]; then
    echo "Building for local debug (Target IP: $TARGET_IP)..."
    OUTPUT_PATH="dist/${BINARY_NAME}"
    
    go build -ldflags="-X main.DefaultServerIP=$TARGET_IP" -o $OUTPUT_PATH $SRC_PATH

    echo "Build complete. Running ${OUTPUT_PATH}..."
    exec $OUTPUT_PATH --token "609f5deb-d92e-4ee1-b188-b86eca8489e4"

else
    echo "Usage: [FAILSAFE_AGENT_SERVER=123.45.67.89:4400] ./tool.sh [--release | --debug]"
    exit 1
fi