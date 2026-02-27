---
name: "windows-network-share-fix"
description: "Fixes Windows 11 network share access issues due to guest authentication restrictions. Invoke when user cannot access network shares with error about security policies blocking unauthenticated guest access."
---

# Windows Network Share Fix

This skill helps users fix network share access issues on Windows 11, particularly when encountering the error: "You can't access this shared folder because your organization's security policies block unauthenticated guest access."

## Problem
Windows 11 has stricter security policies that block insecure guest access by default, preventing users from accessing network shares that use guest authentication.

## Solution
This skill provides a registry fix to enable insecure guest authentication, allowing access to network shares that require guest logins.

## Files Created

1. **`enable_guest_access.reg`** - Registry file to enable guest access
2. **`fix_network_share.ps1`** - PowerShell script with detailed fix

## Usage Instructions

### Method 1: Registry File (Recommended)
1. Double-click `enable_guest_access.reg`
2. Click "Yes" to confirm importing the registry settings
3. Restart your computer or restart the network services

### Method 2: PowerShell Script
1. Right-click `fix_network_share.ps1`
2. Select "Run as Administrator"
3. Follow the on-screen instructions

### Restart Network Services (Optional)
After applying the fix, you can restart these services instead of rebooting:

```powershell
Restart-Service LanmanWorkstation -Force
Restart-Service LanmanServer -Force
```

## What the Fix Does

1. **Enables `AllowInsecureGuestAuth`** in the registry
2. **Configures group policy settings** for network authentication
3. **Maintains system security** while allowing guest access

## When to Use This Skill

- User cannot access network shares on Windows 11
- Error message mentions security policies blocking guest access
- Other devices can access the same network share
- Need to connect to shares that use guest authentication

## Troubleshooting

If the fix doesn't work:
1. Ensure you ran the fix as Administrator
2. Verify the network share is accessible from other devices
3. Check if the network share requires specific credentials
4. Restart your computer to apply all changes