#!/bin/bash

# Script untuk build LADIMAS App
# Usage: ./build.sh [debug|release|bundle]

echo "=== LADIMAS Build Script ==="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter tidak ditemukan. Pastikan Flutter sudah terinstall."
    exit 1
fi

# Check Flutter doctor
echo "Checking Flutter environment..."
flutter doctor

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean
flutter pub get

# Build based on argument
case $1 in
    "debug")
        echo "Building debug APK..."
        flutter build apk --debug
        echo "Debug APK tersedia di: build/app/outputs/flutter-apk/app-debug.apk"
        ;;
    "release")
        echo "Building release APK..."
        flutter build apk --release
        echo "Release APK tersedia di: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    "bundle")
        echo "Building App Bundle untuk Play Store..."
        flutter build appbundle --release
        echo "App Bundle tersedia di: build/app/outputs/bundle/release/app-release.aab"
        ;;
    *)
        echo "Usage: $0 [debug|release|bundle]"
        echo "  debug   - Build APK debug untuk testing"
        echo "  release - Build APK release untuk testing"
        echo "  bundle  - Build App Bundle untuk Play Store"
        exit 1
        ;;
esac

echo "Build selesai!"
