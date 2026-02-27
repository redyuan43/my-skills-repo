# Fix Windows 11 Network Share Guest Access Issue
# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    Write-Host "Right-click the script and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "Fixing network share guest access issue..." -ForegroundColor Cyan

# Method 1: Modify registry to enable insecure guest logons
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
$regName = "AllowInsecureGuestAuth"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

Set-ItemProperty -Path $regPath -Name $regName -Value 1 -Type DWord

Write-Host "Registry setting updated: AllowInsecureGuestAuth = 1" -ForegroundColor Green

# Method 2: Modify group policy (if possible)
try {
    $gpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation"
    if (-not (Test-Path $gpoPath)) {
        New-Item -Path $gpoPath -Force | Out-Null
    }
    Set-ItemProperty -Path $gpoPath -Name "AllowInsecureGuestAuth" -Value 1 -Type DWord
    Write-Host "Group policy registry setting updated" -ForegroundColor Green
} catch {
    Write-Host "Group policy update skipped (non-domain environment or insufficient permissions)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Fix completed!" -ForegroundColor Green
Write-Host "Please restart your computer or restart the following services for changes to take effect:" -ForegroundColor Yellow
Write-Host "1. LanmanWorkstation (Workstation)" -ForegroundColor Cyan
Write-Host "2. LanmanServer (Server)" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can run these commands to restart the services:" -ForegroundColor Yellow
Write-Host "Restart-Service LanmanWorkstation -Force" -ForegroundColor Gray
Write-Host "Restart-Service LanmanServer -Force" -ForegroundColor Gray
Write-Host ""
Write-Host "Or simply restart your computer." -ForegroundColor Yellow
pause