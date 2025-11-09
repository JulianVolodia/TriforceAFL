#!/bin/bash
#
# TriforceAFL Setup Script for Windows (WSL2)
#
# IMPORTANT: TriforceAFL does NOT run natively on Windows!
# This script sets up TriforceAFL in Windows Subsystem for Linux (WSL2)
#
# Prerequisites:
#   1. Windows 10/11 with WSL2 enabled
#   2. Ubuntu 22.04 LTS installed in WSL
#   3. Run this script from within WSL
#
# Usage:
#   wsl
#   cd /path/to/TriforceAFL
#   chmod +x setup_windows_wsl.sh
#   ./setup_windows_wsl.sh
#
# Note: This script is designed for security researchers conducting authorized
# vulnerability research. Always obtain proper authorization before testing.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# ASCII Art Banner
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ████████╗██████╗ ██╗███████╗ ██████╗ ██████╗  ██████╗███████╗
║     ╚══██╔══╝██╔══██╗██║██╔════╝██╔═══██╗██╔══██╗██╔════╝██╔════╝
║        ██║   ██████╔╝██║█████╗  ██║   ██║██████╔╝██║     █████╗
║        ██║   ██╔══██╗██║██╔══╝  ██║   ██║██╔══██╗██║     ██╔══╝
║        ██║   ██║  ██║██║██║     ╚██████╔╝██║  ██║╚██████╗███████╗
║        ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚══════╝
║                                                                ║
║              Windows WSL2 Setup Script v1.0                    ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF

echo ""
print_status "TriforceAFL Windows WSL2 Setup Script"
print_info "Full-System Fuzzing for Security Research"
echo ""

# Check if running in WSL
if ! grep -qi microsoft /proc/version; then
    print_error "This script must be run inside Windows Subsystem for Linux (WSL)!"
    print_error "Current environment: $(uname -a)"
    echo ""
    print_info "To set up WSL on Windows:"
    echo "  1. Open PowerShell as Administrator"
    echo "  2. Run: wsl --install -d Ubuntu-22.04"
    echo "  3. Restart your computer"
    echo "  4. Launch 'Ubuntu 22.04' from Start Menu"
    echo "  5. Run this script again"
    exit 1
fi

print_status "Running in WSL environment: $(grep -i microsoft /proc/version | head -1)"
echo ""

