# DGX Spark UEFI Opal Runbook

## Scope

Use this runbook for an NVIDIA DGX Spark whose system NVMe already contains data and supports TCG Opal. It covers non-destructive ownership and password setup, authenticated boot verification, and failure triage.

Do not use it to erase a drive.

## Read-Only Discovery

Identify the root disk and existing software encryption:

```bash
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,FSVER,MOUNTPOINTS,MODEL
findmnt -no SOURCE,FSTYPE,OPTIONS /
sudo dmsetup ls --tree
sed -n '1,160p' /etc/crypttab
cryptsetup --version
```

Check TPM availability:

```bash
ls -l /dev/tpm* 2>/dev/null || true
dmesg | grep -Ei 'tpm|trusted computing' | tail -100
```

Check NVMe security support:

```bash
sudo nvme id-ctrl -H /dev/nvme0 |
  grep -Ei -C 3 'Security Send|Security Receive|sanicap|fna|oacs'
```

Query Opal with an already installed or locally built `sedutil-cli`:

```bash
sudo sedutil-cli --query /dev/nvme0n1
```

Before setup, the useful indicators are:

```text
LockingSupported = Y
MediaEncrypt = Y
LockingEnabled = N
Locked = N
SID equals MSID = Y
```

`MediaEncrypt = Y` alone is not access protection. Without locking enabled, the controller transparently decrypts data for any host.

Do not globally install packages without approval. If `sedutil-cli` is absent, build the official Drive Trust Alliance source in a disposable directory, run only `--scan` and `--query`, and do not run setup, revert, reset, or erase commands.

## Backup Gate

Before password changes:

1. Confirm the backup destination is independently accessible.
2. Verify several critical files with size and SHA-256.
3. Confirm the backup is not stored only on the NVMe being protected.
4. Do not claim a full backup from the existence of a directory alone.

## Physical Preparation

Required:

- HDMI display or remote KVM video
- wired USB keyboard or reliable firmware-compatible receiver
- network retained for post-boot SSH checks

An ordinary USB-C cable between two computers is not a remote UEFI KVM and does not expose the internal NVMe as USB mass storage.

Before rebooting, verify attached USB devices from Linux:

```bash
lsusb
awk '/^N: Name=/{name=$0} /^H: Handlers=.*kbd/{print name; print}' \
  /proc/bus/input/devices
```

## UEFI Sequence

### 1. Open the one-boot management window

1. Enter UEFI by pressing `Esc` or `Del` during power-on.
2. Open `Security`.
3. Set `Disable Block SID and Freeze Lock` to `Enabled`.
4. Save changes and reset.
5. Immediately re-enter UEFI before Ubuntu starts.

The override is for the next boot. Allowing Ubuntu to start may consume the window and leave `SID blocked = Y`.

Never enter `Media Sanitization`.

### 2. Inspect the TCG device

Open:

```text
Security
  -> TCG Storage Security Configuration
  -> <NVMe model>
```

Proceed only when the page shows:

```text
Security Subsystem Class: Opal
Security Supported: Yes
Security Enabled: No
Security Locked: No
Security Frozen: No
Admin Pwd Status: NOT INSTALLED
```

If `Security Frozen: Yes`, do not improvise. Perform a full shutdown and re-enter UEFI directly after power-on.

### 3. Set the Admin password

This is the dangerous boundary. Explain the impact and obtain explicit confirmation.

Password handling:

- Follow the minimum and maximum length displayed by firmware.
- Prefer a random maximum-length ASCII alphanumeric password.
- Generate it on a trusted user-visible system without printing it into agent logs.
- The user must record and verify it independently.
- Never ask the user to paste it into chat.

Select `Set Admin Password`, enter the value, and confirm it.

Do not select:

- `Device Reset`
- `Media Sanitization`
- any PSID, revert, erase, sanitize, or format action

After setup, verify:

```text
Security Enabled: Yes
Security Locked: Yes
Security Frozen: No
Admin Pwd Status: INSTALLED
```

The User password is optional. Admin alone can be the POST unlock credential.

## First Authenticated Boot

1. Save changes and reset.
2. At `Enter Admin password`, enter the exact recorded password.
3. Press the main `Enter`/`Return` key once.
4. Do not repeatedly submit guesses.

Interpretation:

- Password prompt remains with a full masked field: ensure `Enter` was pressed once.
- Explicit password error: stop after one careful retry and inspect keyboard layout/case.
- `Checking Media Presence` / `Start PXE over IPv4`: the password stage was passed. Wait before declaring failure; abort PXE with one `Esc` if it does not continue.
- Ubuntu login appears: complete a live SSH and root-filesystem check.

Do not power-cycle immediately after a correct password merely because PXE appears. The boot manager may continue to the local entry after its network timeout.

## Post-Boot Verification

Verify the host and root filesystem:

```bash
hostname
uptime -s
findmnt -no SOURCE,FSTYPE,OPTIONS /
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/nvme0n1
```

Query Opal:

```bash
sudo sedutil-cli --query /dev/nvme0n1
```

Expected after successful authentication:

```text
LockingEnabled = Y
MediaEncrypt = Y
Locked = N
SID equals MSID = N
```

`Locked = N` is correct while the authenticated operating system is running. The protection applies after power loss or a full shutdown.

Before RMA or handoff:

1. Stop normal workloads cleanly.
2. Use a full shutdown.
3. Do not use suspend or leave the machine running.
4. Keep the Admin password separate from the machine.

## Recovery and Destructive Operations

### Preserve data

With the correct Admin password:

- unlock at POST;
- modify the password in UEFI;
- clear the Admin/User password through the documented TCG password menu when intentionally removing protection.

Verify data access before and after any password-management change.

### Destroy access to existing data

These are not password-recovery methods:

- UEFI `Device Reset`
- PSID Revert
- NVMe Sanitize
- Crypto Erase
- `mkfs`
- overwrite or discard procedures

Treat `Device Reset` and PSID Revert as cryptographic data destruction. They may make the device reusable but do not recover files or bypass the password.

Do not provide or execute an exact destructive command until the user explicitly confirms the operation, affected device, backup status, and permanent data-loss consequence.

## Sources

- NVIDIA DGX Spark UEFI Security tab:
  `https://docs.nvidia.com/dgx/dgx-spark-uefi/security-tab.html`
- Drive Trust Alliance sedutil:
  `https://github.com/Drive-Trust-Alliance/sedutil`
- TCG Block SID Authentication feature set:
  `https://trustedcomputinggroup.org/resource/storage-feature-set-block-sid-authentication/`
