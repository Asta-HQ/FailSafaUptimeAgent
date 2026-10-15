import * as esbuild from 'esbuild'
import * as fs from 'fs'
import * as path from 'path'

const args = process.argv.slice(2)
const isRelease = args.includes('--release')
const isDebug = args.includes('--debug')

async function main() {
  if (isDebug) {
    console.log('Starting debug build...')
    
    await esbuild.build({
      entryPoints: ['src/index.ts'],
      bundle: true,
      platform: 'node',
      target: ['node20'],
      sourcemap: true,
      outfile: 'dist/debug/bundle.js',
    })
    
    console.log('Debug build successful: dist/debug/bundle.js (including sourcemap)')
    
  } else if (isRelease) {
    console.log('Starting release build for multiple platforms...')

    fs.mkdirSync('dist/release', { recursive: true })

    // 1. Windows Release
    await esbuild.build({
      entryPoints: ['src/index.ts'],
      bundle: true,
      platform: 'node',
      target: ['node20'],
      minify: true,
      outfile: 'dist/release/app-win.exe',
    })
    console.log('Windows build created: dist/release/app-win.exe')

    // 2. Linux x64 Release
    await esbuild.build({
      entryPoints: ['src/index.ts'],
      bundle: true,
      platform: 'node',
      target: ['node20'],
      minify: true,
      outfile: 'dist/release/app-linux-x64.bin',
      banner: { js: '#!/usr/bin/env node\n' },
    })
    console.log('Linux x64 build created: dist/release/app-linux-x64.bin')

    // 3. Linux ARM64 Release
    await esbuild.build({
      entryPoints: ['src/index.ts'],
      bundle: true,
      platform: 'node',
      target: ['node20'],
      minify: true,
      outfile: 'dist/release/app-linux-arm64.bin',
      banner: { js: '#!/usr/bin/env node\n' },
    })
    console.log('Linux ARM64 build created: dist/release/app-linux-arm64.bin')

    console.log('All release builds completed successfully!')
    
  } else {
    console.log('Please specify a mode: npx ts-node build.ts --debug OR --release')
  }
}

main().catch((err) => {
  console.error('Build failed:', err)
  process.exit(1)
})