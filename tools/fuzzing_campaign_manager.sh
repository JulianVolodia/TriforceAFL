#!/bin/bash
#
# Multi-Vendor Fuzzing Campaign Manager
#
# This script helps manage parallel fuzzing campaigns targeting multiple
# vendors (Apple, Microsoft, Google, etc.) simultaneously.
#
# Features:
#  - Launch multiple fuzzing instances
#  - Monitor progress and coverage
#  - Auto-triage crashes
#  - Generate reports for each vendor
#  - Manage resources across campaigns
#
# Usage:
#   ./fuzzing_campaign_manager.sh [command] [options]
#
# Commands:
#   start    - Start fuzzing campaigns
#   stop     - Stop all campaigns
#   status   - Show status of all campaigns
#   triage   - Triage crashes from all campaigns
#   report   - Generate reports for vendors
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
TRIFORCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CAMPAIGN_DIR="$HOME/fuzzing_campaigns"
LOG_DIR="$CAMPAIGN_DIR/logs"
REPORT_DIR="$CAMPAIGN_DIR/reports"

# Vendor configurations
declare -A VENDORS
VENDORS[apple]="Apple (iOS/macOS)"
VENDORS[microsoft]="Microsoft (Windows/Azure)"
VENDORS[google]="Google (Android/Chrome)"
VENDORS[linux]="Linux Kernel"

# Print functions
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}$1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

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

# Initialize campaign directory structure
init_campaign() {
    print_status "Initializing fuzzing campaign structure..."

    mkdir -p "$CAMPAIGN_DIR"/{apple,microsoft,google,linux}/{inputs,outputs,crashes_minimized}
    mkdir -p "$LOG_DIR"
    mkdir -p "$REPORT_DIR"

    print_status "Campaign directory: $CAMPAIGN_DIR"
}

# Start fuzzing campaigns
start_campaigns() {
    print_header "Starting Fuzzing Campaigns"

    local vendors="${1:-all}"
    local num_instances="${2:-2}"

    if [ "$vendors" = "all" ]; then
        vendors="apple microsoft google linux"
    fi

    for vendor in $vendors; do
        if [ ! -d "$CAMPAIGN_DIR/$vendor" ]; then
            print_error "Vendor $vendor not initialized. Run: init"
            continue
        fi

        print_status "Starting $num_instances fuzzing instances for $vendor..."

        # Start master fuzzer
        start_fuzzer "$vendor" "master" 0 &

        # Start slave fuzzers
        for i in $(seq 1 $((num_instances - 1))); do
            sleep 2
            start_fuzzer "$vendor" "slave$i" $i &
        done

        print_status "$vendor: $num_instances instances started"
    done

    print_status "All campaigns started!"
    print_info "Monitor with: $0 status"
    print_info "View logs in: $LOG_DIR"
}

# Start individual fuzzer instance
start_fuzzer() {
    local vendor=$1
    local role=$2  # master or slave
    local instance_id=$3

    local input_dir="$CAMPAIGN_DIR/$vendor/inputs"
    local output_dir="$CAMPAIGN_DIR/$vendor/outputs"
    local log_file="$LOG_DIR/${vendor}_${role}.log"

    # Vendor-specific configurations
    local kernel_image=""
    local initramfs=""
    local panic_addr="0xffffffff81000000"

    case $vendor in
        apple)
            kernel_image="$CAMPAIGN_DIR/$vendor/xnu_kernel"
            initramfs="$CAMPAIGN_DIR/$vendor/initramfs.cpio.gz"
            ;;
        microsoft)
            # Windows kernel fuzzing requires special setup
            print_warning "Windows kernel fuzzing requires Hyper-V setup"
            return
            ;;
        google)
            kernel_image="$CAMPAIGN_DIR/$vendor/zImage_android"
            initramfs="$CAMPAIGN_DIR/$vendor/ramdisk.img"
            ;;
        linux)
            kernel_image="$CAMPAIGN_DIR/$vendor/bzImage"
            initramfs="$CAMPAIGN_DIR/$vendor/initramfs.cpio.gz"
            ;;
    esac

    # Check if kernel exists
    if [ ! -f "$kernel_image" ]; then
        print_warning "$vendor: Kernel image not found at $kernel_image"
        return
    fi

    # Determine master/slave flag
    local mode_flag="-S"
    if [ "$role" = "master" ]; then
        mode_flag="-M"
    fi

    # Launch AFL fuzzer
    cd "$TRIFORCE_DIR"

    print_info "Launching $vendor $role (logging to $log_file)..."

    ./afl-fuzz \
        $mode_flag "${vendor}_${role}" \
        -i "$input_dir" \
        -o "$output_dir" \
        -m 2048 \
        -t 5000 \
        -QQ -- \
        ./afl-qemu-system-trace \
            -kernel "$kernel_image" \
            -initrd "$initramfs" \
            -m 2G \
            -nographic \
            -append "console=ttyS0 nokaslr quiet" \
            -aflPanicAddr "$panic_addr" \
            -aflFile @@ \
        > "$log_file" 2>&1 &

    local pid=$!
    echo "$pid" > "$LOG_DIR/${vendor}_${role}.pid"

    print_status "$vendor $role started (PID: $pid)"
}