# Check WSL version
print_status "Checking WSL version..."
if grep -qi "WSL2" /proc/version || [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    print_status "WSL2 detected (recommended)"
else
    print_warning "WSL1 detected. WSL2 is recommended for better performance."
    print_info "To upgrade to WSL2:"
    print_info "  In PowerShell (Admin): wsl --set-version Ubuntu-22.04 2"
fi
echo ""

# Detect Windows username for integration
WIN_USER=$(powershell.exe -c "echo \$env:USERNAME" 2>/dev/null | tr -d '\r' || echo "unknown")
print_info "Windows username: $WIN_USER"
echo ""

# Update package list
print_status "Updating package lists..."
sudo apt-get update -qq

# Install dependencies
print_status "Installing build dependencies..."
DEPS=(
    "build-essential"
    "gcc"
    "g++"
    "make"
    "libtool"
    "libtool-bin"
    "automake"
    "autoconf"
    "bison"
    "libglib2.0-dev"
    "libpixman-1-dev"
    "pkg-config"
    "zlib1g-dev"
    "git"
    "wget"
    "curl"
    "python3"
    "python3-pip"
    "clang"
    "llvm"
)

for dep in "${DEPS[@]}"; do
    if dpkg -l | grep -q "^ii  $dep "; then
        print_status "$dep already installed"
    else
        print_status "Installing $dep..."
        sudo apt-get install -y -qq "$dep" >/dev/null 2>&1
    fi
done

print_status "All dependencies installed successfully"
echo ""

# Configure system for fuzzing
print_status "Configuring system for fuzzing..."

# Set core dump pattern
print_status "Setting core dump pattern..."
echo core | sudo tee /proc/sys/kernel/core_pattern >/dev/null

# Disable ASLR (for deterministic fuzzing)
print_warning "Disabling ASLR for fuzzing (recommended)..."
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space >/dev/null

# Increase file descriptor limits
print_status "Increasing file descriptor limits..."
cat << 'LIMITS_EOF' | sudo tee -a /etc/security/limits.conf >/dev/null
# TriforceAFL fuzzing limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
LIMITS_EOF

echo ""
print_status "System configuration complete"
echo ""

# Build AFL
print_status "Building TriforceAFL..."
cd "$(dirname "$0")"

# Clean previous builds
if [ -f "afl-fuzz" ]; then
    print_warning "Previous build detected. Cleaning..."
    make clean 2>/dev/null || true
fi

# Set compiler
export CC=gcc
export CXX=g++

# Build AFL components
print_status "Compiling AFL tools (this may take a few minutes)..."
if make -j$(nproc) 2>&1 | tee /tmp/afl_build.log; then
    print_status "AFL tools compiled successfully"
else
    print_error "AFL compilation failed!"
    print_error "Check /tmp/afl_build.log for details"
    exit 1
fi

echo ""

# Build QEMU support
print_status "Building QEMU support (this will take 10-30 minutes)..."
print_warning "This is the longest step - please be patient!"
echo ""

cd qemu_mode

# Check if QEMU is already built
if [ -f "../afl-qemu-system-trace" ]; then
    print_warning "QEMU already built."
    read -p "Rebuild QEMU? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Skipping QEMU build"
        cd ..
    else
        if ./build_qemu_support.sh 2>&1 | tee /tmp/qemu_build.log; then
            print_status "QEMU built successfully"
            cd ..
        else
            print_error "QEMU build failed!"
            print_error "Check /tmp/qemu_build.log for details"
            exit 1
        fi
    fi
else
    if ./build_qemu_support.sh 2>&1 | tee /tmp/qemu_build.log; then
        print_status "QEMU built successfully"
        cd ..
    else
        print_error "QEMU build failed!"
        print_error "Check /tmp/qemu_build.log for details"
        exit 1
    fi
fi

echo ""

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
        print_status "✓ Found: $file"
    else
        print_error "✗ Missing: $file"
        ALL_FOUND=false
    fi
done

echo ""

if [ "$ALL_FOUND" = true ]; then
    print_status "════════════════════════════════════════════════════════════"
    print_status "            TriforceAFL Setup Complete! ✓"
    print_status "════════════════════════════════════════════════════════════"
    echo ""

    # Create shortcuts in Windows
    print_status "Setting up Windows integration..."

    # Get WSL path
    WSL_PATH=$(pwd)
    WIN_PATH=$(wslpath -w "$WSL_PATH" 2>/dev/null || echo "")

    if [ -n "$WIN_PATH" ]; then
        print_info "Windows path: $WIN_PATH"

        # Create a Windows batch file to launch WSL with TriforceAFL
        BATCH_FILE="/mnt/c/Users/$WIN_USER/Desktop/TriforceAFL.bat"
        if [ -d "/mnt/c/Users/$WIN_USER/Desktop" ]; then
            cat > "$BATCH_FILE" << BATCH_EOF
@echo off
echo Starting TriforceAFL in WSL...
wsl -d Ubuntu-22.04 -e bash -c "cd '$WSL_PATH' && bash"
BATCH_EOF
            chmod +x "$BATCH_FILE"
            print_status "Created desktop shortcut: TriforceAFL.bat"
        fi
    fi

    echo ""
    print_status "Next Steps:"
    echo ""
    print_info "1. Read the comprehensive guides:"
    echo "   - MULTI_VENDOR_RESEARCH_GUIDE.md (for all companies)"
    echo "   - MICROSOFT_SECURITY_REPORTING.md (for Microsoft)"
    echo "   - GOOGLE_SECURITY_REPORTING.md (for Google)"
    echo "   - APPLE_SECURITY_REPORTING.md (for Apple)"
    echo ""
    print_info "2. Choose your target:"
    echo "   - Windows kernel (Microsoft)"
    echo "   - Linux kernel (Google, Red Hat, Canonical)"
    echo "   - macOS/iOS kernel (Apple)"
    echo "   - Android kernel (Google)"
    echo ""
    print_info "3. Prepare your fuzzing environment:"
    echo "   - Build or obtain target OS kernel"
    echo "   - Create fuzzing driver"
    echo "   - Set up test cases"
    echo ""
    print_info "4. Start fuzzing:"
    echo "   ./afl-fuzz -i inputs -o outputs -QQ -- \\"
    echo "     ./afl-qemu-system-trace -kernel bzImage ..."
    echo ""
    print_warning "IMPORTANT - Windows-Specific Notes:"
    echo "  • WSL2 provides near-native Linux performance"
    echo "  • Use WSL2 for better fuzzing speed (vs WSL1)"
    echo "  • Windows kernel fuzzing requires special setup"
    echo "  • See WINDOWS_KERNEL_FUZZING.md for details"
    echo ""
    print_warning "LEGAL REQUIREMENTS:"
    echo "  • Obtain proper authorization before testing"
    echo "  • Only test systems you own or have permission to test"
    echo "  • Report vulnerabilities responsibly:"
    echo "    - Microsoft: secure@microsoft.com"
    echo "    - Google: https://bughunters.google.com/"
    echo "    - Apple: product-security@apple.com"
    echo "  • Follow each company's disclosure policies"
    echo ""
    print_status "Performance Tips for WSL:"
    echo "  • Store files in WSL filesystem (not /mnt/c/) for best performance"
    echo "  • Use 'wsl --shutdown' to reset WSL if needed"
    echo "  • Allocate more RAM to WSL in .wslconfig if needed"
    echo ""
    print_info "WSL Configuration (.wslconfig):"
    echo "  Location: C:\\Users\\$WIN_USER\\.wslconfig"
    echo "  Example:"
    echo "    [wsl2]"
    echo "    memory=8GB"
    echo "    processors=4"
    echo "    swap=4GB"
    echo ""
else
    print_error "════════════════════════════════════════════════════════════"
    print_error "Setup incomplete - some files are missing"
    print_error "════════════════════════════════════════════════════════════"
    exit 1
fi

# Create a quick reference card
cat > QUICK_START_WSL.txt << 'QUICKSTART_EOF'
╔══════════════════════════════════════════════════════════════╗
║           TriforceAFL Quick Start Guide - WSL2               ║
╚══════════════════════════════════════════════════════════════╝

LAUNCHING WSL:
--------------
From Windows:
  1. Press Win+R
  2. Type: wsl
  3. Or: Click "Ubuntu 22.04" in Start Menu

From PowerShell/CMD:
  wsl -d Ubuntu-22.04

BASIC COMMANDS:
---------------
# Navigate to TriforceAFL
cd ~/TriforceAFL

# Build a simple fuzzer
./afl-fuzz -i inputs -o outputs /path/to/target @@

# Full-system fuzzing
./afl-fuzz -i inputs -o outputs -QQ -- \
  ./afl-qemu-system-trace -kernel bzImage -initrd initramfs.cpio.gz ...

# View results
ls -lh outputs/crashes/
ls -lh outputs/queue/

WINDOWS ↔ WSL FILE ACCESS:
--------------------------
From Windows Explorer:
  \\wsl$\Ubuntu-22.04\home\<username>\TriforceAFL

From WSL to Windows:
  /mnt/c/Users/<username>/

VULNERABILITY REPORTING:
------------------------
Microsoft:  secure@microsoft.com
            https://msrc.microsoft.com/

Google:     https://bughunters.google.com/
            https://g.co/vulnz

Apple:      product-security@apple.com
            https://security.apple.com/

TARGET EXAMPLES:
----------------
1. Windows Kernel:
   - Requires special setup (see WINDOWS_KERNEL_FUZZING.md)
   - Hyper-V integration

2. Linux Kernel:
   - Download from kernel.org
   - Build with fuzzing driver
   - Standard TriforceAFL workflow

3. Android:
   - AOSP kernel source
   - Emulator integration

PERFORMANCE MONITORING:
-----------------------
# Check fuzzer status
watch -n 1 'cat outputs/fuzzer_stats'

# Monitor CPU usage
htop

# Check memory
free -h

TROUBLESHOOTING:
----------------
Issue: "Fork server timeout"
Fix:   Increase timeout with -t flag

Issue: "WSL slow"
Fix:   Use WSL2, not WSL1
       wsl --set-version Ubuntu-22.04 2

Issue: "Out of memory"
Fix:   Edit C:\Users\<user>\.wslconfig
       [wsl2]
       memory=8GB

USEFUL RESOURCES:
-----------------
Documentation:     See *.md files in repo
Windows specifics: WINDOWS_KERNEL_FUZZING.md
Multi-vendor:      MULTI_VENDOR_RESEARCH_GUIDE.md
Examples:          examples/ directory

WSL Commands:
  wsl --shutdown           # Restart WSL
  wsl --list --verbose     # Show installed distros
  wsl --status             # Show WSL status

SECURITY REMINDERS:
-------------------
✓ Obtain authorization before testing
✓ Only test systems you own or have permission
✓ Report vulnerabilities responsibly
✓ Follow 90-day disclosure timelines
✓ Respect bug bounty program rules

Happy (authorized) fuzzing!
QUICKSTART_EOF

print_status "Created QUICK_START_WSL.txt for quick reference"
echo ""
print_status "Setup complete! Read QUICK_START_WSL.txt for next steps."
