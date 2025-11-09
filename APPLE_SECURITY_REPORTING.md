# Apple Security Vulnerability Reporting Guide

## Quick Reference for Responsible Disclosure

This guide provides essential information for security researchers who discover vulnerabilities in Apple products using TriforceAFL or other fuzzing tools.

---

## 📧 Contact Information

### Primary Contact
- **Email**: product-security@apple.com
- **PGP Key**: https://support.apple.com/en-us/HT201220
- **Website**: https://security.apple.com/
- **Bug Bounty**: https://security.apple.com/bounty/

### Response Time
- Initial Response: 48-72 hours
- Updates: Weekly (typically)
- Standard Disclosure: 90 days from report

---

## ✅ Before You Report

### Essential Checklist

- [ ] **Verify the vulnerability is real and reproducible**
  - Test on multiple versions if possible
  - Document exact steps to reproduce
  - Minimize the test case

- [ ] **Confirm it hasn't been reported/patched**
  - Check Apple Security Updates: https://support.apple.com/en-us/HT201222
  - Search CVE database
  - Review recent patches

- [ ] **Assess the security impact**
  - Can it be exploited remotely?
  - Does it require user interaction?
  - What privileges are needed?
  - What can an attacker achieve?

- [ ] **Prepare clear documentation**
  - Root cause analysis
  - Affected versions
  - Proof of concept
  - Reproduction steps

- [ ] **Ensure you're authorized**
  - Did you test on your own devices?
  - Is this authorized research?
  - No unauthorized access occurred?

---

## 📝 Report Template

```
Subject: [Security] [Component] Vulnerability Type - Brief Description

SUMMARY
-------
One-sentence description of the vulnerability and its impact.

Example: "A buffer overflow in IOKit driver XYZ allows local attackers
to execute arbitrary code with kernel privileges."


AFFECTED PRODUCTS & VERSIONS
-----------------------------
List all affected products and version ranges.

Example:
- macOS Ventura 13.0 - 13.4.1
- macOS Monterey 12.0 - 12.6.7
- iOS 16.0 - 16.5.1
- iPadOS 16.0 - 16.5.1

Note: Tested primarily on macOS Ventura 13.4.1


VULNERABILITY CLASSIFICATION
-----------------------------
Primary Type: [Choose most relevant]
- Memory Corruption (Buffer Overflow)
- Memory Corruption (Use-After-Free)
- Memory Corruption (Out-of-Bounds Access)
- Integer Overflow/Underflow
- Logic Error
- Race Condition
- Information Disclosure
- Privilege Escalation
- Authentication Bypass
- [Other]

CVE/CWE References: [If applicable]
- CWE-XXX: Description


ATTACK VECTOR
--------------
Required Access Level:
- [ ] Remote (network-based)
- [ ] Local (requires local access)
- [ ] Physical (requires physical access)

User Interaction:
- [ ] None (zero-click)
- [ ] Minimal (one-click)
- [ ] Significant (multiple steps)

Privileges Required:
- [ ] None (unprivileged user)
- [ ] Low (standard user account)
- [ ] High (admin/root required)

Attack Complexity:
- [ ] Low (easy to exploit)
- [ ] Medium (requires some expertise)
- [ ] High (requires significant expertise)


SECURITY IMPACT
----------------
Potential Consequences: [Check all that apply]
- [ ] Arbitrary Code Execution (Kernel)
- [ ] Arbitrary Code Execution (User)
- [ ] Privilege Escalation (User → Root)
- [ ] Privilege Escalation (User → Kernel)
- [ ] Sandbox Escape
- [ ] Denial of Service (Kernel Panic)
- [ ] Denial of Service (Service Crash)
- [ ] Information Disclosure (Kernel Memory)
- [ ] Information Disclosure (User Data)
- [ ] Bypass Security Controls
- [ ] [Other]

CVSS Score: [If calculated]
Base Score: X.X (Severity)


TECHNICAL DETAILS
------------------
Component/Subsystem:
- Affected Component: [e.g., IOKit driver, kernel extension, system service]
- File/Module: [e.g., com.apple.driver.AppleXYZ]
- Function: [e.g., IOServiceOpen, xyz_ioctl]
- Code Location: [if open source, provide GitHub link with line numbers]

Root Cause:
[Detailed explanation of the vulnerability]

Example:
"The vulnerability exists in the IOKit driver's ioctl handler at
function xyz_process_input(). The driver allocates a fixed-size buffer
of 256 bytes on the stack but fails to validate the user-supplied
length parameter before calling memcpy(). An attacker can provide a
length value greater than 256, causing a stack buffer overflow."

Why It's Exploitable:
[Explain why this bug is security-relevant]

Example:
"This stack buffer overflow is exploitable because:
1. The overflow occurs in kernel context
2. The attacker fully controls the overflow data
3. The function is reachable from unprivileged userspace via IOConnectCallMethod
4. The stack contains return addresses that can be overwritten
5. macOS lacks stack canaries in this code path"

Security Boundaries Crossed:
[Explain what security boundaries are violated]

Example:
"This vulnerability allows an unprivileged user process to:
1. Cross the user/kernel privilege boundary
2. Bypass SMEP/SMAP protections
3. Gain arbitrary kernel code execution
4. Disable System Integrity Protection (SIP)
5. Achieve complete system compromise"


PROOF OF CONCEPT
------------------
Development Environment:
- Testing Platform: macOS Ventura 13.4.1
- Hardware: Mac Mini M1 / MacBook Pro Intel
- Kernel Version: Darwin 22.5.0

Reproduction Steps:
[Step-by-step instructions]

1. Compile the attached proof-of-concept code:
   clang -o poc poc.c -framework IOKit

2. Run the PoC as an unprivileged user:
   ./poc

3. Observe the result:
   - Expected: Kernel panic or code execution
   - Logs: Check Console.app for crash reports

Proof-of-Concept Code:
[Include minimal PoC code or attach as separate file]

```c
// poc.c - Proof of Concept for CVE-XXXX-XXXXX
// Demonstrates buffer overflow in Apple IOKit driver
//
// Compile: clang -o poc poc.c -framework IOKit
// Run: ./poc