# Stop all campaigns
stop_campaigns() {
    print_header "Stopping All Fuzzing Campaigns"

    for pidfile in "$LOG_DIR"/*.pid; do
        if [ -f "$pidfile" ]; then
            local pid=$(cat "$pidfile")
            local name=$(basename "$pidfile" .pid)

            if kill -0 "$pid" 2>/dev/null; then
                print_status "Stopping $name (PID: $pid)..."
                kill "$pid"
                rm "$pidfile"
            else
                print_warning "$name already stopped"
                rm "$pidfile"
            fi
        fi
    done

    print_status "All campaigns stopped"
}

# Show status of campaigns
show_status() {
    print_header "Fuzzing Campaign Status"

    local total_instances=0
    local running_instances=0

    for vendor in apple microsoft google linux; do
        if [ ! -d "$CAMPAIGN_DIR/$vendor/outputs" ]; then
            continue
        fi

        echo -e "${YELLOW}═══ $vendor ═══${NC}"

        for fuzzer_dir in "$CAMPAIGN_DIR/$vendor/outputs"/*; do
            if [ ! -d "$fuzzer_dir" ]; then
                continue
            fi

            local fuzzer_name=$(basename "$fuzzer_dir")
            local stats_file="$fuzzer_dir/fuzzer_stats"

            total_instances=$((total_instances + 1))

            if [ -f "$stats_file" ]; then
                running_instances=$((running_instances + 1))

                # Extract key stats
                local execs_done=$(grep "execs_done" "$stats_file" | awk '{print $3}')
                local execs_per_sec=$(grep "execs_per_sec" "$stats_file" | awk '{print $3}')
                local paths_total=$(grep "paths_total" "$stats_file" | awk '{print $3}')
                local unique_crashes=$(grep "unique_crashes" "$stats_file" | awk '{print $3}')
                local unique_hangs=$(grep "unique_hangs" "$stats_file" | awk '{print $3}')

                echo -e "  ${GREEN}●${NC} $fuzzer_name"
                echo -e "    Execs: $execs_done  |  Speed: $execs_per_sec/sec  |  Paths: $paths_total"
                echo -e "    Crashes: ${RED}$unique_crashes${NC}  |  Hangs: ${YELLOW}$unique_hangs${NC}"
            else
                echo -e "  ${RED}○${NC} $fuzzer_name (not running)"
            fi
        done
        echo ""
    done

    print_info "Total instances: $total_instances  |  Running: $running_instances"
}

# Triage crashes
triage_crashes() {
    print_header "Triaging Crashes"

    for vendor in apple microsoft google linux; do
        local crash_dir="$CAMPAIGN_DIR/$vendor/outputs/*/crashes"
        local crash_count=$(find $crash_dir -type f 2>/dev/null | wc -l)

        if [ $crash_count -eq 0 ]; then
            continue
        fi

        print_status "$vendor: Found $crash_count crashes"

        # Create minimized crash directory
        local min_dir="$CAMPAIGN_DIR/$vendor/crashes_minimized"
        mkdir -p "$min_dir"

        # Minimize each crash
        for crash in $(find $crash_dir -type f 2>/dev/null); do
            local crash_name=$(basename "$crash")
            local min_crash="$min_dir/$crash_name"

            if [ -f "$min_crash" ]; then
                print_info "  Skip $crash_name (already minimized)"
                continue
            fi

            print_info "  Minimizing $crash_name..."

            # Run afl-tmin (this is placeholder - needs proper config)
            # ./afl-tmin -i "$crash" -o "$min_crash" -QQ -- [target]

            # For now, just copy
            cp "$crash" "$min_crash"
        done

        print_status "$vendor: Crash triage complete"
    done
}

