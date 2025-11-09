#!/bin/bash
#
# Example Fuzzing Configuration Script for macOS
#
# This script demonstrates how to set up and run TriforceAFL
# to fuzz a Linux kernel system call as a learning example
#
# Before using this for Apple security research, ensure you have
# proper authorization and understand the legal implications.
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}TriforceAFL Example Fuzzing Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Configuration
WORK_DIR="$(pwd)/fuzzing_workspace"
TRIFORCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_VERSION="5.15.0"

echo -e "${YELLOW}[*] Work Directory: $WORK_DIR${NC}"
echo -e "${YELLOW}[*] TriforceAFL Directory: $TRIFORCE_DIR${NC}"
echo ""

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${GREEN}[+] Checking prerequisites...${NC}"

if ! command_exists curl; then
    echo -e "${RED}[!] curl not found. Install with: brew install curl${NC}"
    exit 1
fi

if [ ! -f "$TRIFORCE_DIR/afl-fuzz" ]; then
    echo -e "${RED}[!] AFL not built. Run make in TriforceAFL directory first.${NC}"
    exit 1
fi

if [ ! -f "$TRIFORCE_DIR/afl-qemu-system-trace" ]; then
    echo -e "${RED}[!] QEMU not built. Run: cd qemu_mode && ./build_qemu_support.sh${NC}"
    exit 1
fi

echo -e "${GREEN}[+] All prerequisites met${NC}"
echo ""

# Download and prepare kernel (if not exists)
if [ ! -f "bzImage" ]; then
    echo -e "${YELLOW}[*] Downloading pre-built Linux kernel...${NC}"
    echo -e "${YELLOW}[*] Note: In production, you'd build your own kernel with debug symbols${NC}"

    # For this example, we'll create a placeholder
    # In reality, users should build their own kernel
    cat << 'EOF' > README_KERNEL.txt
To properly use this fuzzer, you need a Linux kernel:

Option 1: Download pre-built kernel
  wget https://github.com/google/AFL/raw/master/qemu_mode/qemu/pc-bios/bios-256k.bin

Option 2: Build your own (recommended)
  # Download kernel source
  wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
  tar xf linux-5.15.tar.xz
  cd linux-5.15

  # Configure
  make defconfig
  make kvmconfig

  # Important: Enable debug symbols
  ./scripts/config -e DEBUG_INFO
  ./scripts/config -e DEBUG_INFO_DWARF4
  ./scripts/config -d RANDOMIZE_BASE  # Disable KASLR for fuzzing

  # Build
  make -j$(sysctl -n hw.ncpu)

  # Copy kernel
  cp arch/x86/boot/bzImage ../bzImage

For Apple security research:
  - Building XNU is complex: https://github.com/apple/darwin-xnu
  - Consider using Linux first to learn the fuzzing workflow
  - Then adapt techniques to macOS/iOS targets
EOF

    echo -e "${YELLOW}[*] Created README_KERNEL.txt with instructions${NC}"
    echo -e "${YELLOW}[*] Please provide bzImage kernel file${NC}"
    echo ""
fi

# Create minimal fuzzing driver
echo -e "${GREEN}[+] Creating example fuzzing driver...${NC}"

mkdir -p driver_source
cat > driver_source/fuzzer_driver.c << 'DRIVER_EOF'
/*
 * Example AFL Fuzzing Driver for Linux Kernel
 *
 * This driver demonstrates how to:
 * 1. Start AFL fork server
 * 2. Receive test cases
 * 3. Invoke target code
 * 4. Report results
 *
 * For production use, adapt this to your specific target.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/delay.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Security Researcher");
MODULE_DESCRIPTION("AFL Full-System Fuzzing Driver - Example");

/* AFL Communication Instructions */
static inline long aflCall(long op, unsigned long arg1, unsigned long arg2) {
    long ret;
    __asm__ volatile (
        ".byte 0x0f, 0x24\n\t"
        : "=a"(ret)
        : "D"(op), "S"(arg1), "d"(arg2)
        : "memory"
    );
    return ret;
}

#define AFL_START_FORKSERVER 1
#define AFL_GET_WORK 2
#define AFL_START_WORK 3
#define AFL_DONE_WORK 4

