# Cross-Platform Setup Guide for TriforceAFL

## Complete Guide for macOS, Windows, and Linux

This guide provides comprehensive setup instructions for running TriforceAFL on macOS, Windows (via WSL), and Linux for multi-vendor security research.

---

## 📋 Quick Navigation

| Platform | Setup Script | Best For | Performance |
|----------|--------------|----------|-------------|
| **macOS** | `setup_macos.sh` | Apple research | Medium (10x slower than Linux) |
| **Windows (WSL2)** | `setup_windows_wsl.sh` | Microsoft/multi-vendor | Good (near-native Linux) |
| **Linux** | Standard build | All vendors | Best (fastest) |

---

## Platform-Specific Setup

### macOS Setup

**Prerequisites**:
- macOS 10.15+ (Catalina or later)
- Xcode Command Line Tools
- 16GB+ RAM recommended
- 100GB+ free disk space

**Quick Start**:
```bash
# Clone repository
git clone https://github.com/nccgroup/TriforceAFL.git
cd TriforceAFL

# Run automated setup
chmod +x setup_macos.sh
./setup_macos.sh

# Setup will:
# ✓ Install dependencies via Homebrew
# ✓ Disable crash reporting (required)
# ✓ Build AFL and QEMU
# ✓ Verify installation
```

**What Gets Installed**:
- Homebrew packages: `libtool automake pkg-config glib pixman`
- TriforceAFL tools: `afl-fuzz`, `afl-showmap`, `afl-tmin`, etc.
- QEMU system emulators: `afl-qemu-system-trace`

**Important macOS Notes**:
- ⚠️ Fuzzing is 10x slower than Linux (fork() overhead)
- ⚠️ Only full-system mode (-QQ) works, not user mode (-Q)
- ⚠️ Only 64-bit compilation supported
- 💡 Consider using Linux VM for production fuzzing

**macOS Best Practices**:
1. Use for Apple-specific research (XNU kernel, IOKit)
2. Run in Docker/VM for better performance
3. Disable energy saver settings
4. Ensure adequate cooling

**See**: `APPLE_SECURITY_REPORTING.md` for Apple-specific research

---

### Windows (WSL2) Setup

**Prerequisites**:
- Windows 10 version 2004+ or Windows 11
- WSL2 enabled
- Ubuntu 22.04 LTS installed in WSL
- 16GB+ RAM recommended
- 100GB+ free disk space

**Enable WSL2**:
```powershell
# In PowerShell (Administrator)
wsl --install -d Ubuntu-22.04

# Restart computer

# Verify WSL2
wsl --list --verbose
# Should show VERSION 2

# If VERSION 1, upgrade:
wsl --set-version Ubuntu-22.04 2
```

**Quick Start**:
```bash
# Launch WSL
wsl

# Clone repository
git clone https://github.com/nccgroup/TriforceAFL.git
cd TriforceAFL

# Run automated setup
chmod +x setup_windows_wsl.sh
./setup_windows_wsl.sh

# Setup will:
# ✓ Verify WSL2 environment
# ✓ Install all dependencies
# ✓ Configure system for fuzzing
# ✓ Build AFL and QEMU
# ✓ Create Windows desktop shortcut
```

**WSL2 Optimization**:

Create `C:\Users\<YourUsername>\.wslconfig`:
```ini
[wsl2]
memory=8GB          # Limit WSL2 memory usage
processors=4        # Number of CPU cores
swap=4GB           # Swap file size
localhostForwarding=true
```

Restart WSL:
```powershell
wsl --shutdown
wsl
```

**File System Performance**:
```bash
# IMPORTANT: Store files in WSL filesystem, not /mnt/c/
# ✓ Good: /home/user/TriforceAFL
# ✗ Bad:  /mnt/c/Users/user/TriforceAFL

# WSL filesystem is 5-10x faster!
```

**Windows Integration**:
```bash
# Access WSL files from Windows Explorer:
# \\wsl$\Ubuntu-22.04\home\user\TriforceAFL

# Access Windows files from WSL:
cd /mnt/c/Users/<username>/Desktop
```

