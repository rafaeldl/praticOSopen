#!/bin/bash
# run-visual-tests.sh - Run visual tests with Maestro
# Usage: ./scripts/run-visual-tests.sh [--platform ios|android] [--flow flow_name]
#
# Examples:
#   ./scripts/run-visual-tests.sh                    # Run all flows on iOS
#   ./scripts/run-visual-tests.sh --platform android # Run all flows on Android
#   ./scripts/run-visual-tests.sh --flow 02_plans_screen # Run specific flow

set -e

# Default values
PLATFORM="ios"
FLOW=""
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAESTRO_DIR="$PROJECT_ROOT/.maestro"
SCREENSHOT_DIR="$MAESTRO_DIR/screenshots"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --flow)
            FLOW="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --platform ios|android   Target platform (default: ios)"
            echo "  --flow FLOW_NAME         Run specific flow (e.g., 02_plans_screen)"
            echo "  --help                   Show this help"
            echo ""
            echo "Available flows:"
            ls -1 "$MAESTRO_DIR/flows"/*.yaml 2>/dev/null | xargs -I {} basename {} .yaml
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check Maestro installation
check_maestro() {
    if ! command -v maestro &> /dev/null; then
        print_warn "Maestro not installed. Installing..."
        curl -Ls "https://get.maestro.mobile.dev" | bash
        export PATH="$HOME/.maestro/bin:$PATH"

        if ! command -v maestro &> /dev/null; then
            print_error "Failed to install Maestro. Please install manually:"
            echo "  curl -Ls 'https://get.maestro.mobile.dev' | bash"
            exit 1
        fi
    fi
    print_info "Maestro version: $(maestro --version)"
}

# Build Flutter app
build_app() {
    print_step "Building Flutter app for $PLATFORM..."

    cd "$PROJECT_ROOT"

    if [ "$PLATFORM" == "ios" ]; then
        flutter build ios --simulator --debug
    else
        flutter build apk --debug
    fi

    print_info "Build complete!"
}

# Install app
install_app() {
    print_step "Installing app on $PLATFORM..."

    cd "$PROJECT_ROOT"

    if [ "$PLATFORM" == "ios" ]; then
        # Get simulator UDID
        DEVICE_UDID=$(xcrun simctl list devices booted | grep -oE "[0-9A-F-]{36}" | head -1)

        if [ -z "$DEVICE_UDID" ]; then
            print_error "No iOS simulator running. Start one first:"
            echo "  ./scripts/start-emulator.sh ios"
            exit 1
        fi

        # Install app
        APP_PATH="build/ios/iphonesimulator/Runner.app"
        if [ -d "$APP_PATH" ]; then
            xcrun simctl install booted "$APP_PATH"
            print_info "App installed on iOS simulator"
        else
            print_error "App not found at $APP_PATH. Build first."
            exit 1
        fi
    else
        # Android
        if ! adb devices | grep -q "device$"; then
            print_error "No Android device/emulator connected. Start one first:"
            echo "  ./scripts/start-emulator.sh android"
            exit 1
        fi

        APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
        if [ -f "$APK_PATH" ]; then
            adb install -r "$APK_PATH"
            print_info "App installed on Android"
        else
            print_error "APK not found at $APK_PATH. Build first."
            exit 1
        fi
    fi
}

# Run Maestro tests
run_tests() {
    print_step "Running visual tests..."

    cd "$PROJECT_ROOT"

    # Create screenshot directory
    mkdir -p "$SCREENSHOT_DIR"

    # Set environment variables
    export DEMO_EMAIL="demo-pt@praticos.com.br"
    export DEMO_PASSWORD="Demo@2024!"

    if [ -n "$FLOW" ]; then
        # Run specific flow
        FLOW_FILE="$MAESTRO_DIR/flows/${FLOW}.yaml"
        if [ ! -f "$FLOW_FILE" ]; then
            print_error "Flow not found: $FLOW_FILE"
            exit 1
        fi
        print_info "Running flow: $FLOW"
        maestro test "$FLOW_FILE" --output "$SCREENSHOT_DIR"
    else
        # Run all flows
        print_info "Running all flows..."
        maestro test "$MAESTRO_DIR/flows/" --output "$SCREENSHOT_DIR"
    fi

    print_info "Tests complete! Screenshots saved to: $SCREENSHOT_DIR"
}

# List screenshots
list_screenshots() {
    print_step "Screenshots captured:"
    echo ""
    ls -la "$SCREENSHOT_DIR"/*.png 2>/dev/null || echo "No screenshots found"
}

# Main
main() {
    echo ""
    echo "=========================================="
    echo "  PraticOS Visual Test Runner"
    echo "=========================================="
    echo "Platform: $PLATFORM"
    echo "Flow: ${FLOW:-all}"
    echo ""

    check_maestro

    # Check if app is already installed or needs build
    read -p "Build and install app? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        build_app
        install_app
    fi

    run_tests
    list_screenshots

    echo ""
    print_info "Done! Review screenshots in: $SCREENSHOT_DIR"
}

main
