# Google Security Vulnerability Reporting Guide

## Comprehensive Guide for Reporting Vulnerabilities in Google Products

This guide provides detailed information for security researchers using TriforceAFL to discover and report vulnerabilities in Google products including Android, Chrome, ChromeOS, Google Cloud Platform, and other Google services.

---

## 📞 Quick Reference

| Item | Information |
|------|-------------|
| **Bug Bounty Portal** | https://bughunters.google.com/ |
| **General VRP** | https://g.co/vrp |
| **Android Security** | https://source.android.com/security/overview/updates-resources |
| **Chrome Security** | https://www.chromium.org/Home/chromium-security |
| **Response Time** | 24-72 hours (typically) |
| **Max Bounty** | $1,000,000+ (Android) |
| **Disclosure** | 90 days (Project Zero standard) |

---

## Table of Contents

1. [Google Vulnerability Reward Programs](#google-vulnerability-reward-programs)
2. [Android Security Research](#android-security-research)
3. [Chrome Browser Research](#chrome-browser-research)
4. [Google Cloud Platform](#google-cloud-platform)
5. [Report Submission](#report-submission)
6. [Bounty Rewards](#bounty-rewards)
7. [Legal & Safe Harbor](#legal--safe-harbor)
8. [Tools & Resources](#tools--resources)

---

## Google Vulnerability Reward Programs

### Active Programs (2025)

| Program | Scope | Max Reward | Submission Portal |
|---------|-------|------------|-------------------|
| **Android Security Rewards (ASR)** | Android OS, framework, kernel | $1,000,000+ | https://bughunters.google.com/about/rules/6171833274204160/android-and-google-devices-security-reward-program-rules |
| **Chrome Vulnerability Rewards** | Chrome browser, ChromeOS | $500,000 | https://bughunters.google.com/about/rules/5745167867576320/chrome-vulnerability-reward-program-rules |
| **Google Play Security Rewards** | Apps on Google Play | $20,000 | https://bughunters.google.com/about/rules/6625378258649088/google-play-security-reward-program-rules |
| **Google VRP** | Google web properties, services | $31,337 | https://bughunters.google.com/about/rules/6521337925468160/google-and-alphabet-vulnerability-reward-program-vrp-rules |
| **Abuse VRP** | Spam, phishing, malware distribution | $5,000 | https://bughunters.google.com/about/rules/5432673380507648/abuse-vulnerability-rewards-program-rules |
| **Data Protection Reward** | Data exposure issues | $50,000 | https://bughunters.google.com/ |

### Program Highlights

**Android Security Rewards**:
- 💰 Base rewards: $1,000 - $1,000,000
- 🏆 Developer Preview bonus: Up to 50% extra
- 📱 Pixel exclusive: Up to $1,500,000
- 🔥 Exploit chains: Rewards multiplied

**Chrome Rewards**:
- 💰 Base rewards: $500 - $500,000
- 🎯 Sandbox escapes: Premium rewards
- 🔗 Exploit chains: Increased rewards
- 💻 ChromeOS vulnerabilities: Up to $150,000

---

## Android Security Research

### Android Architecture for Fuzzing

```
Android Stack
├── Linux Kernel (AOSP)
│   ├── Binder IPC ⭐⭐⭐⭐⭐ (Highest Priority)
│   ├── Device Drivers ⭐⭐⭐⭐
│   ├── SELinux ⭐⭐⭐
│   └── Memory Management ⭐⭐⭐
├── Hardware Abstraction Layer (HAL)
│   ├── Camera HAL ⭐⭐⭐⭐
│   ├── Biometric HAL ⭐⭐⭐⭐
│   ├── Audio HAL ⭐⭐⭐
│   └── Graphics HAL ⭐⭐⭐⭐
├── Native Libraries
│   ├── Media Frameworks ⭐⭐⭐⭐⭐
│   ├── WebView (Chromium) ⭐⭐⭐⭐
│   ├── Native Services ⭐⭐⭐
│   └── libc/Bionic ⭐⭐⭐
└── Android Framework
    ├── System Services ⭐⭐⭐⭐
    ├── Package Manager ⭐⭐⭐
    └── Activity Manager ⭐⭐⭐
```

### High-Value Android Targets

#### 1. Binder IPC (Critical) ⭐⭐⭐⭐⭐

**Location**: `/dev/binder`, `/dev/hwbinder`, `/dev/vndbinder`

**Why Important**:
- Core Android IPC mechanism
- Used by all system services
- Kernel attack surface
- History of critical vulnerabilities

**Fuzzing Strategy**:
```c
// Example Binder fuzzing
#include <linux/android/binder.h>

int fuzz_binder(char *input, size_t len) {
    int fd = open("/dev/binder", O_RDWR);

    struct binder_write_read bwr;
    bwr.write_buffer = (unsigned long)input;
    bwr.write_size = len;
    bwr.read_size = 0;

    ioctl(fd, BINDER_WRITE_READ, &bwr);

    close(fd);
}
```

**Reward Range**: $50,000 - $250,000+

**Notable CVEs**:
- CVE-2019-2215 (Bad Binder) - $7,500
- Multiple Binder UAF vulnerabilities

---

#### 2. Media Frameworks (Stagefright etc.) ⭐⭐⭐⭐⭐

**Components**:
- `libstagefright.so`
- `mediaserver`
- `mediadrmserver`
- `codec2` (newer)

**Why Important**:
- Parses untrusted media files
- Processes remote content
- History of RCE vulnerabilities
- Can be remotely exploited (MMS, browser)

**Fuzzing Strategy**:
```bash
# Fuzz media codecs
./afl-fuzz -i media_samples/ -o findings/ \
    /system/bin/mediaserver @@

# Target specific codecs
# H.264, H.265, VP8, VP9, AAC, MP3, etc.
```

**File Formats to Fuzz**:
- Video: MP4, AVI, MKV, 3GP, WebM
- Audio: MP3, AAC, FLAC, OGG
- Images: JPEG, PNG, GIF, WebP

**Reward Range**: $20,000 - $150,000

**Famous Bugs**:
- Stagefright (2015) - Billion+ devices affected
- Multiple codec vulnerabilities

---

#### 3. Hardware Abstraction Layer (HAL) ⭐⭐⭐⭐

**High-Value HALs**:

```
Camera HAL
├── Location: /vendor/lib64/hw/camera.*
├── Attack Surface: Image processing, metadata
├── Reward: $30,000 - $100,000
└── Notable: CVE-2019-2234

Biometric HAL (Fingerprint/Face)
├── Location: /vendor/lib64/hw/fingerprint.*, /vendor/lib64/hw/face.*
├── Attack Surface: Enrollment, authentication
├── Reward: $40,000 - $150,000
└── Impact: Unlock bypass

Audio HAL
├── Location: /vendor/lib64/hw/audio.*
├── Attack Surface: Audio stream processing
├── Reward: $20,000 - $80,000
└── Notable: Multiple heap overflows

Graphics HAL
├── Location: /vendor/lib64/hw/gralloc.*, /vendor/lib64/hw/hwcomposer.*
├── Attack Surface: Buffer management, composition
├── Reward: $30,000 - $100,000
└── Notable: Memory corruption bugs
```

**Fuzzing Approach**:
```c
// Example: Fuzzing Camera HAL
#include <hardware/camera3.h>

void fuzz_camera_hal(uint8_t *data, size_t size) {
    camera3_device_t *device;
    // Initialize camera HAL
    hw_get_module(CAMERA_HARDWARE_MODULE_ID, &module);

    // Send fuzzed data to HAL methods
    // process_capture_request()
    // configure_streams()
    // etc.
}
```

---

#### 4. Android System Services ⭐⭐⭐⭐

**Critical Services**:

```java
// System Server Services (Java)
PackageManagerService      // App installation, permissions
ActivityManagerService     // App lifecycle
WindowManagerService       // UI management
TelephonyManager          // Cellular communication
LocationManagerService    // GPS/location

// Native Services (C++)
SurfaceFlinger            // Graphics composition
AudioFlinger             // Audio mixing
DrmServer                // DRM/media protection
```

**Fuzzing Strategy**:
```java
// Example: Fuzz PackageManager via Binder
IPackageManager pm = IPackageManager.Stub.asInterface(
    ServiceManager.getService("package"));

// Send malformed package info
PackageInfo fuzzedPackage = createFuzzedPackage(input);
pm.installPackage(fuzzedPackage);
```

**Reward Range**: $15,000 - $80,000

---

### Android Kernel Fuzzing with TriforceAFL

#### Building AOSP Kernel

```bash
# Clone AOSP kernel
git clone https://android.googlesource.com/kernel/common
cd common
git checkout android-mainline

# Configure for fuzzing
make ARCH=arm64 defconfig
make ARCH=arm64 menuconfig
# Enable KASAN, disable KASLR

# Build
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```

#### Creating Android Fuzzing Driver

```c
/*
 * Android Kernel Fuzzing Driver
 * Targets: Binder, Ashmem, ION, etc.
 */

#include <linux/module.h>
#include <linux/binder.h>

// AFL instrumentation
static inline void aflCall(int op, unsigned long arg1, unsigned long arg2) {
    __asm__ volatile (".byte 0x0f, 0x24\n" : : "D"(op), "S"(arg1), "d"(arg2));
}

static int __init android_fuzzer_init(void) {
    char *test_buf;
    size_t test_size;
    struct binder_write_read bwr;

    aflCall(AFL_START_FORKSERVER, 0, 0);

    test_buf = kmalloc(65536, GFP_KERNEL);

    while (1) {
        test_size = aflCall(AFL_GET_WORK, (unsigned long)test_buf, 65536);
        aflCall(AFL_START_WORK, (unsigned long)&trace_range, 0);

        // Target Binder IPC
        bwr.write_buffer = (binder_uintptr_t)test_buf;
        bwr.write_size = test_size;
        bwr.read_size = 0;

        // This would normally go through syscall path
        // For fuzzing, we call directly
        binder_ioctl(NULL, BINDER_WRITE_READ, (unsigned long)&bwr);

        aflCall(AFL_DONE_WORK, 0, 0);
    }

    return 0;
}

module_init(android_fuzzer_init);
```

---

## Chrome Browser Research

### Chrome Architecture

```
Chrome Multi-Process Architecture
├── Browser Process (Trusted)
│   ├── UI Rendering
│   ├── Network Service
│   ├── File Access
│   └── Extension Management
├── Renderer Processes (Sandboxed)
│   ├── Blink (HTML/CSS Engine)
│   ├── V8 (JavaScript Engine) ⭐⭐⭐⭐⭐
│   ├── Skia (Graphics)
│   └── WebGL/Canvas
├── GPU Process (Sandboxed)
│   ├── Graphics Acceleration
│   ├── Video Decoding
│   └── WebGL Rendering
└── Utility Processes
    ├── Audio Service
    ├── Data Decoder
    └── Network Service
```

### High-Value Chrome Targets

#### 1. V8 JavaScript Engine ⭐⭐⭐⭐⭐

**Why Important**:
- Executes untrusted JavaScript
- JIT compilation complexity
- Type confusion bugs common
- Direct RCE potential

**Fuzzing Strategy**:
```javascript
// V8 fuzzing with custom harness
// Use Fuzzilli, jsfunfuzz, or custom mutator

// Example vulnerable patterns to look for:
let arr = [1, 2, 3];
arr.length = 0;  // Resize
arr[10] = 42;    // Out-of-bounds write (if bug exists)

// Type confusion
function vuln(a) {
    let x = a ? {} : [];
    return x[0];  // Type confusion if JIT optimizes incorrectly
}
```

**Tools**:
- Fuzzilli: https://github.com/googleprojectzero/fuzzilli
- Clusterfuzz: https://google.github.io/clusterfuzz/

**Reward Range**: $10,000 - $500,000

**Notable Bugs**:
- Multiple V8 type confusion → RCE
- JIT optimization bugs

---

#### 2. Blink Rendering Engine ⭐⭐⭐⭐

**Components**:
- HTML Parser
- CSS Engine
- DOM Implementation
- Web APIs

**Fuzzing Targets**:
```html
<!-- Fuzz HTML parsing -->
<!DOCTYPE html>
<svg><foreignObject><math><mtext><table>
<!-- Deeply nested, malformed structures -->

<!-- Fuzz CSS -->
<style>
* { property: value; }
.class { malformed-css-here; }
</style>

<!-- Fuzz DOM APIs -->
<script>
let elem = document.createElement('div');
elem.innerHTML = FUZZED_INPUT;
// Trigger parsing, layout, rendering
</script>
```

**Reward Range**: $5,000 - $100,000

---

#### 3. Sandbox Escapes ⭐⭐⭐⭐⭐

**Critical Value**:
- Renderer → Browser process escape
- Highest Chrome rewards
- Full system compromise

**Attack Surfaces**:
- IPC (Mojo interfaces)
- Shared memory
- File descriptors
- GPU process communication

**Reward Range**: $50,000 - $500,000

---

### ChromeOS Kernel

**Targets**:
- Linux kernel (Chromium-specific patches)
- Chrome OS system services
- Container runtime (Crostini)
- Android compatibility (ARC++)

**Reward Range**: $50,000 - $150,000

---

## Google Cloud Platform

### GCP Security Research

#### Authorization

✅ **Allowed** (on your own projects):
- Testing your own GCP VMs
- Testing your own Cloud Functions
- Testing your own App Engine apps
- Security research on your resources

❌ **Prohibited**:
- Testing other customers' resources
- DoS attacks
- Crypto mining
- Scanning GCP infrastructure
- Accessing production data

#### Contact for GCP Issues

**Email**: gcp-vulnerabilities@google.com
**Portal**: https://bughunters.google.com/

### High-Value GCP Targets

1. **Compute Engine VM Escape**
   ```
   Impact: Break out of GCP VM to host
   Reward: $20,000 - $31,337
   ```

2. **Cloud Functions Sandbox Escape**
   ```
   Impact: Escape Node.js/Python sandbox
   Reward: $10,000 - $31,337
   ```

3. **IAM Bypass**
   ```
   Impact: Unauthorized access to resources
   Reward: $15,000 - $31,337
   ```

4. **Kubernetes Engine (GKE)**
   ```
   Impact: Container/cluster compromise
   Reward: $10,000 - $25,000
   ```

---

## Report Submission

### Google Bug Hunters Platform

**URL**: https://bughunters.google.com/

**Account Setup**:
1. Sign in with Google account
2. Complete profile
3. Read program rules
4. Submit reports through portal

### Report Template

```markdown
**Title**: [Clear, concise vulnerability description]

---

## Summary
[One-sentence summary of the vulnerability and its impact]

## Product
- Product: [Android / Chrome / GCP / etc.]
- Version: [Specific version number]
- Component: [Affected component]
- Platform: [Device/OS if relevant]

## Vulnerability Details

### Type
- [ ] Memory Corruption
- [ ] Logic Error
- [ ] Privilege Escalation
- [ ] Sandbox Escape
- [ ] Information Disclosure
- [ ] Other: __________

**CWE**: CWE-###

### Attack Scenario
- Attack Vector: [Remote / Local / Physical]
- User Interaction: [None / Required]
- Privileges Required: [None / Low / High]

### Security Impact
- Confidentiality Impact: [None / Low / High]
- Integrity Impact: [None / Low / High]
- Availability Impact: [None / Low / High]

**CVSS Score**: [If calculated]

## Technical Analysis

### Root Cause
[Detailed explanation of the underlying issue]

### Attack Path
[Step-by-step description of how to exploit]

### Affected Code
[File path, function name, line number if known]

## Proof of Concept

### Test Environment
- Device: [Pixel 7, Galaxy S23, etc.]
- OS Version: [Android 14, ChromeOS 120, etc.]
- Build: [Build fingerprint]

### Reproduction Steps
1. [Clear, step-by-step instructions]
2. [Include any required setup]
3. [Expected result]

### PoC Code/Files
```
[Minimal proof-of-concept code]
[Or attach files if needed]
```

### Crash/Error Output
```
[Logcat output, crash dumps, error messages]
```

### Video/Screenshots
[If helpful, attach demonstration]

## Impact Assessment

### Exploitability
[Discuss how easy/difficult to exploit]

### Real-World Impact
[What can an attacker achieve?]

### Affected Users
[How many users/devices affected?]

## Suggested Fix
[Optional: Propose how to remediate]

## Additional Notes
[Any other relevant information]

---

**Researcher**: [Your name/handle]
**Contact**: [Email]
**Date**: [YYYY-MM-DD]
```

### Submission Best Practices

✅ **Do**:
- Submit one vulnerability per report
- Provide clear reproduction steps
- Include minimal PoC
- Be responsive to questions
- Coordinate disclosure timeline

❌ **Don't**:
- Submit duplicates
- Publicly disclose before fix
- Demand specific timeline
- Test on non-consenting users
- Access real user data

---

## Bounty Rewards

### Android Security Rewards (ASR)

#### Base Rewards

| Category | Description | Reward |
|----------|-------------|--------|
| **Critical** | Remote code execution, no interaction | $15,000 - $30,000 |
| **High** | Code execution, user interaction required | $3,000 - $7,000 |
| **Moderate** | Unauthorized data access | $1,000 - $3,000 |
| **Low** | Security feature bypass | $500 - $1,000 |

#### Reward Modifiers

**Quality Multipliers**:
- ✅ **Exploit chain**: 2x - 4x multiplier
- ✅ **Persistence**: Up to 2x
- ✅ **Data exfiltration**: Up to 2x
- ✅ **Remote/proximity attack**: Up to 3x
- ✅ **No user interaction**: Up to 2x

**Developer Preview Bonus**:
- 🎁 +50% for bugs in Android beta/preview

**Pixel Exclusive**:
- 📱 Pixel-specific bugs: +50%
- 📱 Titan M bugs: Up to $1,500,000

**Example Calculation**:
```
Base reward: $30,000 (Critical RCE)
× 2 (Exploit chain)
× 1.5 (Remote attack)
× 1.5 (Developer preview)
= $135,000
```

### Chrome Vulnerability Rewards

| Severity | Description | Base Reward |
|----------|-------------|-------------|
| **Critical** | Arbitrary code execution in browser process | $15,000 - $30,000 |
| **High** | Arbitrary code execution in renderer | $7,500 - $15,000 |
| **Medium** | Security feature bypass | $3,000 - $7,500 |
| **Low** | Information disclosure | $500 - $3,000 |

**Special Categories**:
- 🏆 **Sandbox escape**: +$20,000 - $100,000
- 🏆 **Exploit chains**: Rewards combined + bonus
- 🏆 **Chrome OS**: Up to $150,000

### Reward Comparison

| Vulnerability | Android | Chrome | GCP |
|--------------|---------|--------|-----|
| **RCE (Remote, no interaction)** | Up to $600,000+ | Up to $500,000 | $31,337 |
| **Privilege Escalation** | Up to $250,000 | Up to $100,000 | $20,000 |
| **Sandbox Escape** | Up to $200,000 | Up to $500,000 | $25,000 |
| **Info Disclosure** | Up to $50,000 | Up to $30,000 | $10,000 |

---

## Legal & Safe Harbor

### Google VRP Safe Harbor

Google provides safe harbor for researchers who:
1. Act in good faith
2. Follow program rules
3. Report vulnerabilities privately
4. Don't access user data unnecessarily
5. Don't cause service disruption

**Safe Harbor Policy**: https://bughunters.google.com/about/rules

### Protected Activities

✅ **Covered**:
- Testing on your own Google accounts/devices
- Security research on Google products you use
- Developing PoC exploits for reporting
- Responsible disclosure through Bug Hunters
- Testing Android apps you develop

❌ **Not Covered**:
- Testing on others' accounts/devices
- Accessing real user data
- Public disclosure before patch
- Social engineering
- DoS attacks

### Legal Framework

- **DMCA**: Security research exemption
- **CFAA**: Safe harbor for authorized research
- **Project Zero**: 90-day disclosure standard
- **Export Control**: Be aware of exploit restrictions

---

## Tools & Resources

### Android Development & Security

- **Android Studio**: https://developer.android.com/studio
- **Android Source**: https://source.android.com/
- **AOSP Build**: https://source.android.com/setup/build/building
- **ADB**: https://developer.android.com/studio/command-line/adb

### Chrome Development

- **Chromium Source**: https://chromium.googlesource.com/chromium/src
- **Chrome DevTools**: Built into Chrome
- **V8 Debug**: https://v8.dev/docs/debug

### Fuzzing Tools

- **TriforceAFL**: (This repository)
- **LibFuzzer**: https://llvm.org/docs/LibFuzzer.html
- **Honggfuzz**: https://github.com/google/honggfuzz
- **Syzkaller**: https://github.com/google/syzkaller
- **ClusterFuzz**: https://google.github.io/clusterfuzz/
- **Fuzzilli** (V8): https://github.com/googleprojectzero/fuzzilli

### Google Security Resources

- **Project Zero Blog**: https://googleprojectzero.blogspot.com/
- **Google Security Blog**: https://security.googleblog.com/
- **Android Security Bulletin**: https://source.android.com/security/bulletin
- **Chrome Releases Blog**: https://chromereleases.googleblog.com/

---

## Success Stories

### Notable Android Vulnerabilities

1. **Stagefright (2015)**
   - Researcher: Joshua Drake
   - Component: libstagefright media codecs
   - Impact: Billion+ devices, RCE via MMS
   - Changed Android security landscape

2. **Dirty COW (CVE-2016-5195)**
   - Component: Linux kernel (affects Android)
   - Impact: Privilege escalation on millions of devices

3. **BlueFrag (CVE-2020-0022)**
   - Component: Bluetooth stack
   - Impact: RCE without user interaction
   - Reward: $100,000+

4. **Bad Binder (CVE-2019-2215)**
   - Component: Binder IPC
   - Impact: Privilege escalation
   - Used in real-world exploits

### Chrome Browser Wins

1. **V8 Type Confusion**
   - Multiple instances by various researchers
   - Typical reward: $10,000 - $50,000 each
   - Often used in exploit chains

2. **Renderer → Browser Escape**
   - Mojo IPC vulnerabilities
   - Typical reward: $50,000 - $150,000

---

## Quick Start Checklist

### Android Research
- [ ] Set up Android development environment
- [ ] Build AOSP kernel from source
- [ ] Create fuzzing driver for target component
- [ ] Choose high-value target (Binder, media, HAL)
- [ ] Run fuzzing campaign with TriforceAFL
- [ ] Triage crashes and verify exploitability
- [ ] Prepare detailed report
- [ ] Submit via Bug Hunters platform

### Chrome Research
- [ ] Build Chromium from source
- [ ] Set up fuzzing infrastructure
- [ ] Choose target (V8, Blink, IPC)
- [ ] Run fuzzer (ClusterFuzz, LibFuzzer, etc.)
- [ ] Minimize test cases
- [ ] Verify bugs in latest Chrome
- [ ] Submit via Bug Hunters

---

## Conclusion

Google's vulnerability reward programs are among the most generous in the industry, with rewards up to **$1,500,000** for exceptional Android vulnerabilities. By focusing on high-value components like **Binder IPC**, **media frameworks**, **V8**, and **Chrome sandboxes**, researchers can earn substantial rewards while securing billions of users worldwide.

**Key Success Factors**:
- 🎯 Target high-value components
- ⏰ Invest time in quality research
- 📚 Understand the technology deeply
- 🔧 Use proper tooling (TriforceAFL, etc.)
- 💬 Communicate clearly in reports
- 🤝 Coordinate responsibly with Google

**Remember**:
- Test only on your own devices/accounts
- Report through official channels
- Follow responsible disclosure
- Respect user privacy
- Prioritize user safety

**Good luck with your Google security research!** 🔒🐛

---

**Document Version**: 1.0
**Last Updated**: 2025-01-09
**Maintainer**: Security Research Team
**License**: See repository LICENSE file

**Disclaimer**: This guide is for educational and authorized security research only. Always obtain proper authorization and follow responsible disclosure practices.