**Windows-Specific Notes**:
- ✓ WSL2 provides near-native Linux performance
- ✓ Great for fuzzing Linux, Android, Chrome
- ⚠️ Windows kernel fuzzing requires Hyper-V (advanced)
- 💡 Best cross-platform fuzzing solution for Windows users

**See**: `MICROSOFT_SECURITY_REPORTING.md` for Windows research

---

### Linux Setup

**Prerequisites**:
- Ubuntu 20.04+ / Debian 11+ / Fedora 35+ or similar
- GCC or Clang compiler
- 16GB+ RAM recommended
- 100GB+ free disk space

**Quick Start**:
```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y \
    build-essential gcc g++ make \
    libtool libtool-bin automake autoconf bison \
    libglib2.0-dev libpixman-1-dev pkg-config \
    zlib1g-dev git wget curl python3

# Clone repository
git clone https://github.com/nccgroup/TriforceAFL.git
cd TriforceAFL

# Build AFL
make clean
make -j$(nproc)

# Build QEMU
cd qemu_mode
./build_qemu_support.sh
cd ..

# Verify
ls -lh afl-fuzz afl-qemu-system-trace
```

**System Configuration**:
```bash
# Disable ASLR (for deterministic fuzzing)
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

# Set core dump pattern
echo core | sudo tee /proc/sys/kernel/core_pattern

# Increase file limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Set CPU governor to performance
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Linux Advantages**:
- ✓ Best performance (500-2000 execs/sec)
- ✓ Full control over system
- ✓ Native QEMU support
- ✓ Ideal for kernel fuzzing
- ✓ Recommended for production fuzzing

---

## Multi-Vendor Fuzzing Setup

### Campaign Manager Tool

The included campaign manager helps orchestrate fuzzing across multiple vendors:

```bash
# Make executable
chmod +x tools/fuzzing_campaign_manager.sh

# Initialize campaign structure
./tools/fuzzing_campaign_manager.sh init

# Directory structure created:
# ~/fuzzing_campaigns/
# ├── apple/
# ├── microsoft/
# ├── google/
# ├── linux/
# ├── logs/
# └── reports/

# Start campaigns
./tools/fuzzing_campaign_manager.sh start all -n 4

# Monitor status
./tools/fuzzing_campaign_manager.sh status

# Generate reports
./tools/fuzzing_campaign_manager.sh report
```

### Target-Specific Setup

#### Apple (macOS/iOS)

```bash
# Set up Apple fuzzing
cd ~/fuzzing_campaigns/apple

# Option 1: Use Linux kernel for practice
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
tar xf linux-5.15.tar.xz
cd linux-5.15
make defconfig && make -j$(nproc)
cp arch/x86/boot/bzImage ~/fuzzing_campaigns/apple/

# Option 2: Build XNU (advanced - see APPLE_SECURITY_REPORTING.md)
git clone https://github.com/apple/darwin-xnu.git
# Follow XNU build instructions

# Create test cases
mkdir -p ~/fuzzing_campaigns/apple/inputs
echo "test" > ~/fuzzing_campaigns/apple/inputs/seed1
dd if=/dev/urandom bs=1 count=100 > ~/fuzzing_campaigns/apple/inputs/seed2
```

**Target**: IOKit drivers, XNU system calls, APFS
**Max Bounty**: $1,000,000+
**Contact**: product-security@apple.com

#### Microsoft (Windows)

```bash
# Set up Windows fuzzing (requires Hyper-V or WSL2)
cd ~/fuzzing_campaigns/microsoft

# Windows kernel fuzzing is complex
# See MICROSOFT_SECURITY_REPORTING.md for detailed instructions

# For Azure/cloud services, use standard Linux setup
```

**Target**: win32k.sys, Hyper-V, Azure, Office
**Max Bounty**: $250,000+
**Contact**: secure@microsoft.com

#### Google (Android/Chrome)

```bash
# Set up Android kernel fuzzing
cd ~/fuzzing_campaigns/google

# Download AOSP kernel
git clone https://android.googlesource.com/kernel/common
cd common
git checkout android-mainline

# Build
make ARCH=arm64 defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

# Copy kernel
cp arch/arm64/boot/Image ~/fuzzing_campaigns/google/zImage_android