/* Trace range structure */
struct trace_range {
    unsigned long start;
    unsigned long end;
} __attribute__((packed));

/* Example vulnerable function (for demonstration only) */
static void example_vulnerable_parser(char *buf, size_t len) {
    char stack_buffer[256];
    size_t i;

    /* This is intentionally vulnerable for demonstration */
    /* In real fuzzing, you'd target actual kernel code */

    if (len > sizeof(stack_buffer)) {
        /* Simulate finding a buffer overflow */
        pr_err("FUZZER: Potential overflow detected! len=%zu\n", len);
        len = sizeof(stack_buffer);
    }

    /* Copy data (safely in this example) */
    for (i = 0; i < len && i < sizeof(stack_buffer); i++) {
        stack_buffer[i] = buf[i];
    }

    /* Simulate various code paths based on input */
    if (len >= 4) {
        u32 magic = *(u32*)buf;

        switch (magic) {
        case 0x41414141: /* "AAAA" */
            pr_info("FUZZER: Path A taken\n");
            break;
        case 0x42424242: /* "BBBB" */
            pr_info("FUZZER: Path B taken\n");
            break;
        case 0x43434343: /* "CCCC" */
            pr_info("FUZZER: Path C taken\n");
            /* Simulate a bug condition */
            if (len > 100) {
                pr_err("FUZZER: Simulated bug triggered!\n");
            }
            break;
        default:
            pr_info("FUZZER: Default path\n");
            break;
        }
    }
}

static int __init fuzzer_init(void) {
    char *test_buf;
    long test_size;
    struct trace_range range;
    unsigned long iteration = 0;

    pr_info("=== AFL Fuzzing Driver Loaded ===\n");
    pr_info("Starting AFL Fork Server...\n");

    /* Allocate buffer for test cases */
    test_buf = kmalloc(128 * 1024, GFP_KERNEL);
    if (!test_buf) {
        pr_err("FUZZER: Failed to allocate test buffer\n");
        return -ENOMEM;
    }

    /* Start AFL fork server - all code after this runs in forked VMs */
    aflCall(AFL_START_FORKSERVER, 0, 0);
    pr_info("FUZZER: Fork server started\n");

    /* Main fuzzing loop */
    while (1) {
        memset(test_buf, 0, 128 * 1024);

        /* Get next test case from AFL */
        test_size = aflCall(AFL_GET_WORK, (unsigned long)test_buf, 128 * 1024);

        if (test_size < 0) {
            pr_err("FUZZER: Failed to get work (ret=%ld)\n", test_size);
            aflCall(AFL_DONE_WORK, 1, 0);
            continue;
        }

        pr_info("FUZZER: Iteration %lu, test_size=%ld\n", iteration++, test_size);

        /*
         * Set up tracing range
         * In production, use actual addresses from /proc/kallsyms
         * Example: grep "target_function" /proc/kallsyms
         */
        range.start = (unsigned long)example_vulnerable_parser;
        range.end = (unsigned long)example_vulnerable_parser + 0x1000;

        /* Enable AFL tracing for target function */
        aflCall(AFL_START_WORK, (unsigned long)&range, 0);

        /* ====================================
         * INVOKE TARGET CODE HERE
         * ====================================
         * This is where you call the kernel function you want to fuzz.
         * Examples:
         *   - System call handler: do_syscall_64(...)
         *   - File system function: vfs_read(...)
         *   - Network function: tcp_v4_rcv(...)
         *   - Driver function: ioctl handler
         */

        /* For this example, call our demo function */
        example_vulnerable_parser(test_buf, test_size);

        /* Test case completed successfully (exit code 0) */
        aflCall(AFL_DONE_WORK, 0, 0);

        /*
         * Note: If a kernel panic occurs, QEMU will catch it
         * and report it to AFL automatically (if -aflPanicAddr is set)
         */
    }

    kfree(test_buf);
    return 0;
}

static void __exit fuzzer_exit(void) {
    pr_info("=== AFL Fuzzing Driver Unloaded ===\n");
}

module_init(fuzzer_init);
module_exit(fuzzer_exit);
DRIVER_EOF

