# Advanced Windows Security & Forensic Auditor
# Professional Edition - Modular & Aesthetic

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Theme & UI ---
$white = [char]27 + "[97m"; $blue = [char]27 + "[94m"; $yellow = [char]27 + "[93m"
$red   = [char]27 + "[91m"; $green = [char]27 + "[92m"; $reset  = [char]27 + "[0m"
$gray  = [char]27 + "[90m"

$ReportFile = "$env:USERPROFILE\Desktop\Security_Audit_Report.txt"

function Write-Separator {
    Write-Host "$gray------------------------------------------------------------$reset"
}

function Show-Header {

    Clear-Host

    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {$_.IPAddress -notlike "169.*" -and $_.InterfaceAlias -notmatch "Loopback"} |
    Select-Object -First 1).IPAddress

    if (!$ip) { $ip = "Unknown" }

    $model = (Get-CimInstance Win32_ComputerSystem).Model

    Write-Host "$blue"
    Write-Host "  ┌────────────────────────────────────────────────────────┐"
    Write-Host "  │            WINDOWS FORENSIC & SECURITY AUDIT           │"
    Write-Host "  └────────────────────────────────────────────────────────┘"
    Write-Host "   $white Model: $model | IPv4: $ip $reset"
    Write-Host ""
}

# --- Module 1: Download Artifact Scan ---
function Get-DownloadHistory {

    Write-Host "$yellow[!] Checking download artifacts...$reset"
    Write-Separator

    $path = "$env:USERPROFILE\Downloads"

    if(Test-Path $path){

        Get-ChildItem $path -Recurse -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 20 Name,LastWriteTime |
        Format-Table

    }
}

# --- Module 2: Process Location Audit ---
function Get-ProcessAudit {

    Write-Host "$yellow[!] Scanning processes for unusual locations...$reset"
    Write-Separator

    $procs = Get-CimInstance Win32_Process

    foreach ($p in $procs){

        $path = $p.ExecutablePath

        if ($path -match "AppData|Temp|ProgramData|Public"){

            Write-Host "$red$p.Name (PID $($p.ProcessId)) -> $path$reset"
        }

    }

}

# --- Module 3: Persistence Audit ---
function Get-Persistence {

    Write-Host "$yellow[!] Checking startup persistence...$reset"
    Write-Separator

    $keys = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach($k in $keys){

        if(Test-Path $k){

            $props = Get-ItemProperty $k

            foreach($p in $props.PSObject.Properties){

                if($p.Name -notmatch "PS"){

                    Write-Host "$blue$p.Name -> $($p.Value)$reset"

                }

            }

        }

    }

}

# --- Module 4: Prefetch Execution History ---
function Get-PrefetchScan {

    Write-Host "$yellow[!] Checking Prefetch execution history...$reset"
    Write-Separator

    $pf="C:\Windows\Prefetch"

    if(Test-Path $pf){

        Get-ChildItem $pf -Filter *.pf |
        Sort LastWriteTime -Descending |
        Select -First 20 Name,LastWriteTime |
        Format-Table

    }

}

# --- Module 5: Driver Scan ---
function Get-DriverScan {

    Write-Host "$yellow[!] Scanning loaded drivers...$reset"
    Write-Separator

    Get-WmiObject Win32_SystemDriver |
    Where {$_.State -eq "Running"} |
    Select Name,DisplayName,PathName |
    Format-Table

}

# --- Module 6: USB Device History ---
function Get-USBHistory {

    Write-Host "$yellow[!] Checking USB device history...$reset"
    Write-Separator

    $usb="HKLM:\SYSTEM\CurrentControlSet\Enum\USBSTOR"

    if(Test-Path $usb){

        Get-ChildItem $usb |
        Select Name |
        Format-Table

    }

}

# --- Module 7: DNS Cache ---
function Get-DNSCache {

    Write-Host "$yellow[!] Viewing DNS cache...$reset"
    Write-Separator

    try{

        Get-DnsClientCache |
        Select Entry,Data |
        Format-Table

    }catch{

        ipconfig /displaydns

    }

}

# --- Module 8: Service Scan ---
function Get-ServiceAudit {

    Write-Host "$yellow[!] Scanning running services...$reset"
    Write-Separator

    Get-Service |
    Where {$_.Status -eq "Running"} |
    Select Name,DisplayName |
    Format-Table

}

# --- Main Logic ---
while ($true) {

    Show-Header

    Write-Host "  $white 1.$reset $blue Full System Scan$reset"
    Write-Host "  $white 2.$reset Download Artifact Scan"
    Write-Host "  $white 3.$reset Process Location Audit"
    Write-Host "  $white 4.$reset Startup Persistence"
    Write-Host "  $white 5.$reset Prefetch Execution History"
    Write-Host "  $white 6.$reset Driver Scan"
    Write-Host "  $white 7.$reset USB Device History"
    Write-Host "  $white 8.$reset DNS Cache"
    Write-Host "  $white 9.$reset Service Scan"
    Write-Host "  $white C.$reset Clear Console"
    Write-Host "  $white Q.$reset $red Exit$reset"
    Write-Host ""

    $opt = Read-Host "  Execute Option"

    switch ($opt) {

        "1"{
            Get-DownloadHistory
            Get-ProcessAudit
            Get-Persistence
            Get-PrefetchScan
            Get-DriverScan
            Get-USBHistory
            Get-DNSCache
            Get-ServiceAudit
            Read-Host "Press Enter"
        }

        "2"{Get-DownloadHistory;Read-Host "Press Enter"}
        "3"{Get-ProcessAudit;Read-Host "Press Enter"}
        "4"{Get-Persistence;Read-Host "Press Enter"}
        "5"{Get-PrefetchScan;Read-Host "Press Enter"}
        "6"{Get-DriverScan;Read-Host "Press Enter"}
        "7"{Get-USBHistory;Read-Host "Press Enter"}
        "8"{Get-DNSCache;Read-Host "Press Enter"}
        "9"{Get-ServiceAudit;Read-Host "Press Enter"}

        "C"{Clear-Host}
        "Q"{break}
        "q"{break}

    }

}