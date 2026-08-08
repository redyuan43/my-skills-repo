---
name: dgx-spark-opal-nvme-lock
description: Inspect, enable, verify, and safely recover the NVIDIA DGX Spark system NVMe TCG Opal hardware lock without erasing existing data. Use when a user wants to protect Spark data before RMA or disk removal, asks about Block SID, TCG Storage Security Configuration, NVMe boot passwords, Opal Locked/LockingEnabled/MediaEncrypt states, a password prompt that appears before Ubuntu, PXE delay after unlocking, or the difference between clearing a password and destructive Device Reset, PSID Revert, Sanitize, or formatting.
---

# DGX Spark Opal NVMe Lock

Protect data at rest on a DGX Spark system NVMe by using the firmware-native TCG Opal password flow. Treat this as a fragile, confirmation-gated procedure: a wrong or lost password can make the existing data inaccessible.

## Safety Rules

- Default to read-only inspection.
- Verify a separate backup before changing Opal ownership or passwords.
- Never ask the user to send the password through chat, shell history, logs, or screenshots.
- Require explicit confirmation immediately before setting, changing, or clearing an Opal password.
- Never select `Media Sanitization` or `Device Reset` during normal setup or unlock.
- Treat PSID Revert, Device Reset, Crypto Erase, Sanitize, `mkfs`, and writing zeros as destructive data-loss operations.
- Do not confuse account, GRUB, or UEFI setup passwords with NVMe data-at-rest protection.
- Do not promise protection while the machine is running and the NVMe is unlocked.

Use this confirmation format before a password or destructive security change:

```text
危险操作检测！
操作类型：<exact Opal password/reset action>
影响范围：<exact NVMe device and affected data>
风险评估：<boot impact, lockout risk, and whether data loss is permanent>

请确认是否继续？需要明确的“确认继续”
```

## Read-Only Example

Run the bundled checker on the DGX Spark itself:

```bash
sudo bash dgx-spark-opal-nvme-lock/scripts/check_opal_state.sh
```

Use a locally built `sedutil-cli` without installing it:

```bash
sudo bash dgx-spark-opal-nvme-lock/scripts/check_opal_state.sh \
  --sedutil /tmp/sedutil-build/sedutil-cli
```

## Workflow

1. Establish the threat model:
   - Protecting a powered-off disk from removal: Opal is appropriate.
   - Protecting a running unlocked machine from an administrator: Opal is insufficient.
   - Preserving existing data while enabling protection: do not format, sanitize, or PSID-reset.

2. Inspect live state:
   - Confirm the root device, filesystem, encryption layers, backup reachability, TPM state, and NVMe security capabilities.
   - Query with `sedutil-cli --query` when available.
   - Require `LockingSupported = Y` and `MediaEncrypt = Y` before considering the UEFI workflow.

3. Prepare physical access:
   - Connect HDMI and a wired USB keyboard.
   - Keep network connected for post-boot SSH verification.
   - Verify both devices from Linux before rebooting when possible.

4. Use the one-boot UEFI window:
   - Enter UEFI with `Esc` or `Del`.
   - Enable `Disable Block SID and Freeze Lock`.
   - Save and reset, then immediately re-enter UEFI before Ubuntu starts.
   - Open `Security` -> `TCG Storage Security Configuration` -> the NVMe device.

5. Validate the pre-change state:
   - `Security Supported: Yes`
   - `Security Enabled: No`
   - `Security Locked: No`
   - `Security Frozen: No`
   - `Admin Pwd Status: NOT INSTALLED`

6. Set the Admin password only after confirmation:
   - Generate it locally on a trusted user-visible machine.
   - Respect the firmware length limit shown on screen.
   - Prefer random ASCII letters and digits to avoid keyboard-layout ambiguity.
   - Have the user retain two offline copies.
   - Do not set a User password unless the user has a specific need for a second POST credential.

7. Verify and boot:
   - Confirm `Security Enabled: Yes`, `Security Locked: Yes`, and `Admin Pwd Status: INSTALLED`.
   - Save changes and reset.
   - At the pre-boot prompt, type the Admin password and press `Enter`.
   - If PXE starts after a successful password entry, wait before assuming failure; some boots may fall through network boot before returning to the local Ubuntu entry.

8. Verify from Linux:
   - Confirm SSH and the root filesystem are healthy.
   - Query Opal again.
   - Expect `LockingEnabled = Y`, `MediaEncrypt = Y`, `Locked = N`, and `SID equals MSID = N` after a successful unlock.

Read [references/dgx-spark-uefi-opal-runbook.md](references/dgx-spark-uefi-opal-runbook.md) before performing UEFI changes, diagnosing a stuck password prompt, or discussing recovery/reset operations.

## Completion Criteria

- Existing files remain readable after the first authenticated boot.
- The controller reports Opal locking enabled and currently unlocked.
- A complete shutdown, not suspend, is used before handing off the machine.
- The user understands that losing the password makes existing data inaccessible.
- The user understands that Device Reset or PSID Revert can make the SSD reusable only by destroying access to the old data.

## Files

- `scripts/check_opal_state.sh`: read-only root disk, NVMe capability, and Opal state inspection
- `scripts/selftest.sh`: safe static smoke test
- `references/dgx-spark-uefi-opal-runbook.md`: detailed UEFI, first-boot, verification, and recovery runbook
