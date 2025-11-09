# TriforceAFL macOS Fuzzing Guide

## Security Research & Vulnerability Discovery for Apple Platforms

This guide provides instructions for using TriforceAFL on macOS to discover security vulnerabilities in operating systems and kernel-level code, specifically targeting Apple platforms.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Legal and Ethical Considerations](#legal-and-ethical-considerations)
3. [Understanding TriforceAFL](#understanding-triforceafl)
4. [Target Selection](#target-selection)
5. [Building a Fuzzing Environment](#building-a-fuzzing-environment)
6. [Creating a Fuzzing Driver](#creating-a-fuzzing-driver)
7. [Running the Fuzzer](#running-the-fuzzer)
8. [Analyzing Results](#analyzing-results)
9. [Reporting to Apple](#reporting-to-apple)
10. [Performance Considerations](#performance-considerations)

---

## Introduction

TriforceAFL extends American Fuzzy Lop (AFL) to support **full-system fuzzing** using QEMU. This allows you to fuzz entire operating systems, including:
- Kernel system calls
- Device drivers
- File system implementations
- Network protocol stacks
- Cryptographic implementations
- Memory management subsystems

### What Makes TriforceAFL Different?

- **Full System Fuzzing**: Unlike traditional AFL that fuzzes individual applications, TriforceAFL can fuzz kernel code
- **Fork Server in VM**: Each test case runs in an isolated forked copy of the entire VM
- **Targeted Tracing**: You can specify which memory regions to trace for coverage
- **Panic Detection**: Automatically detects kernel panics and crashes

---

## Legal and Ethical Considerations

### CRITICAL: Authorization Required

**You MUST have explicit authorization before conducting any security testing.**

✅ **Authorized Activities:**
- Fuzzing your own systems and code
- Fuzzing open-source operating systems (Linux, FreeBSD, etc.)
- Authorized penetration testing engagements
- CTF competitions and security research challenges
- Academic research with proper oversight
- Testing under Apple's Security Bounty Program

❌ **Prohibited Activities:**
- Unauthorized testing of production systems
- Denial of Service attacks
- Testing systems you don't own without permission
- Circumventing security controls for malicious purposes

### Apple Security Bounty Program

Apple operates a security bounty program for responsible disclosure:
- **Website**: https://security.apple.com/
- **Email**: product-security@apple.com
- **Rewards**: Up to $1,000,000+ for critical vulnerabilities

**Eligible Categories:**
- Zero-click kernel code execution
- One-click kernel code execution
- Privilege escalation vulnerabilities
- Sandbox escapes
- Authentication bypasses
- User data access vulnerabilities

---

## Understanding TriforceAFL

### Architecture Overview

```
┌─────────────────────────────────────────────┐
│          Host OS (macOS)                    │
│  ┌───────────────────────────────────────┐  │
│  │     afl-fuzz (Fuzzer Engine)          │  │
│  └──────────────┬────────────────────────┘  │
│                 │                            │
│  ┌──────────────▼────────────────────────┐  │
│  │   QEMU Full-System Emulator           │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  Guest OS (e.g., Linux/macOS)   │  │  │
│  │  │  ┌───────────────────────────┐  │  │  │
│  │  │  │   Fuzzing Driver          │  │  │  │
│  │  │  │   - startForkserver       │  │  │  │
│  │  │  │   - getWork (read input)  │  │  │  │
│  │  │  │   - startWork (trace)     │  │  │  │
│  │  │  │   - Parse & Execute       │  │  │  │
│  │  │  │   - doneWork (complete)   │  │  │  │
│  │  │  └───────────────────────────┘  │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Custom CPU Instructions (aflCall)

TriforceAFL adds special CPU instructions for communication:

| Instruction | edi Value | Purpose |
|------------|-----------|---------|
| `startForkserver` | 1 | Start AFL fork server |
| `getWork` | 2 | Get next test case input |
| `startWork` | 3 | Enable coverage tracing |
| `doneWork` | 4 | Mark test case complete |

---

## Target Selection

### Ideal Targets for Fuzzing

1. **System Call Handlers**
   - Entry points from userspace to kernel
   - Complex parsers with attack surface
   - Example: `ioctl()`, `setsockopt()`, `fcntl()`

2. **File System Code**
   - File format parsers
   - Mount operations
   - Extended attributes handling

3. **Network Stack**
   - Protocol implementations
   - Packet parsing
   - Socket options

4. **Device Drivers**
   - IOKit drivers (macOS/iOS)
   - Character device handlers
   - Memory-mapped I/O handlers

5. **Virtualization Features**
   - Hypervisor interfaces
   - VM control interfaces

### Apple-Specific High-Value Targets

#### iOS/macOS Kernel (XNU)

```
Priority Targets in XNU:
1. IOKit Drivers
   - Location: xnu/iokit/
   - High attack surface from userspace
   - History of vulnerabilities

2. System Call Interface
   - Location: xnu/bsd/kern/
   - Entry points: syscalls.master

3. Mach IPC
   - Location: xnu/osfmk/mach/
   - Complex message parsing

4. Network Stack
   - Location: xnu/bsd/netinet/
   - Protocol implementations

5. File Systems (APFS, HFS+)
   - Location: xnu/bsd/vfs/
   - Complex on-disk format parsers
```

---

## Building a Fuzzing Environment

### Step 1: Prepare Target OS Image

For fuzzing macOS/iOS kernel components:

#### Option A: Use Linux as Target (Recommended for Learning)

```bash
# Download a Linux kernel and build a custom initramfs
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
tar xf linux-5.15.tar.xz
cd linux-5.15

# Build kernel with debug symbols
make defconfig
make kvmconfig
make -j$(sysctl -n hw.ncpu)

# Create minimal initramfs with fuzzing driver
mkdir initramfs
cd initramfs
# (See "Creating a Fuzzing Driver" section below)
```

#### Option B: Build XNU (Advanced)

```bash
# Note: Building XNU is complex and requires matching dependencies
# See: https://github.com/apple/darwin-xnu

git clone https://github.com/apple/darwin-xnu.git
cd darwin-xnu

# Follow Apple's build instructions
# Note: This is challenging and may require additional setup
```

#### Option C: Use Existing Darwin/XNU Builds

```bash
# Look for pre-built XNU kernels for research
# Community projects: https://github.com/Synss/darwin-xnu-build
```

### Step 2: Set Up QEMU Environment

```bash
# Test QEMU with your kernel
./afl-qemu-system-trace \
    -kernel /path/to/bzImage \
    -initrd /path/to/initramfs.cpio.gz \
    -m 2G \
    -nographic \
    -append "console=ttyS0 nokaslr"

# nokaslr is recommended for consistent addressing during fuzzing
```

---

## Creating a Fuzzing Driver

### Basic Driver Structure

Your fuzzing driver needs to:
1. Execute during OS boot
2. Set up the fork server
3. Read test cases
4. Invoke the target code
5. Report completion or crashes

### Example C Driver (Linux Kernel Module)

```c
// fuzzer_driver.c - Minimal kernel fuzzing driver
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/slab.h>

// AFL custom instructions
static inline void aflCall(int op, unsigned long arg1, unsigned long arg2) {
    __asm__ volatile (
        ".byte 0x0f, 0x24\n"
        : : "D"(op), "S"(arg1), "d"(arg2)
    );
}

#define AFL_START_FORKSERVER 1
#define AFL_GET_WORK 2
#define AFL_START_WORK 3
#define AFL_DONE_WORK 4

// Target addresses to trace (update these!)
struct trace_range {
    unsigned long start;
    unsigned long end;
};

static int __init fuzzer_init(void) {
    char *test_buf;
    int test_size;
    struct trace_range range;

    printk(KERN_INFO "Fuzzer: Starting AFL fork server\n");

    // Start the AFL fork server
    aflCall(AFL_START_FORKSERVER, 0, 0);

    // Allocate buffer for test cases
    test_buf = kmalloc(64 * 1024, GFP_KERNEL);
    if (!test_buf) {
        printk(KERN_ERR "Fuzzer: Failed to allocate buffer\n");
        return -ENOMEM;
    }

    // Main fuzzing loop
    while (1) {
        // Get next test case
        test_size = aflCall(AFL_GET_WORK, (unsigned long)test_buf, 64 * 1024);

        // Set trace range (adjust for your target!)
        // Example: trace system call handler
        range.start = 0xffffffff81000000;  // Start of kernel text
        range.end   = 0xffffffff82000000;  // End of kernel text

        // Enable tracing for target region
        aflCall(AFL_START_WORK, (unsigned long)&range, 0);

        // === YOUR TARGET CODE HERE ===
        // Example: Parse and execute system call
        // This is where you invoke the code you want to fuzz

        // For demonstration: call a vulnerable function
        // vulnerable_syscall_handler(test_buf, test_size);

        printk(KERN_INFO "Fuzzer: Processed test case of size %d\n", test_size);

        // Mark test case as complete (exit code 0 = success)
        aflCall(AFL_DONE_WORK, 0, 0);
    }

    kfree(test_buf);
    return 0;
}

static void __exit fuzzer_exit(void) {
    printk(KERN_INFO "Fuzzer: Exiting\n");
}

module_init(fuzzer_init);
module_exit(fuzzer_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Security Researcher");
MODULE_DESCRIPTION("AFL Fuzzing Driver");
```

### Finding Target Addresses

To trace specific kernel functions, you need their addresses:

```bash
# From within the running VM:
grep "function_name" /proc/kallsyms

# For panic detection:
grep " panic$" /proc/kallsyms
# Output: ffffffff8108064b T panic

# For logging detection (Linux):
grep " log_store$" /proc/kallsyms
# Output: ffffffff8108e570 t log_store
```

### Building the Driver into initramfs

```bash
# Create initramfs structure
mkdir -p initramfs/{bin,sbin,etc,proc,sys,dev,lib,lib64}

# Build static busybox
cd busybox-1.35.0
make defconfig
make LDFLAGS="--static" -j$(nproc)
make LDFLAGS="--static" install CONFIG_PREFIX=../initramfs

# Add fuzzing driver
cd initramfs
cat > init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Load fuzzing driver
insmod /fuzzer_driver.ko

# Keep running
exec /bin/sh
EOF

chmod +x init

# Copy your compiled driver
cp /path/to/fuzzer_driver.ko .

# Create cpio archive
find . | cpio -o -H newc | gzip > ../initramfs.cpio.gz
```

---

## Running the Fuzzer

### Step 1: Create Initial Test Cases

```bash
mkdir inputs
# Start with simple inputs
echo "AAAA" > inputs/test1
echo "BBBBBBBB" > inputs/test2
python3 -c "import sys; sys.stdout.buffer.write(b'\x00' * 100)" > inputs/test3
```

### Step 2: Find Target Addresses

Boot your VM normally and extract addresses:

```bash
./afl-qemu-system-trace \
    -kernel bzImage \
    -initrd initramfs.cpio.gz \
    -m 2G -nographic \
    -append "console=ttyS0"

# In VM, note addresses from kallsyms
# Exit VM when done
```

### Step 3: Start Fuzzing

```bash
# Basic fuzzing command
./afl-fuzz \
    -i inputs \
    -o outputs \
    -m 2048 \
    -t 5000 \
    -QQ -- \
    ./afl-qemu-system-trace \
        -kernel bzImage \
        -initrd initramfs.cpio.gz \
        -m 2G \
        -nographic \
        -append "console=ttyS0 nokaslr" \
        -aflPanicAddr 0xffffffff8108064b \
        -aflDmesgAddr 0xffffffff8108e570 \
        -aflFile @@

# Options explained:
# -i inputs       : Directory with initial test cases
# -o outputs      : Directory for fuzzer findings
# -m 2048         : Memory limit in MB
# -t 5000         : Timeout per test in ms
# -QQ             : Full-system QEMU mode
# -aflPanicAddr   : Address of panic() function
# -aflDmesgAddr   : Address of log_store() function
# -aflFile @@     : Test case file (AFL replaces @@)
```

### Step 4: Parallel Fuzzing (Recommended)

For better performance, run multiple fuzzers in parallel:

```bash
# Terminal 1 - Master fuzzer
./afl-fuzz -i inputs -o outputs -m 2048 -t 5000 -M fuzzer01 -QQ -- [...]

# Terminal 2 - Secondary fuzzer
./afl-fuzz -i inputs -o outputs -m 2048 -t 5000 -S fuzzer02 -QQ -- [...]

# Terminal 3 - Secondary fuzzer
./afl-fuzz -i inputs -o outputs -m 2048 -t 5000 -S fuzzer03 -QQ -- [...]

# Use as many cores as you have available (minus 1-2 for system)
```

---

## Analyzing Results

### Understanding AFL Output Directories

```
outputs/
├── queue/          # All unique test cases (corpus)
├── crashes/        # Test cases that caused crashes
├── hangs/          # Test cases that caused timeouts
└── fuzzer_stats    # Statistics and progress
```

### Triaging Crashes

```bash
# List all crashes
ls -lh outputs/crashes/

# Crashes are named with format: id:NNNNNN,sig:NN,src:...
# sig:11 = SIGSEGV (segmentation fault)
# sig:06 = SIGABRT (abort)
# sig:04 = SIGILL (illegal instruction)

# Reproduce a crash
./afl-qemu-system-trace \
    -kernel bzImage \
    -initrd initramfs.cpio.gz \
    -m 2G \
    -nographic \
    -append "console=ttyS0" \
    -aflFile outputs/crashes/id:000000,sig:11,src:000000
```

### Minimizing Test Cases

Reduce crash test cases to smallest size:

```bash
# Minimize a crashing test case
./afl-tmin \
    -i outputs/crashes/id:000000,sig:11,src:000000 \
    -o minimized_crash \
    -QQ -- \
    ./afl-qemu-system-trace [same args as fuzzing]
```

### Coverage Analysis

```bash
# Generate coverage map
./afl-showmap \
    -o coverage.txt \
    -QQ -- \
    ./afl-qemu-system-trace \
        -kernel bzImage \
        -initrd initramfs.cpio.gz \
        -m 2G \
        -nographic \
        -append "console=ttyS0" \
        -aflFile test_input

# View unique edges discovered
wc -l coverage.txt
```

### Identifying Exploitability

When analyzing crashes, consider:

1. **Crash Type**
   - NULL pointer dereference (likely DoS)
   - Buffer overflow (potential RCE)
   - Use-after-free (potential RCE)
   - Integer overflow (depends on usage)

2. **Attacker Control**
   - Can attacker control crash address?
   - Can attacker control register values?
   - Is crash deterministic?

3. **Privilege Context**
   - Does crash occur in kernel mode?
   - Can unprivileged user trigger it?
   - Does it bypass sandbox?

---

## Reporting to Apple

### Before Reporting

✅ **Checklist:**
- [ ] Confirm vulnerability is reproducible
- [ ] Minimize proof-of-concept
- [ ] Identify affected versions
- [ ] Assess security impact
- [ ] Check if already reported/patched
- [ ] Document root cause
- [ ] Create clear reproduction steps

### Report Format

```
Subject: [Security] [Component] Brief Description

SUMMARY:
One-line description of the vulnerability

AFFECTED VERSIONS:
- macOS Ventura 13.x
- macOS Monterey 12.x
- iOS 16.x
(etc.)

VULNERABILITY TYPE:
- Memory corruption (buffer overflow)
- Use-after-free
- Integer overflow
- Logic error
(etc.)

ATTACK VECTOR:
- Local access required
- Remote network attack
- No user interaction needed
- Requires user action
(etc.)

SECURITY IMPACT:
- Arbitrary kernel code execution
- Privilege escalation
- Information disclosure
- Denial of service
(etc.)

TECHNICAL DETAILS:
Detailed explanation of the bug, including:
- Root cause analysis
- Affected code/function
- Why it's exploitable

PROOF OF CONCEPT:
Step-by-step reproduction instructions and
minimal test case to trigger the vulnerability

PROPOSED FIX:
(Optional) Suggested remediation approach
```

### Submission Channels

1. **Apple Product Security**
   - Email: product-security@apple.com
   - PGP Key: Available at https://support.apple.com/en-us/HT201220

2. **Bug Bounty Portal**
   - https://security.apple.com/

3. **Response Timeline**
   - Apple typically responds within 48-72 hours
   - Coordinate disclosure timeline (usually 90 days)
   - Follow responsible disclosure practices

### Bounty Expectations

| Vulnerability Type | Reward Range |
|-------------------|--------------|
| Zero-click kernel RCE | $1,000,000+ |
| One-click kernel RCE | $500,000+ |
| Kernel privilege escalation | $100,000+ |
| Sandbox escape | $100,000+ |
| Authentication bypass | $50,000+ |

*Actual rewards vary based on impact, quality, and novelty*

---

## Performance Considerations

### macOS-Specific Limitations

⚠️ **Important**: Fuzzing on macOS is **significantly slower** than Linux due to:
- Non-POSIX-compliant fork() semantics
- Different memory management
- macOS overhead

**Expected Performance:**
- Linux: 500-2000 execs/sec
- macOS: 50-500 execs/sec
- **10x slower on macOS is normal**

### Optimization Strategies

1. **Use Linux VM**
   ```bash
   # Consider running TriforceAFL inside a Linux VM on macOS
   # Use Docker or VirtualBox with Linux
   docker run -it --privileged ubuntu:22.04
   ```

2. **Reduce VM Memory**
   ```bash
   # Smaller VMs fork faster
   # Use minimal memory: -m 512M or -m 1G
   ```

3. **Disable Unnecessary Features**
   ```bash
   # In kernel command line:
   # nokaslr - Disable KASLR for consistency
   # noapic - Disable APIC
   # nosmp - Single CPU
   # quiet - Reduce logging
   ```

4. **Optimize Test Cases**
   ```bash
   # Keep inputs small (<1KB)
   # Use afl-cmin to minimize corpus
   ./afl-cmin -i outputs/queue -o minimized_corpus -QQ -- [...]
   ```

5. **Parallel Fuzzing**
   - Run multiple instances (one per CPU core)
   - Use tmux/screen for management

6. **Use Persistent Mode**
   - Modify driver to handle multiple test cases per fork
   - Significantly improves throughput

---

## Additional Resources

### TriforceAFL Resources
- Official Repo: https://github.com/nccgroup/TriforceAFL
- Linux Syscall Fuzzer: https://github.com/nccgroup/TriforceLinuxSyscallFuzzer
- NCC Group Blog: https://www.nccgroup.com/

### AFL Resources
- AFL Documentation: https://github.com/google/AFL
- AFL Technical Whitepaper: See docs/technical_details.txt
- AFL Community: https://groups.google.com/group/afl-users

### Apple Security Resources
- Apple Security: https://support.apple.com/en-us/HT201220
- XNU Source Code: https://github.com/apple/darwin-xnu
- iOS Security Guide: https://support.apple.com/guide/security/welcome/web
- macOS Security: https://support.apple.com/guide/security/welcome/1/web

### Vulnerability Research
- Project Zero: https://googleprojectzero.blogspot.com/
- Talos Intelligence: https://blog.talosintelligence.com/
- Trail of Bits Blog: https://blog.trailofbits.com/

---

## Troubleshooting

### Common Issues on macOS

**Issue**: "AFL++ crash reporter detection"
```bash
# Disable crash reporter (see setup script)
sudo launchctl unload -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist
```

**Issue**: "Compiler not found" or "gcc fails"
```bash
# macOS gcc is actually clang
export CC=clang
export CXX=clang++
make clean && make
```

**Issue**: "QEMU doesn't compile"
```bash
# Install all dependencies
brew install libtool automake pkg-config glib pixman

# Check for errors in qemu_mode/qemu/config.log
```

**Issue**: "Fork server timeout"
```bash
# Increase timeout (default is 120 seconds)
# Edit config.h and increase EXEC_TIMEOUT
# Or use -t flag with larger value
./afl-fuzz -t 10000 ...  # 10 second timeout
```

**Issue**: "No instrumentation detected"
```bash
# Verify driver is calling aflCall instructions
# Check QEMU boots and loads your driver
# Test manually first before fuzzing
```

---

## Legal Disclaimer

This guide is provided for educational and authorized security research purposes only. Users are responsible for:

- Obtaining proper authorization before testing
- Complying with all applicable laws and regulations
- Following responsible disclosure practices
- Respecting intellectual property rights
- Using this information ethically and legally

Unauthorized access to computer systems is illegal. Always conduct security research within the bounds of authorization and applicable law.

---

## Conclusion

TriforceAFL is a powerful tool for discovering deep kernel vulnerabilities. When used responsibly and with proper authorization, it can help improve the security of operating systems including Apple's platforms.

**Key Takeaways:**
1. Always get authorization before testing
2. Start with simple targets (Linux syscalls) before attempting macOS/XNU
3. macOS fuzzing is slower - consider using Linux VM
4. Report findings responsibly through proper channels
5. Follow Apple's security bounty program guidelines

Happy (authorized) fuzzing! 🔒🔍

---

**Last Updated**: 2025
**Author**: Security Research Team
**License**: See repository LICENSE file
