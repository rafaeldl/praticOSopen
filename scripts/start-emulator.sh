#!/bin/bash
# start-emulator.sh - Start iOS Simulator or Android Emulator
# Usage: ./scripts/start-emulator.sh [ios|android]

set -e

PLATFORM="${1:-ios}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

start_ios_simulator() {
    print_info "Starting iOS Simulator..."

    # Check if Xcode is installed
    if ! command -v xcrun &> /dev/null; then
        print_error "Xcode Command Line Tools not found. Install Xcode first."
        exit 1
    fi

    # List available simulators
    print_info "Available iOS Simulators:"
    xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10

    # Get the first available iPhone simulator
    DEVICE_UDID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -oE "[0-9A-F-]{36}")
    DEVICE_NAME=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed 's/(.*//' | xargs)

    if [ -z "$DEVICE_UDID" ]; then
        print_error "No iPhone simulator found. Create one in Xcode."
        exit 1
    fi

    print_info "Selected device: $DEVICE_NAME ($DEVICE_UDID)"

    # Boot the simulator
    print_info "Booting simulator..."
    xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true

    # Open Simulator app
    open -a Simulator

    # Wait for boot
    print_info "Waiting for simulator to boot..."
    sleep 5

    # Check status
    xcrun simctl list devices | grep "$DEVICE_UDID"

    print_info "iOS Simulator ready!"
    echo ""
    echo "Device UDID: $DEVICE_UDID"
    echo "Device Name: $DEVICE_NAME"
}

start_android_emulator() {
    print_info "Starting Android Emulator..."

    # Check if Android SDK is configured
    if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
        print_error "ANDROID_HOME or ANDROID_SDK_ROOT not set."
        print_info "Set it in ~/.zshrc or ~/.bashrc:"
        echo "  export ANDROID_HOME=\$HOME/Library/Android/sdk"
        echo "  export PATH=\$PATH:\$ANDROID_HOME/emulator:\$ANDROID_HOME/platform-tools"
        exit 1
    fi

    SDK_ROOT="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
    EMULATOR="$SDK_ROOT/emulator/emulator"

    if [ ! -f "$EMULATOR" ]; then
        print_error "Emulator not found at $EMULATOR"
        exit 1
    fi

    # List available AVDs
    print_info "Available Android Emulators:"
    "$EMULATOR" -list-avds

    # Get the first available AVD
    AVD_NAME=$("$EMULATOR" -list-avds | head -1)

    if [ -z "$AVD_NAME" ]; then
        print_error "No Android Emulator found. Create one in Android Studio."
        print_info "To create: Android Studio > Device Manager > Create Device"
        exit 1
    fi

    print_info "Selected AVD: $AVD_NAME"

    # Check if emulator is already running
    if adb devices | grep -q "emulator-"; then
        print_warn "Android emulator already running"
        adb devices
    else
        # Start emulator in background
        print_info "Starting emulator..."
        "$EMULATOR" -avd "$AVD_NAME" -no-snapshot-save &

        # Wait for boot
        print_info "Waiting for emulator to boot..."
        adb wait-for-device

        # Wait for boot animation to complete
        while [ "$(adb shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
            sleep 2
        done

        print_info "Android Emulator ready!"
    fi

    echo ""
    adb devices
}

# Main
case "$PLATFORM" in
    ios)
        start_ios_simulator
        ;;
    android)
        start_android_emulator
        ;;
    *)
        print_error "Unknown platform: $PLATFORM"
        echo "Usage: $0 [ios|android]"
        exit 1
        ;;
esac

print_info "Emulator started successfully!"