# Create Makefile for driver
cat > driver_source/Makefile << 'MAKEFILE_EOF'
obj-m += fuzzer_driver.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
MAKEFILE_EOF

echo -e "${GREEN}[+] Driver source created in driver_source/${NC}"
echo ""

# Create initial test inputs
echo -e "${GREEN}[+] Creating initial test inputs...${NC}"

mkdir -p inputs
echo -n "AAAA" > inputs/test_magic_a
echo -n "BBBB" > inputs/test_magic_b
echo -n "CCCC" > inputs/test_magic_c
dd if=/dev/zero bs=1 count=50 > inputs/test_zeros 2>/dev/null
dd if=/dev/urandom bs=1 count=100 > inputs/test_random 2>/dev/null
python3 -c "import sys; sys.stdout.buffer.write(b'\\xff' * 200)" > inputs/test_maxbytes

echo -e "${GREEN}[+] Created $(ls inputs/ | wc -l) initial test cases${NC}"
echo ""

# Create fuzzing launch script
echo -e "${GREEN}[+] Creating launch script...${NC}"

cat > run_fuzzer.sh << 'LAUNCH_EOF'
#!/bin/bash

# AFL Fuzzing Launch Script
set -e

TRIFORCE_DIR="TRIFORCE_PLACEHOLDER"
WORK_DIR="$(pwd)"

# Check for required files
if [ ! -f "bzImage" ]; then
    echo "Error: bzImage not found!"
    echo "Please provide a Linux kernel image. See README_KERNEL.txt"
    exit 1
fi

if [ ! -f "initramfs.cpio.gz" ]; then
    echo "Error: initramfs.cpio.gz not found!"
    echo "Please build initramfs with fuzzing driver. See instructions below."
    exit 1
fi

# Get panic address (you need to update this from your kernel)
# Boot the kernel and run: grep " panic$" /proc/kallsyms
PANIC_ADDR=${AFL_PANIC_ADDR:-0xffffffff81000000}
DMESG_ADDR=${AFL_DMESG_ADDR:-0xffffffff81000000}

echo "==================================="
echo "Starting AFL Fuzzing Campaign"
echo "==================================="
echo "Work Dir: $WORK_DIR"
echo "Panic Addr: $PANIC_ADDR"
echo "Dmesg Addr: $DMESG_ADDR"
echo ""
echo "Note: On macOS, expect 10x slower performance than Linux"
echo "      Consider running in a Linux VM for better results"
echo ""

# Run fuzzer
"$TRIFORCE_DIR/afl-fuzz" \
    -i inputs \
    -o outputs \
    -m 2048 \
    -t 10000 \
    -QQ -- \
    "$TRIFORCE_DIR/afl-qemu-system-trace" \
        -kernel bzImage \
        -initrd initramfs.cpio.gz \
        -m 2G \
        -nographic \
        -append "console=ttyS0 nokaslr quiet" \
        -aflPanicAddr "$PANIC_ADDR" \
        -aflDmesgAddr "$DMESG_ADDR" \
        -aflFile @@

echo ""
echo "Fuzzing session completed!"
echo "Check outputs/ directory for results"
LAUNCH_EOF

# Replace placeholder with actual path
sed -i.bak "s|TRIFORCE_PLACEHOLDER|$TRIFORCE_DIR|g" run_fuzzer.sh
rm run_fuzzer.sh.bak
chmod +x run_fuzzer.sh

echo -e "${GREEN}[+] Launch script created: run_fuzzer.sh${NC}"
echo ""

# Create parallel fuzzing script
cat > run_parallel.sh << 'PARALLEL_EOF'
#!/bin/bash

# Parallel Fuzzing Launch Script
# Runs multiple AFL instances for better coverage

TRIFORCE_DIR="TRIFORCE_PLACEHOLDER"
NUM_FUZZERS=${1:-4}

echo "Starting $NUM_FUZZERS parallel fuzzers..."
echo "Use tmux or screen to manage multiple instances"
echo ""

for i in $(seq 1 $NUM_FUZZERS); do
    if [ $i -eq 1 ]; then
        MODE="-M"
        NAME="master"
    else
        MODE="-S"
        NAME="secondary$i"
    fi

    echo "Fuzzer $i: $NAME"
    echo "  Start with: $0 $MODE fuzzer$NAME"