# Create test cases
mkdir -p ~/fuzzing_campaigns/google/inputs
# Add media files, network packets, etc.
```

**Target**: Binder IPC, media codecs, Chrome V8
**Max Bounty**: $1,000,000+
**Portal**: https://bughunters.google.com/

#### Linux Kernel

```bash
# Set up Linux kernel fuzzing
cd ~/fuzzing_campaigns/linux

# Download kernel
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.tar.xz
tar xf linux-6.1.tar.xz
cd linux-6.1

# Configure
make defconfig
make kvmconfig

# Enable debug features
./scripts/config -e DEBUG_INFO
./scripts/config -e KASAN
./scripts/config -d RANDOMIZE_BASE

# Build
make -j$(nproc)

# Copy
cp arch/x86/boot/bzImage ~/fuzzing_campaigns/linux/

# Create initramfs with fuzzing driver
# See MULTI_VENDOR_RESEARCH_GUIDE.md
```

**Target**: System calls, file systems, network stack
**Bounty**: Varies by distribution
**Contact**: security@kernel.org (upstream)

---

## Performance Comparison

| Platform | Execs/Sec | Setup Difficulty | Best Use Case |
|----------|-----------|------------------|---------------|
| **Linux (Native)** | 500-2000 | Easy | All vendors, production |
| **WSL2 (Windows)** | 400-1500 | Easy | Multi-vendor, Windows users |
| **macOS** | 50-500 | Medium | Apple research only |
| **Docker on macOS** | 300-1000 | Medium | Better than native macOS |
| **Cloud (AWS/GCP)** | 500-2000+ | Medium | Large-scale campaigns |

### Performance Optimization

**All Platforms**:
```bash
# Use parallel fuzzing
./afl-fuzz -M master ...  # Terminal 1
./afl-fuzz -S slave01 ...  # Terminal 2
./afl-fuzz -S slave02 ...  # Terminal 3

# Minimize VM memory
-m 512M  # Instead of -m 2G

# Reduce timeout
-t 1000  # 1 second instead of 5

# Disable unnecessary kernel features
-append "nokaslr nosmp noapic quiet"
```

**macOS Specific**:
```bash
# Run in Linux VM for 10x speedup
docker run -it --privileged ubuntu:22.04
# Build TriforceAFL inside container
```

**WSL2 Specific**:
```bash
# Allocate more resources in .wslconfig
[wsl2]
memory=16GB
processors=8
```

---

## Verification & Testing

### Quick Verification Test

```bash
# Test basic AFL functionality
mkdir test_inputs test_outputs
echo "hello" > test_inputs/seed

# Run quick test (Ctrl+C after 30 seconds)
timeout 30 ./afl-fuzz -i test_inputs -o test_outputs /bin/cat @@

# Should see fuzzing UI
```

### Test Full-System Mode

```bash
# If you have a kernel image
./afl-showmap -o /tmp/coverage.txt -QQ -- \
  ./afl-qemu-system-trace \
    -kernel bzImage \
    -initrd initramfs.cpio.gz \
    -m 1G -nographic \
    -append "console=ttyS0" \
    -aflFile test_inputs/seed