#include <stdio.h>
#include <IOKit/IOKitLib.h>

int main() {
    kern_return_t kr;
    io_service_t service;
    io_connect_t connect;

    // Find the vulnerable service
    service = IOServiceGetMatchingService(
        kIOMasterPortDefault,
        IOServiceMatching("AppleVulnerableDriver")
    );

    if (!service) {
        printf("[-] Service not found\n");
        return 1;
    }

    // Open connection
    kr = IOServiceOpen(service, mach_task_self(), 0, &connect);
    if (kr != KERN_SUCCESS) {
        printf("[-] IOServiceOpen failed: 0x%x\n", kr);
        return 1;
    }

    // Craft malicious input (oversized buffer)
    char evil_input[512];
    memset(evil_input, 0x41, sizeof(evil_input));

    // Trigger vulnerability via selector 0
    size_t output_size = 0;
    kr = IOConnectCallMethod(
        connect,
        0,                              // Selector
        NULL, 0,                        // Scalar inputs
        evil_input, sizeof(evil_input), // Struct input (oversized!)
        NULL, NULL,                     // Scalar outputs
        NULL, &output_size              // Struct output
    );

    printf("[+] Exploit sent, return code: 0x%x\n", kr);
    printf("[*] Check for kernel panic...\n");

    IOServiceClose(connect);
    IOObjectRelease(service);

    return 0;
}
```

Crash Log / Debugging Info:
[Include relevant crash logs, kernel panics, or debugging output]

```
panic(cpu 0 caller 0xffffff8012345678): "kernel memory corruption"
Backtrace:
  0xffffff8012345678: panic + 0x...
  0xffffff8012abcdef: xyz_process_input + 0x42
  0xffffff8012fedcba: iokit_user_client_trap + 0x...
```


PROPOSED REMEDIATION
--------------------
[Optional but helpful - suggest how to fix the vulnerability]

Recommended Fix:
1. Add input validation to check length parameter
2. Use safe memory copy functions (strlcpy, bounds checking)
3. Consider using heap allocation for large buffers
4. Add appropriate error handling

Example Patch Concept:
```c
// Before (vulnerable):
void xyz_process_input(char *input, size_t len) {
    char buffer[256];
    memcpy(buffer, input, len);  // VULNERABLE!
    // ...
}