done

echo ""
echo "Example commands:"
echo "  Terminal 1: ./run_fuzzer.sh -M master"
echo "  Terminal 2: ./run_fuzzer.sh -S secondary2"
echo "  Terminal 3: ./run_fuzzer.sh -S secondary3"
PARALLEL_EOF

sed -i.bak "s|TRIFORCE_PLACEHOLDER|$TRIFORCE_DIR|g" run_parallel.sh
rm run_parallel.sh.bak
chmod +x run_parallel.sh

echo -e "${GREEN}[+] Parallel fuzzing helper created: run_parallel.sh${NC}"
echo ""

# Create README
cat > README.txt << 'README_EOF'
TriforceAFL Fuzzing Workspace
=============================

This workspace contains everything needed to start fuzzing with TriforceAFL.

Directory Structure:
-------------------
- driver_source/     : Kernel module source code for fuzzing driver
- inputs/           : Initial test cases for AFL
- outputs/          : AFL results (created during fuzzing)
- bzImage           : Linux kernel image (you must provide this)
- initramfs.cpio.gz : Initramfs with fuzzing driver (you must build this)

Quick Start:
-----------

1. Build or obtain a Linux kernel
   See README_KERNEL.txt for instructions

2. Build the fuzzing driver
   cd driver_source
   # You'll need kernel headers matching your bzImage
   # This may require building in a Linux environment

3. Create initramfs with the driver
   See MACOS_FUZZING_GUIDE.md for detailed instructions

4. Run the fuzzer
   ./run_fuzzer.sh

Important Notes for macOS:
-------------------------
- Fuzzing performance is 10x slower on macOS vs Linux
- Consider using Docker or a Linux VM for better performance
- Only full-system mode (-QQ) works on macOS
- Disable crash reporting (see setup_macos.sh)

For Apple Security Research:
---------------------------
- Start by fuzzing Linux to learn the workflow
- Once comfortable, adapt to XNU/macOS targets
- Always obtain proper authorization
- Report vulnerabilities to product-security@apple.com
- Follow responsible disclosure practices

Resources:
---------
- TriforceAFL: https://github.com/nccgroup/TriforceAFL
- AFL Documentation: See docs/ directory
- Fuzzing Guide: MACOS_FUZZING_GUIDE.md
- Apple Security: https://security.apple.com/

Troubleshooting:
---------------
- Fork server timeout: Increase -t value (e.g., -t 20000)
- No coverage: Verify driver loads and calls aflCall instructions
- QEMU crashes: Check kernel command line and memory settings
- Slow performance: Normal on macOS, try Linux VM

For questions or issues, see the TriforceAFL documentation.
README_EOF

# Create summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Workspace created at: $WORK_DIR${NC}"
echo ""
echo "Files created:"
echo "  ✓ driver_source/fuzzer_driver.c - Example fuzzing driver"
echo "  ✓ driver_source/Makefile - Build configuration"
echo "  ✓ inputs/ - Initial test cases (6 files)"
echo "  ✓ run_fuzzer.sh - Launch fuzzing campaign"
echo "  ✓ run_parallel.sh - Helper for parallel fuzzing"
echo "  ✓ README.txt - Workspace documentation"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Provide a Linux kernel:"
echo "   - Download or build bzImage"
echo "   - See README_KERNEL.txt for instructions"
echo ""
echo "2. Build the fuzzing driver:"
echo "   cd driver_source"
echo "   # Build as kernel module (requires kernel headers)"
echo ""
echo "3. Create initramfs with driver:"
echo "   # See $TRIFORCE_DIR/MACOS_FUZZING_GUIDE.md"
echo "   # Section: 'Building the Driver into initramfs'"
echo ""
echo "4. Start fuzzing:"
echo "   cd $WORK_DIR"
echo "   ./run_fuzzer.sh"
echo ""
echo -e "${YELLOW}For Apple Security Research:${NC}"
echo "   - Read MACOS_FUZZING_GUIDE.md thoroughly"
echo "   - Ensure proper authorization before testing"
echo "   - Report findings to product-security@apple.com"
echo ""
echo -e "${GREEN}Happy (authorized) fuzzing!${NC}"