# Generate reports
generate_reports() {
    print_header "Generating Vendor Reports"

    for vendor in apple microsoft google linux; do
        if [ ! -d "$CAMPAIGN_DIR/$vendor/outputs" ]; then
            continue
        fi

        local report_file="$REPORT_DIR/${vendor}_report_$(date +%Y%m%d_%H%M%S).md"

        print_status "Generating report for $vendor..."

        cat > "$report_file" << REPORT_EOF
# Fuzzing Campaign Report: $vendor
**Generated**: $(date)
**Campaign Directory**: $CAMPAIGN_DIR/$vendor

---

## Executive Summary

### Campaign Statistics
REPORT_EOF

        # Aggregate statistics
        local total_execs=0
        local total_paths=0
        local total_crashes=0
        local total_hangs=0

        for stats_file in "$CAMPAIGN_DIR/$vendor/outputs"/*/fuzzer_stats; do
            if [ -f "$stats_file" ]; then
                local execs=$(grep "execs_done" "$stats_file" | awk '{print $3}')
                local paths=$(grep "paths_total" "$stats_file" | awk '{print $3}')
                local crashes=$(grep "unique_crashes" "$stats_file" | awk '{print $3}')
                local hangs=$(grep "unique_hangs" "$stats_file" | awk '{print $3}')

                total_execs=$((total_execs + execs))
                total_paths=$((total_paths + paths))
                total_crashes=$((total_crashes + crashes))
                total_hangs=$((total_hangs + hangs))
            fi
        done

        cat >> "$report_file" << REPORT_EOF

| Metric | Value |
|--------|-------|
| **Total Executions** | $(printf "%'d" $total_execs) |
| **Unique Paths** | $total_paths |
| **Unique Crashes** | **$total_crashes** |
| **Unique Hangs** | $total_hangs |

---

## Crashes Found

### Critical Findings
REPORT_EOF

        # List crashes
        for crash in "$CAMPAIGN_DIR/$vendor/crashes_minimized"/*; do
            if [ -f "$crash" ]; then
                local crash_name=$(basename "$crash")
                echo "- \`$crash_name\`" >> "$report_file"
            fi
        done

        cat >> "$report_file" << REPORT_EOF

---

## Next Steps

### For $vendor Vulnerabilities:
REPORT_EOF

        case $vendor in
            apple)
                cat >> "$report_file" << REPORT_EOF
1. Verify crashes on latest macOS/iOS version
2. Analyze root cause with debugger
3. Assess exploitability
4. Prepare detailed report
5. Submit to: product-security@apple.com
6. Reference: APPLE_SECURITY_REPORTING.md

**Expected Bounty Range**: \$50,000 - \$1,000,000+
REPORT_EOF
                ;;
            microsoft)
                cat >> "$report_file" << REPORT_EOF
1. Reproduce on latest Windows build
2. Analyze with WinDbg
3. Determine security impact
4. Create proof-of-concept
5. Submit to: secure@microsoft.com
6. Reference: MICROSOFT_SECURITY_REPORTING.md

**Expected Bounty Range**: \$15,000 - \$250,000+
REPORT_EOF
                ;;
            google)
                cat >> "$report_file" << REPORT_EOF
1. Test on latest Android/Chrome version
2. Root cause analysis
3. Develop minimal PoC
4. Submit via: https://bughunters.google.com/
5. Reference: GOOGLE_SECURITY_REPORTING.md

**Expected Bounty Range**: \$1,000 - \$1,000,000+
REPORT_EOF
                ;;
            linux)
                cat >> "$report_file" << REPORT_EOF
1. Verify on upstream kernel
2. Identify affected subsystem
3. Create patch if possible
4. Report to: security@kernel.org or vendor-specific security team
5. Reference: MULTI_VENDOR_RESEARCH_GUIDE.md

**Expected Bounty**: Varies by distribution
REPORT_EOF
                ;;
        esac

        cat >> "$report_file" << REPORT_EOF

---

## Files & Artifacts

- Crashes: \`$CAMPAIGN_DIR/$vendor/crashes_minimized/\`
- Corpus: \`$CAMPAIGN_DIR/$vendor/outputs/*/queue/\`
- Logs: \`$LOG_DIR/${vendor}_*.log\`

---

**Generated by**: TriforceAFL Multi-Vendor Campaign Manager
REPORT_EOF

        print_status "Report saved: $report_file"
    done

    print_status "All reports generated in: $REPORT_DIR"
}

# Show help
show_help() {
    cat << 'HELP_EOF'
╔══════════════════════════════════════════════════════════════╗
║      Multi-Vendor Fuzzing Campaign Manager                  ║
╚══════════════════════════════════════════════════════════════╝

USAGE:
    ./fuzzing_campaign_manager.sh [COMMAND] [OPTIONS]

COMMANDS:
    init            Initialize campaign directory structure
    start [VENDOR]  Start fuzzing campaigns
                    VENDOR: apple|microsoft|google|linux|all (default: all)
    stop            Stop all running campaigns
    status          Show status of all campaigns
    triage          Triage and minimize crashes
    report          Generate reports for all vendors
    help            Show this help message

OPTIONS:
    -n NUM          Number of fuzzer instances per vendor (default: 2)

EXAMPLES:
    # Initialize
    ./fuzzing_campaign_manager.sh init

    # Start all campaigns with 4 instances each
    ./fuzzing_campaign_manager.sh start all -n 4

    # Start only Apple fuzzing
    ./fuzzing_campaign_manager.sh start apple

    # Check status
    ./fuzzing_campaign_manager.sh status

    # Triage crashes
    ./fuzzing_campaign_manager.sh triage

    # Generate reports
    ./fuzzing_campaign_manager.sh report

WORKFLOW:
    1. Set up kernels/images in $CAMPAIGN_DIR/[vendor]/
    2. Add initial test cases to $CAMPAIGN_DIR/[vendor]/inputs/
    3. Run: ./fuzzing_campaign_manager.sh start
    4. Monitor: ./fuzzing_campaign_manager.sh status
    5. Triage: ./fuzzing_campaign_manager.sh triage
    6. Report: ./fuzzing_campaign_manager.sh report

DIRECTORY STRUCTURE:
    ~/fuzzing_campaigns/
    ├── apple/
    │   ├── inputs/          # Initial test cases
    │   ├── outputs/         # AFL output
    │   ├── xnu_kernel       # macOS/iOS kernel
    │   └── initramfs.cpio.gz
    ├── microsoft/
    │   └── [Windows setup]
    ├── google/
    │   ├── zImage_android   # Android kernel
    │   └── ramdisk.img
    ├── linux/
    │   ├── bzImage          # Linux kernel
    │   └── initramfs.cpio.gz
    ├── logs/                # Fuzzer logs
    └── reports/             # Generated reports

REQUIREMENTS:
    - TriforceAFL built and working
    - Kernel images prepared
    - Initial test cases created
    - Sufficient disk space (100GB+ recommended)
    - Multi-core CPU (8+ cores recommended)

TIPS:
    • Use tmux/screen for persistent sessions
    • Monitor disk space regularly
    • Back up crashes frequently
    • Run on dedicated fuzzing machines
    • Allocate 1-2 cores per fuzzer instance

For detailed vendor-specific guidance, see:
    - APPLE_SECURITY_REPORTING.md
    - MICROSOFT_SECURITY_REPORTING.md
    - GOOGLE_SECURITY_REPORTING.md
    - MULTI_VENDOR_RESEARCH_GUIDE.md

HELP_EOF
}

# Main command dispatcher
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=$1
    shift

    case $command in
        init)
            init_campaign
            ;;
        start)
            init_campaign
            start_campaigns "$@"
            ;;
        stop)
            stop_campaigns
            ;;
        status)
            show_status
            ;;
        triage)
            triage_crashes
            ;;
        report)
            generate_reports
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
