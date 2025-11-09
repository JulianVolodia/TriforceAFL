#!/bin/bash
#
# TriforceAFL Setup Script for macOS
# This script sets up TriforceAFL for full-system fuzzing on macOS
#
# Usage: ./setup_macos.sh
#
# Note: This script is designed for security researchers conducting authorized
# vulnerability research. Always obtain proper authorization before testing.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This script is designed for macOS only!"
    exit 1
fi

print_status "TriforceAFL macOS Setup Script"
echo "================================"
echo ""

# Check for Xcode Command Line Tools
print_status "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
    print_warning "Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    echo ""
    print_warning "Please complete the Xcode Command Line Tools installation"
    print_warning "and run this script again."
    exit 1
else
    print_status "Xcode Command Line Tools found: $(xcode-select -p)"
fi

# Check for Homebrew
print_status "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_status "Homebrew found: $(brew --version | head -1)"
fi

# Install dependencies
print_status "Installing dependencies via Homebrew..."
DEPS=(
    "libtool"
    "automake"
    "pkg-config"
    "glib"
    "pixman"
    "gnu-sed"
    "coreutils"
)

for dep in "${DEPS[@]}"; do
    if brew list "$dep" &>/dev/null; then
        print_status "$dep already installed"
    else
        print_status "Installing $dep..."
        brew install "$dep"
    fi
done

# Disable macOS crash reporting (CRITICAL for fuzzing)
print_status "Configuring macOS for fuzzing..."
print_warning "Disabling crash reporting (required for AFL to work properly)..."

# Check current CrashReporter state
CRASH_REPORTER_STATE=$(launchctl list | grep -i crashreporter || echo "not running")

if [[ "$CRASH_REPORTER_STATE" != "not running" ]]; then
    print_warning "CrashReporter is running. To disable it, run:"
    echo ""
    echo "  sudo launchctl unload -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist"
    echo "  sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist"
    echo ""
    echo "To re-enable after fuzzing:"
    echo "  sudo launchctl load -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist"
    echo "  sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist"
    echo ""

    read -p "Disable crash reporter now? (requires sudo) [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo launchctl unload -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist 2>/dev/null || true
        sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist 2>/dev/null || true
        print_status "Crash reporter disabled"
    fi
fi

# Set CPU performance mode
print_status "Setting CPU to performance mode..."
print_warning "Note: macOS doesn't have the same CPU governor controls as Linux"
print_warning "Ensure your Mac has adequate cooling and is plugged into power"

# Build AFL
print_status "Building TriforceAFL..."
cd "$(dirname "$0")"

# Use clang (macOS default)
export CC=clang
export CXX=clang++

# Build AFL components
print_status "Compiling AFL tools..."
make clean 2>/dev/null || true
make

if [ $? -eq 0 ]; then
    print_status "AFL tools compiled successfully"
else
    print_error "AFL compilation failed!"
    exit 1
fi

# Build QEMU support
print_status "Building QEMU support (this may take 10-30 minutes)..."
cd qemu_mode

# Check if QEMU is already built
if [ -f "../afl-qemu-system-trace" ]; then
    read -p "QEMU already built. Rebuild? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Skipping QEMU build"
        cd ..
    else
        ./build_qemu_support.sh
        cd ..
    fi
else
    ./build_qemu_support.sh
    cd ..
fi

# Verify build
print_status "Verifying build..."
REQUIRED_FILES=(
    "afl-fuzz"
    "afl-showmap"
    "afl-tmin"
    "afl-cmin"
    "afl-analyze"
    "afl-qemu-system-trace"
)

ALL_FOUND=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status "Found: $file"
    else
        print_error "Missing: $file"
        ALL_FOUND=false
    fi
done

if [ "$ALL_FOUND" = true ]; then
    echo ""
    print_status "================================"
    print_status "TriforceAFL Setup Complete!"
    print_status "================================"
    echo ""
    print_status "Next steps:"
    echo "  1. Read MACOS_FUZZING_GUIDE.md for vulnerability research guidance"
    echo "  2. Prepare your target kernel/OS image"
    echo "  3. Create a fuzzing driver for your target"
    echo "  4. Start fuzzing with: ./afl-fuzz -i inputs -o outputs -QQ -- ..."
    echo ""
    print_warning "Important Notes for macOS:"
    echo "  - Fuzzing will be slower than on Linux (fork() semantics)"
    echo "  - Consider using a Linux VM for better performance"
    echo "  - Only full-system mode (-QQ) works, not user mode (-Q)"
    echo "  - Only 64-bit targets are supported"
    echo ""
    print_warning "For Apple vulnerability research:"
    echo "  - Always obtain proper authorization"
    echo "  - Report findings to Apple Security: product-security@apple.com"
    echo "  - See: https://support.apple.com/en-us/HT201220"
    echo ""
else
    print_error "Setup incomplete - some files are missing"
    exit 1
fi