# Check coverage
wc -l /tmp/coverage.txt
# Should show number of edges covered
```

---

## Troubleshooting

### macOS Issues

**Problem**: "Crash reporter is running"
```bash
# Solution: Disable crash reporter
sudo launchctl unload -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist
```

**Problem**: "QEMU build failed"
```bash
# Solution: Install all dependencies
brew install libtool automake pkg-config glib pixman gnu-sed
```

**Problem**: "Fuzzing too slow"
```bash
# Solution: Use Linux VM or WSL2
# macOS is inherently slower due to fork() overhead
```

### Windows WSL Issues

**Problem**: "Not running in WSL"
```bash
# Solution: Launch WSL first
wsl -d Ubuntu-22.04
```

**Problem**: "WSL1 instead of WSL2"
```powershell
# Solution: Upgrade to WSL2
wsl --set-version Ubuntu-22.04 2
```

**Problem**: "Slow file I/O"
```bash
# Solution: Use WSL filesystem, not /mnt/c/
# Move files to /home/user/
```

### Linux Issues

**Problem**: "Fork server timeout"
```bash
# Solution: Increase timeout
./afl-fuzz -t 10000 ...  # 10 second timeout
```

**Problem**: "Out of memory"
```bash
# Solution: Reduce VM memory
-m 512M  # Instead of -m 2G
```

### Universal Issues

**Problem**: "No instrumentation detected"
```bash
# Solution: Verify driver calls aflCall instructions
# Check QEMU boots and loads driver
# Test manually before fuzzing
```

---

## Next Steps

### 1. Choose Your Target

| Interest | Recommended Target | Guide |
|----------|-------------------|-------|
| Highest bounties | iOS/Android | APPLE_SECURITY_REPORTING.md, GOOGLE_SECURITY_REPORTING.md |
| Windows security | Windows kernel, Hyper-V | MICROSOFT_SECURITY_REPORTING.md |
| Learning | Linux kernel | MULTI_VENDOR_RESEARCH_GUIDE.md |
| Web security | Chrome browser | GOOGLE_SECURITY_REPORTING.md |

### 2. Read Relevant Guides

- **Apple Research**: `APPLE_SECURITY_REPORTING.md`
- **Microsoft Research**: `MICROSOFT_SECURITY_REPORTING.md`
- **Google Research**: `GOOGLE_SECURITY_REPORTING.md`
- **Multi-Vendor**: `MULTI_VENDOR_RESEARCH_GUIDE.md`
- **Detailed Fuzzing**: `MACOS_FUZZING_GUIDE.md`

### 3. Set Up Campaign

```bash
# Run campaign manager
./tools/fuzzing_campaign_manager.sh init
./tools/fuzzing_campaign_manager.sh start

# Or manual setup
./examples/macos_fuzzer_example.sh
```

### 4. Monitor & Iterate

```bash
# Check status
./tools/fuzzing_campaign_manager.sh status

# Triage crashes
./tools/fuzzing_campaign_manager.sh triage

# Generate reports
./tools/fuzzing_campaign_manager.sh report
```

### 5. Report Findings

Follow responsible disclosure:
- **Apple**: product-security@apple.com
- **Microsoft**: secure@microsoft.com
- **Google**: https://bughunters.google.com/
- **Others**: See MULTI_VENDOR_RESEARCH_GUIDE.md

---

## Resources

### Documentation
- Setup guides (this file)
- Vendor-specific reporting guides
- Technical internals: `docs/triforce_internals.txt`
- AFL algorithm: `docs/technical_details.txt`

### Tools
- Campaign manager: `tools/fuzzing_campaign_manager.sh`
- Example setup: `examples/macos_fuzzer_example.sh`

### Community
- TriforceAFL: https://github.com/nccgroup/TriforceAFL
- AFL users group: https://groups.google.com/group/afl-users
- Security research communities

---

## Legal Reminder

### Always Required
- ✅ Proper authorization before testing
- ✅ Responsible disclosure practices
- ✅ Follow bug bounty program rules
- ✅ Respect user privacy and data
- ✅ Comply with all applicable laws

### Never Do
- ❌ Unauthorized system access
- ❌ Testing production systems without permission
- ❌ Public disclosure before patches
- ❌ Accessing user data
- ❌ Selling vulnerabilities maliciously

---

## Quick Reference Commands

```bash
# Setup
./setup_macos.sh           # macOS
./setup_windows_wsl.sh     # Windows WSL2
make && cd qemu_mode && ./build_qemu_support.sh  # Linux

# Campaign Management
./tools/fuzzing_campaign_manager.sh init
./tools/fuzzing_campaign_manager.sh start
./tools/fuzzing_campaign_manager.sh status

# Manual Fuzzing
./afl-fuzz -i inputs -o outputs -QQ -- \
  ./afl-qemu-system-trace -kernel bzImage ...

# Parallel Fuzzing
./afl-fuzz -M master ...
./afl-fuzz -S slave01 ...

# Crash Triage
./afl-tmin -i crash -o minimized -QQ -- ...
./afl-showmap -o coverage.txt -QQ -- ...
```

---

**Good luck with your cross-platform security research!** 🔒🌐

---

**Document Version**: 1.0
**Last Updated**: 2025-01-09
**Maintainer**: Security Research Team
**License**: See repository LICENSE file