// After (fixed):
void xyz_process_input(char *input, size_t len) {
    char buffer[256];

    // Validate input length
    if (len > sizeof(buffer)) {
        return EINVAL;
    }

    memcpy(buffer, input, len);  // Safe now
    // ...
}
```


TIMELINE
--------
- YYYY-MM-DD: Vulnerability discovered via fuzzing
- YYYY-MM-DD: Confirmed exploitability
- YYYY-MM-DD: Reported to Apple Security
- [Apple will track subsequent timeline]


ADDITIONAL INFORMATION
----------------------
Discovery Method:
- Tool: TriforceAFL (AFL-based full-system fuzzer)
- Target: [Component being fuzzed]
- Duration: [Days of fuzzing]
- Test cases: [Number executed]

Related Vulnerabilities:
[If this is similar to previous CVEs or part of a pattern]

Public Disclosure Plan:
"I plan to follow Apple's coordinated disclosure process and will not
publicly disclose this vulnerability until Apple has released a patch
and provided clearance, or 90 days have elapsed, whichever comes first."


RESEARCHER INFORMATION
----------------------
Name: [Your name or handle]
Affiliation: [Organization, if applicable]
Email: [Contact email]
PGP Key: [Optional: Your PGP key fingerprint]
Twitter: [Optional: @handle]

Bounty Program Participation:
- [ ] Yes, I wish to participate in Apple Security Bounty
- [ ] No, reporting for public benefit only

Acknowledgment Preference:
- [ ] Please credit me as: [Name/Handle]
- [ ] Please keep my identity anonymous


ATTACHMENTS
-----------
- poc.c: Proof-of-concept exploit code
- crash.log: Kernel panic log
- fuzzing_input.bin: Test case that triggers the bug
- coverage.txt: AFL coverage map
```

---

## 💰 Apple Security Bounty Rewards

### Reward Ranges (As of 2024)

| Category | Maximum Reward |
|----------|----------------|
| **Zero-click kernel code execution** | $1,000,000+ |
| **Zero-click kernel memory disclosure** | $500,000 |
| **One-click kernel code execution** | $500,000 |
| **Kernel privilege escalation** | $100,000 |
| **Sandbox escape** | $100,000 |
| **User data access** | $100,000 |
| **Authentication bypass** | $50,000 |
| **Vulnerabilities in accessories** | $50,000 |

### Reward Modifiers

- **Up to 2x bonus** for reporting before public release (beta software)
- **Additional bonus** for complete exploit chains
- **Highest quality** submissions receive maximum rewards

### What Apple Looks For

✅ **Qualities of High-Value Reports:**
- Clear, detailed reproduction steps
- Minimal proof-of-concept code
- Comprehensive security impact analysis
- Proposed remediation
- Professional presentation
- Novel attack techniques

❌ **Lower Value Reports:**
- Theoretical vulnerabilities without PoC
- Requires complex user interaction
- Limited security impact
- Duplicate reports
- Incomplete information

---

## 🔒 Responsible Disclosure Best Practices

### Do's ✅

1. **Report Privately First**
   - Always report to Apple before public disclosure
   - Use encrypted email (PGP) for sensitive details
   - Keep vulnerability details confidential

2. **Provide Complete Information**
   - Include all affected versions you tested
   - Provide step-by-step reproduction
   - Include crash logs and debugging info

3. **Be Professional**
   - Use clear, technical language
   - Be respectful in all communications
   - Be patient during the patching process

4. **Follow the Timeline**
   - Standard disclosure: 90 days
   - Request extensions if needed
   - Coordinate with Apple before going public

5. **Protect Users**
   - Don't release exploits publicly until patched
   - Don't sell vulnerabilities to third parties
   - Consider the impact on end users

### Don'ts ❌

1. **Don't Publish Prematurely**
   - No blog posts before patches are released
   - No conference talks without coordination
   - No exploit code on GitHub until after patch

2. **Don't Test on Others' Systems**
   - Only test on systems you own
   - Don't scan/probe Apple infrastructure
   - Don't test on production environments

3. **Don't Exfiltrate Data**
   - Don't access or steal user data
   - Don't abuse the vulnerability beyond PoC
   - Don't cause damage or service disruption

4. **Don't Be Aggressive**
   - Don't threaten full disclosure
   - Don't demand specific timelines
   - Don't publicly pressure Apple

---

## 📅 Typical Timeline

### Week 1-2: Initial Report
- Submit detailed report to product-security@apple.com
- Receive acknowledgment (usually 48-72 hours)
- Apple may request additional information

