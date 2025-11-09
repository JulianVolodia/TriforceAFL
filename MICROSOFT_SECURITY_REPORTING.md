# Microsoft Security Vulnerability Reporting Guide

## Comprehensive Guide for Reporting Vulnerabilities in Microsoft Products

This guide provides detailed information for security researchers using TriforceAFL to discover and report vulnerabilities in Microsoft products including Windows, Azure, Office, Edge, and more.

---

## 📞 Quick Reference

| Item | Information |
|------|-------------|
| **Primary Contact** | secure@microsoft.com |
| **Bug Bounty Portal** | https://www.microsoft.com/en-us/msrc/bounty |
| **MSRC Portal** | https://msrc.microsoft.com/ |
| **PGP Key** | Available at https://www.microsoft.com/en-us/msrc/pgp-key-msrc |
| **Response Time** | 24-48 hours (typically) |
| **Max Bounty** | $250,000+ |
| **Standard Disclosure** | 90 days (coordinated) |

---

## Table of Contents

1. [Microsoft Bug Bounty Programs](#microsoft-bug-bounty-programs)
2. [High-Value Targets](#high-value-targets)
3. [Windows Kernel Fuzzing](#windows-kernel-fuzzing)
4. [Azure & Cloud Services](#azure--cloud-services)
5. [Report Submission](#report-submission)
6. [Bounty Rewards](#bounty-rewards)
7. [Legal & Safe Harbor](#legal--safe-harbor)
8. [Tools & Resources](#tools--resources)

---

## Microsoft Bug Bounty Programs

### Active Programs (2025)

| Program | Scope | Max Reward | URL |
|---------|-------|------------|-----|
| **Windows Bounty** | Windows OS, kernel, core components | $250,000 | [Link](https://www.microsoft.com/en-us/msrc/bounty-windows) |
| **Hyper-V Bounty** | Hyper-V hypervisor, guest-to-host escapes | $250,000 | [Link](https://www.microsoft.com/en-us/msrc/bounty-hyper-v) |
| **Azure Bounty** | Azure infrastructure, services | $40,000 | [Link](https://www.microsoft.com/en-us/msrc/bounty-microsoft-azure) |
| **Microsoft 365** | Office apps, SharePoint, Teams | $30,000 | [Link](https://www.microsoft.com/en-us/msrc/bounty-microsoft-365-apps) |
| **Edge Browser** | Microsoft Edge (Chromium) | $30,000 | [Link](https://www.microsoft.com/en-us/msrc/bounty-microsoft-edge) |
| **Xbox Bounty** | Xbox consoles, services | $20,000 | [Link](https://www.microsoft.com/en-us/msrc/bounty-xbox) |
| **Identity Bounty** | Active Directory, Entra ID | $100,000 | [Link](https://www.microsoft.com/en-us/msrc/bounty-identity) |

### Bounty Eligibility

✅ **In Scope**:
- Latest versions of Windows (10, 11, Server)
- Hyper-V on Windows Server
- Azure production services
- Microsoft 365 apps (latest versions)
- Microsoft Edge (stable channel)
- Active Directory, Entra ID (Azure AD)
- Xbox consoles and services

❌ **Out of Scope**:
- Denial of Service (DoS) without RCE
- Issues requiring physical access
- Social engineering attacks
- Unsupported/EOL products
- Third-party applications on Microsoft platforms
- Issues already publicly known

---

## High-Value Targets

### Windows Kernel (NT Kernel)

**Component: ntoskrnl.exe**

**High-Value Attack Surfaces**:

1. **win32k.sys** (GUI Subsystem) ⭐⭐⭐⭐⭐
   ```
   Location: C:\Windows\System32\win32k.sys
   Functions: Window management, GDI, user input
   History: Frequent vulnerabilities
   Reward: $50,000 - $150,000

   Key syscalls to fuzz:
   - NtUserSetWindowLong
   - NtGdiDdDDI*
   - NtUserMessageCall
   - NtGdiCreateBitmap
   ```

2. **I/O Manager & Drivers** ⭐⭐⭐⭐
   ```
   Location: Various .sys files
   Functions: Device I/O, file operations
   Reward: $30,000 - $100,000

   Key IOCTLs to fuzz:
   - Storage drivers
   - Network drivers
   - USB drivers
   - Graphics drivers
   ```

3. **Network Stack** ⭐⭐⭐⭐
   ```
   Components: tcpip.sys, afd.sys, http.sys
   Functions: TCP/IP, sockets, HTTP
   Reward: $40,000 - $150,000

   Key syscalls:
   - NtDeviceIoControlFile (for sockets)
   - WSK (Winsock Kernel)
   - HTTP.sys kernel mode driver
   ```

4. **File System Drivers** ⭐⭐⭐
   ```
   Components: ntfs.sys, refs.sys
   Functions: NTFS, ReFS file systems
   Reward: $30,000 - $100,000

   Key operations:
   - File creation with extended attributes
   - Symbolic link handling
   - Volume mount operations
   ```

5. **Object Manager** ⭐⭐⭐
   ```
   Component: Part of ntoskrnl.exe
   Functions: Kernel object management
   Reward: $40,000 - $150,000

   Key syscalls:
   - NtCreateFile
   - NtCreateSection
   - NtDuplicateObject
   ```

### Hyper-V Hypervisor

**Component: hvax64.exe / hvix64.exe**

**High-Value Vulnerabilities**:

1. **Guest-to-Host Escape** ⭐⭐⭐⭐⭐
   ```
   Impact: Full host compromise from guest VM
   Reward: $150,000 - $250,000

   Attack surfaces:
   - Virtual devices (network, storage, video)
   - VM bus communication
   - Integration services
   - Enlightened I/O
   ```

2. **VM Isolation Bypass** ⭐⭐⭐⭐
   ```
   Impact: Access another VM's memory/data
   Reward: $100,000 - $200,000

   Key areas:
   - Memory isolation
   - CPU register isolation
   - Device assignment
   ```

### Azure Services

**High-Value Cloud Vulnerabilities**:

1. **Compute (VMs)** ⭐⭐⭐⭐
   ```
   Impact: VM escape, cross-tenant access
   Reward: $20,000 - $40,000

   Areas to test:
   - Azure VM agent
   - Azure Linux agent
   - VM extensions
   ```

2. **Container Services** ⭐⭐⭐⭐
   ```
   Services: AKS, Container Instances
   Impact: Container escape, cluster compromise
   Reward: $15,000 - $40,000
   ```

3. **Storage & Databases** ⭐⭐⭐
   ```
   Services: Blob Storage, SQL Database, Cosmos DB
   Impact: Unauthorized data access
   Reward: $10,000 - $30,000
   ```

4. **Identity & Access** ⭐⭐⭐⭐⭐
   ```
   Services: Azure AD (Entra ID), ADFS
   Impact: Authentication bypass, privilege escalation
   Reward: $20,000 - $100,000
   ```

---

## Windows Kernel Fuzzing

### Setup for Windows Kernel Fuzzing

#### Option 1: Using Hyper-V (Recommended)

```powershell
# Enable Hyper-V (PowerShell as Administrator)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# Create a VM for fuzzing
New-VM -Name "FuzzTarget" -MemoryStartupBytes 4GB -Generation 2
```

#### Option 2: Using TriforceAFL in WSL2

```bash
# From WSL2 Ubuntu
cd TriforceAFL

# Note: Direct Windows kernel fuzzing from WSL is complex
# You'll need to:
# 1. Extract Windows kernel from running system
# 2. Set up symbols for debugging
# 3. Use kernel debugging tools

# See WINDOWS_KERNEL_FUZZING.md for detailed instructions
```

### Finding Vulnerability Targets

#### Enumerate Installed Drivers

```powershell
# List all kernel drivers
Get-WindowsDriver -Online -All | Format-Table Driver, ProviderName

# Find driver files
Get-ChildItem C:\Windows\System32\drivers\*.sys

# Check driver details
Get-Item C:\Windows\System32\drivers\[driver].sys | Format-List *
```

#### Find IOCTL Codes

```powershell
# Using WinDbg
!devobj \Driver\[DriverName]

# Find dispatch routines
!drvobj [DriverName]

# Analyze IOCTL handler
u [DriverName]!DeviceIoControl
```

#### Get Symbol Information

```powershell
# Download symbols (WinDbg)
.symfix
.reload

# Find function addresses
x nt!NtDeviceIoControlFile
x win32k!NtUserSetWindowLong
```

### Example Fuzzing Driver for Windows

```c
/*
 * Windows Kernel Fuzzing Driver - Example
 * Target: Generic IOCTL handler
 *
 * Build: WDK (Windows Driver Kit) required
 */

#include <ntddk.h>

// AFL call instruction (requires patched QEMU)
__forceinline void AflCall(ULONG op, PVOID arg1, PVOID arg2) {
    __asm {
        mov edi, op
        mov esi, arg1
        mov edx, arg2
        _emit 0x0F
        _emit 0x24
    }
}

#define AFL_START_FORKSERVER 1
#define AFL_GET_WORK 2
#define AFL_START_WORK 3
#define AFL_DONE_WORK 4

NTSTATUS FuzzerDriverEntry(PDRIVER_OBJECT DriverObject, PUNICODE_STRING RegistryPath) {
    PVOID testBuffer;
    ULONG testSize;
    struct {
        ULONG64 start;
        ULONG64 end;
    } traceRange;

    DbgPrint("[AFL] Starting Windows kernel fuzzer\n");

    // Allocate buffer for test cases
    testBuffer = ExAllocatePoolWithTag(NonPagedPool, 64 * 1024, 'TLFA');
    if (!testBuffer) {
        return STATUS_INSUFFICIENT_RESOURCES;
    }

    // Start fork server
    AflCall(AFL_START_FORKSERVER, NULL, NULL);

    // Fuzzing loop
    while (TRUE) {
        // Get test case
        testSize = (ULONG)AflCall(AFL_GET_WORK, testBuffer, (PVOID)(64 * 1024));

        // Set trace range (target function address range)
        // Update these addresses for your target!
        traceRange.start = 0xFFFFF80000000000;  // Start of kernel
        traceRange.end   = 0xFFFFF80001000000;  // End of range

        // Enable tracing
        AflCall(AFL_START_WORK, &traceRange, NULL);

        // === TARGET CODE HERE ===
        // Example: Send IOCTL to target driver
        /*
        HANDLE hDevice;
        IO_STATUS_BLOCK ioStatusBlock;
        OBJECT_ATTRIBUTES objAttr;
        UNICODE_STRING deviceName;

        RtlInitUnicodeString(&deviceName, L"\\Device\\TargetDevice");
        InitializeObjectAttributes(&objAttr, &deviceName, OBJ_KERNEL_HANDLE, NULL, NULL);

        ZwCreateFile(&hDevice, GENERIC_READ | GENERIC_WRITE, &objAttr,
                     &ioStatusBlock, NULL, 0, 0, FILE_OPEN, 0, NULL, 0);

        ZwDeviceIoControlFile(hDevice, NULL, NULL, NULL, &ioStatusBlock,
                              IOCTL_CODE, testBuffer, testSize, NULL, 0);

        ZwClose(hDevice);
        */

        DbgPrint("[AFL] Processed test case, size=%lu\n", testSize);

        // Mark test complete
        AflCall(AFL_DONE_WORK, (PVOID)0, NULL);
    }

    ExFreePoolWithTag(testBuffer, 'TLFA');
    return STATUS_SUCCESS;
}
```

### Common Windows Vulnerability Patterns

1. **Integer Overflow in Size Calculations**
   ```c
   // Vulnerable pattern
   ULONG totalSize = userCount * sizeof(OBJECT);
   PVOID buffer = ExAllocatePool(NonPagedPool, totalSize);
   // If userCount is large, totalSize wraps around!
   ```

2. **Use-After-Free in Object Handling**
   ```c
   // Vulnerable pattern
   ObDereferenceObject(object);  // Object may be freed
   // ...later...
   object->field = value;  // Use after free!
   ```

3. **Buffer Overflow in Kernel Mode**
   ```c
   // Vulnerable pattern
   CHAR kernelBuffer[256];
   memcpy(kernelBuffer, userBuffer, userLength);  // No length check!
   ```

4. **Type Confusion**
   ```c
   // Vulnerable pattern
   PVOID object = GetObjectByHandle(handle);
   TypeA* typedObject = (TypeA*)object;  // Wrong type!
   typedObject->methodPtr();  // Crash or RCE
   ```

---

## Azure & Cloud Services

### Azure Security Research

#### Authorized Testing

✅ **Allowed**:
- Testing your own Azure subscriptions
- Using test data only
- Coordinating with Azure security team
- Following Azure Penetration Testing rules

❌ **Prohibited**:
- Testing other customers' resources
- DoS attacks
- Accessing production data
- Scanning Azure infrastructure

#### Azure Penetration Testing Rules

**No prior approval needed for**:
- Your own Azure VMs
- Your own web apps
- Your own databases
- Your own storage accounts

**Prior approval required for**:
- DoS testing
- Network security group testing
- Azure AD testing
- Multi-tenant service testing

**Contact**: azure-security@microsoft.com

### High-Value Azure Vulnerabilities

1. **VM Escape**
   ```
   Description: Break out of Azure VM to host
   Impact: Access to Azure infrastructure
   Reward: $20,000 - $40,000
   ```

2. **Cross-Tenant Data Access**
   ```
   Description: Access another customer's data
   Impact: Critical data breach
   Reward: $30,000 - $40,000
   ```

3. **Authentication Bypass**
   ```
   Description: Bypass Azure AD authentication
   Impact: Unauthorized account access
   Reward: $20,000 - $100,000 (Identity bounty)
   ```

4. **Privilege Escalation**
   ```
   Description: Gain elevated permissions in Azure
   Impact: Unauthorized resource access
   Reward: $15,000 - $30,000
   ```

---

## Report Submission

### Report Template for Microsoft

```markdown
**Title**: [Brief, clear description]

**Reporter**: [Your name/handle]
**Email**: [Contact email]
**Date**: [YYYY-MM-DD]

---

## Summary
[One-sentence description of the vulnerability]

## Product/Component
- Product: [Windows 11, Azure VM, etc.]
- Version: [Specific version number]
- Build: [Build number if applicable]
- Architecture: [x64, ARM64, etc.]

## Vulnerability Details

### Classification
- Type: [Memory Corruption/Logic Error/etc.]
- CWE: [CWE-###]
- Affected Component: [ntoskrnl.exe, win32k.sys, etc.]
- Affected Function: [Function name if known]

### Attack Vector
- Attack Complexity: [Low/Medium/High]
- Privileges Required: [None/Low/High]
- User Interaction: [None/Required]
- Scope: [Unchanged/Changed]

### Impact
- Confidentiality: [None/Low/High]
- Integrity: [None/Low/High]
- Availability: [None/Low/High]

**CVSS v3.1 Score**: [If calculated]

## Technical Analysis

### Root Cause
[Detailed explanation of what causes the vulnerability]

### Exploitation Details
[How the vulnerability can be exploited]

### Affected Code Path
[Call stack or code flow leading to vulnerability]

## Proof of Concept

### Environment
- OS: Windows 11 Build [####]
- Hardware: [If relevant]
- Configuration: [Any special setup]

### Reproduction Steps
1. [Step-by-step instructions]
2. [Be specific and detailed]
3. [Expected result]

### PoC Code
```c
// Minimal proof-of-concept
#include <windows.h>

int main() {
    // PoC code here
    return 0;
}
```

### Crash Information
```
[Crash dump, bugcheck code, or error details]
```

## Proposed Mitigation
[Optional: Suggest how to fix the vulnerability]

## Timeline
- Discovered: [Date]
- Reported: [Date]
- Suggested Disclosure: [90 days from report]

## Additional Information
[Any other relevant details]

## Bounty Program
I wish to participate in the applicable Microsoft bug bounty program.
```

### Submission Channels

1. **Email Submission**
   ```
   To: secure@microsoft.com
   Subject: [Security] [Component] Vulnerability Type

   Attach: Report in TXT or PDF format
   PGP: Encrypt sensitive details using Microsoft's PGP key
   ```

2. **MSRC Portal**
   ```
   URL: https://msrc.microsoft.com/create-report
   Login: Microsoft account required
   Submit: Through web form
   ```

3. **Special Programs**
   - Azure: azure-security@microsoft.com
   - Office 365: secure@microsoft.com (mark [Azure] or [O365])
   - Coordinated Disclosure: Use MSRC portal

---

## Bounty Rewards

### Windows Bounty Program

| Vulnerability Class | Reward Range | Notes |
|-------------------|--------------|-------|
| **Critical RCE (Network)** | $100,000 - $250,000 | Remote code execution, no user interaction |
| **Critical RCE (Local)** | $50,000 - $100,000 | Requires local access or user interaction |
| **Privilege Escalation** | $30,000 - $100,000 | User to SYSTEM/kernel |
| **Information Disclosure** | $15,000 - $50,000 | Kernel memory disclosure |
| **Defense-in-Depth** | $500 - $20,000 | Security improvement without direct exploit |

### Hyper-V Bounty Program

| Vulnerability Class | Reward Range |
|-------------------|--------------|
| **Guest-to-Host Escape** | $150,000 - $250,000 |
| **Guest-to-Guest** | $100,000 - $150,000 |
| **Denial of Host Service** | $25,000 - $75,000 |

### Azure Bounty Program

| Vulnerability Class | Reward Range |
|-------------------|--------------|
| **Critical Impact** | $20,000 - $40,000 |
| **High Impact** | $10,000 - $20,000 |
| **Medium Impact** | $5,000 - $10,000 |
| **Low Impact** | $500 - $5,000 |

### Reward Modifiers

**Bonus Factors**:
- ✅ **High quality report**: Clear, detailed, professional (+20%)
- ✅ **Proposed fix included**: Patch or mitigation (+10%)
- ✅ **Novel technique**: New exploitation method (+15%)
- ✅ **Multiple variants**: Found several instances (+varies)

**Reduction Factors**:
- ⚠️ **Duplicate report**: Report already submitted
- ⚠️ **Incomplete information**: Missing repro steps or PoC
- ⚠️ **Out of scope**: Not covered by bounty program
- ⚠️ **Low quality**: Poor documentation or analysis

---

## Legal & Safe Harbor

### Microsoft Safe Harbor

Microsoft provides safe harbor for security researchers who:
1. Act in good faith
2. Follow disclosure guidelines
3. Don't access customer data unnecessarily
4. Report vulnerabilities responsibly
5. Follow bounty program rules

**Safe Harbor Policy**: https://www.microsoft.com/en-us/msrc/bounty-safe-harbor

### What's Protected

✅ **Protected Activities**:
- Testing on your own Microsoft accounts/VMs
- Security research on Microsoft products you own
- Reporting through proper channels
- Developing PoC exploits for reporting
- Testing cloud services you subscribe to

❌ **Not Protected**:
- Accessing others' data or accounts
- Public disclosure before fix
- DoS attacks without prior approval
- Social engineering
- Physical attacks

### Legal Considerations

1. **DMCA**: Security research exemption applies
2. **CFAA**: Safe harbor protects authorized testing
3. **Data Protection**: Don't access real customer data
4. **Export Control**: Be aware of exploit export restrictions

---

## Tools & Resources

### Microsoft Security Tools

- **WinDbg**: https://docs.microsoft.com/windows-hardware/drivers/debugger/
- **Sysinternals**: https://docs.microsoft.com/sysinternals/
- **Windows SDK**: https://developer.microsoft.com/windows/downloads/windows-sdk/
- **WDK**: https://docs.microsoft.com/windows-hardware/drivers/download-the-wdk

### Fuzzing Tools for Windows

- **TriforceAFL**: (This repository)
- **WinAFL**: https://github.com/googleprojectzero/winafl
- **Peach Fuzzer**: https://www.peach.tech/
- **Honggfuzz**: https://github.com/google/honggfuzz

### Microsoft Security Resources

- **MSRC Blog**: https://msrc-blog.microsoft.com/
- **Security Updates**: https://portal.msrc.microsoft.com/
- **Security Advisories**: https://msrc.microsoft.com/update-guide/
- **Windows Security**: https://www.microsoft.com/security/

### Documentation

- **Windows Internals**: https://docs.microsoft.com/windows/
- **Azure Security**: https://docs.microsoft.com/azure/security/
- **Kernel-Mode Driver Architecture**: https://docs.microsoft.com/windows-hardware/drivers/kernel/

---

## Success Stories

### Notable Microsoft Vulnerabilities

1. **EternalBlue (MS17-010)**
   - Component: SMBv1
   - Impact: Remote code execution
   - Used in: WannaCry, NotPetya

2. **BlueKeep (CVE-2019-0708)**
   - Component: Remote Desktop Services
   - Impact: Remote code execution, wormable
   - Bounty: N/A (found internally)

3. **PrintNightmare (CVE-2021-34527)**
   - Component: Windows Print Spooler
   - Impact: Remote code execution, privilege escalation
   - Widespread impact

4. **PetitPotam (CVE-2021-36942)**
   - Component: MS-EFSRPC
   - Impact: NTLM relay attacks
   - Active Directory compromise

### Researcher Success

Many researchers have earned $100,000+ from Microsoft bounties by:
- Focusing on **win32k.sys** vulnerabilities
- Finding **Hyper-V** guest-to-host escapes
- Discovering **Azure AD** authentication bypasses
- Identifying **Windows kernel** memory corruption

---

## Quick Start Checklist

- [ ] Read Microsoft bounty program rules
- [ ] Set up Windows fuzzing environment
- [ ] Choose target component (win32k, drivers, etc.)
- [ ] Set up debugging tools (WinDbg)
- [ ] Start fuzzing campaign
- [ ] Triage crashes
- [ ] Verify exploitability
- [ ] Prepare detailed report
- [ ] Submit via secure@microsoft.com or MSRC portal
- [ ] Coordinate disclosure timeline
- [ ] Earn bounty and recognition!

---

## Conclusion

Microsoft's bug bounty programs offer substantial rewards for high-quality security research. By focusing on high-value targets like **win32k.sys**, **Hyper-V**, and **Azure services**, researchers can earn significant bounties while contributing to the security of billions of users worldwide.

**Remember**:
- Always obtain proper authorization
- Report responsibly through official channels
- Follow coordinated disclosure timelines
- Respect safe harbor protections
- Prioritize user safety

**Good luck with your Microsoft security research!** 🔒💻

---

**Document Version**: 1.0
**Last Updated**: 2025-01-09
**Maintainer**: Security Research Team
**License**: See repository LICENSE file