### Week 2-4: Validation
- Apple security team reproduces the issue
- Severity assessment
- Bounty eligibility determination

### Week 4-12: Fix Development
- Apple develops patch
- Internal testing
- Integration into next security update

### Week 12-16: Release
- Security update released to public
- CVE assigned
- Security advisory published
- Bounty payment processed

### Post-Release
- You may publish your research
- Apple may credit you in advisory
- Bounty rewards typically paid within 30 days

---

## 🌟 Success Stories

### Example: CVE-2021-30737
- **Researcher**: Qualified security researcher
- **Vulnerability**: Kernel memory corruption
- **Impact**: Kernel code execution
- **Reward**: $100,000+
- **Timeline**: Reported March, Patched July

### Example: CVE-2021-30807
- **Researcher**: Anonymous
- **Vulnerability**: IOMobileFrameBuffer memory corruption
- **Impact**: Kernel privilege escalation
- **Reward**: $100,000+
- **Timeline**: Responsible disclosure followed

---

## 📚 Additional Resources

### Apple Official Resources
- **Security Updates**: https://support.apple.com/en-us/HT201222
- **Security Advisories**: https://support.apple.com/en-us/HT201222
- **Reporting Guidelines**: https://support.apple.com/en-us/HT201220
- **Bug Bounty Program**: https://security.apple.com/bounty/

### Third-Party Resources
- **CVE Database**: https://cve.mitre.org/
- **NVD**: https://nvd.nist.gov/
- **Project Zero**: https://googleprojectzero.blogspot.com/
- **Phrack Magazine**: http://phrack.org/

### Tools & Research
- **TriforceAFL**: https://github.com/nccgroup/TriforceAFL
- **AFL**: https://github.com/google/AFL
- **Syzkaller**: https://github.com/google/syzkaller
- **LLVM LibFuzzer**: https://llvm.org/docs/LibFuzzer.html

---

## ⚖️ Legal Considerations

### Safe Harbor

Apple's bug bounty program provides safe harbor for security research:

✅ **Protected Activities:**
- Security testing on your own devices
- Reporting vulnerabilities privately
- Developing proof-of-concept exploits for reporting
- Responsible disclosure to Apple

❌ **Not Protected:**
- Testing on others' devices without permission
- Accessing user data or causing harm
- Public disclosure before patching
- Selling vulnerabilities to third parties

### DMCA and Jailbreaking

In the United States:
- Security research has DMCA exemptions
- Jailbreaking for security research may be permitted
- Consult legal counsel for specific situations

### International Researchers

- Apple accepts reports globally
- Legal protections vary by country
- Consider your local laws
- Safe harbor applies under Apple's program

---

## 📞 Support & Questions

### Need Help?

If you have questions about:
- **Technical details of reporting**: Contact product-security@apple.com
- **Bounty program eligibility**: See https://security.apple.com/bounty/
- **TriforceAFL usage**: See MACOS_FUZZING_GUIDE.md
- **Responsible disclosure**: Review this guide

### Community Support

- **AFL Users Group**: https://groups.google.com/group/afl-users
- **Fuzzing Discord/Slack**: Various security communities
- **Security Twitter**: Follow @AppleSupport, security researchers

---

## 🎯 Final Checklist

Before submitting your report:

- [ ] Vulnerability is confirmed and reproducible
- [ ] Tested on latest public version
- [ ] Created minimal proof-of-concept
- [ ] Documented all steps clearly
- [ ] Assessed security impact
- [ ] Checked for duplicates
- [ ] Report is complete and professional
- [ ] Used Apple's report template
- [ ] Encrypted sensitive details (PGP)
- [ ] Committed to responsible disclosure
- [ ] Read and understood Apple's program rules
- [ ] Have realistic expectations on timeline

---

## Conclusion

Reporting security vulnerabilities to Apple is an important contribution to the security of millions of users worldwide. By following responsible disclosure practices and using tools like TriforceAFL ethically, you can:

- Improve security for everyone
- Earn recognition and rewards
- Advance your security research career
- Build positive relationships with vendors

**Remember**: With great power comes great responsibility. Use your skills ethically and always prioritize user safety.

Good luck with your research! 🔐

---

**Document Version**: 1.0
**Last Updated**: 2025
**Maintainer**: Security Research Team
**License**: See repository LICENSE
