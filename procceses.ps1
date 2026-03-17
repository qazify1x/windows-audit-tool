# =========================================================================================
# Script Name: Process Remover
# Description: Safely terminates non-essential processes to free up system resources.
# Features: Basic/Advanced Modes, Restoration Support, and Process Documentation.
# =========================================================================================

# 1. Ensure Administrative Privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell -Verb runAs -ArgumentList $args
    Break
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- Configuration & Data Sets ---
$Global:RestoreList = @()

# RED: Core Windows Kernel processes (Hard-locked for safety)
$RedList = @("system","idle","winlogon","csrss","lsass","smss","services","svchost","wininit","explorer","runtimebroker","searchhost","dwm","fontdrvhost","taskhostw","ctfmon")

# SYSTEM YELLOW: Microsoft processes providing vital hardware/UI functions
$ProtectedYellows = @("audiodg", "spoolsv", "shellexperiencehost", "siihost", "startmenuexperiencehost", "smartscreen", "securityhealthservice")

function Get-ProcessCategory {
    param($Proc)
    $Name = $Proc.ProcessName.ToLower()
    
    if ($RedList -contains $Name) { 
        return @("DO NOT TOUCH", [System.Drawing.Color]::Red, "CRITICAL: Essential Windows component. Termination will crash the system.") 
    }
    if ($ProtectedYellows -contains $Name) { 
        return @("SYSTEM", [System.Drawing.Color]::IndianRed, "VITAL: Microsoft service for Audio, Start Menu, or Hardware. Best left running.") 
    }
    if ($Proc.Company -match "Microsoft") { 
        return @("CAUTION", [System.Drawing.Color]::Orange, "MICROSOFT: Non-essential background task. Safe to stop in Advanced mode.") 
    }
    return @("SAFE", [System.Drawing.Color]::LimeGreen, "THIRD-PARTY: Standard application. Completely safe to stop for performance.")
}

function Update-ProcessGrid {
    $grid.SuspendLayout()
    $grid.Rows.Clear()
    $searchTerm = $txtSearch.Text.ToLower()
    
    # Fast query of current processes
    $processSnapshot = Get-Process | Select-Object ProcessName, Id, WorkingSet, Company, Path
    
    foreach ($p in $processSnapshot) {
        if ($p.ProcessName.ToLower().Contains($searchTerm)) {
            $cat = Get-ProcessCategory $p
            $memUsage = "{0:N0} MB" -f ($p.WorkingSet / 1MB)
            $rowIdx = $grid.Rows.Add($p.ProcessName, $memUsage, $cat[0], $cat[2])
            $grid.Rows[$rowIdx].Cells[2].Style.ForeColor = $cat[1]
            
            if ($cat[0] -eq "DO NOT TOUCH") { 
                $grid.Rows[$rowIdx].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray 
            }
        }
    }
    
    $lblActiveCount.Text = "Active Processes: $($processSnapshot.Count)"
    $lblDisabledCount.Text = "Restore List: $($Global:RestoreList.Count)"
    $grid.ResumeLayout()
}

function Invoke-Optimization {
    $mode = $comboMode.SelectedItem.ToString()
    
    $targets = Get-Process | Where-Object { 
        $cat = (Get-ProcessCategory $_)[0]
        $eligible = if ($mode -eq "Basic (Green Only)") { $cat -eq "SAFE" } else { $cat -eq "SAFE" -or $cat -eq "CAUTION" }
        
        # Guard Clause: Prevent self-termination and system crashes
        $eligible -and $cat -ne "DO NOT TOUCH" -and $cat -ne "SYSTEM" -and $_.Id -ne $PID -and $_.ProcessName -notmatch "powershell|pwsh"
    }
    
    foreach ($p in $targets) {
        try { 
            if ($p.Path) { $Global:RestoreList += @{ Name = $p.ProcessName; Path = $p.Path } }
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue 
        } catch {}
    }
    Update-ProcessGrid
}

# --- GUI Construction ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Surgical System Utility"
$form.Size = "500, 680"
$form.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 25)
$form.FormBorderStyle = "FixedToolWindow"
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Top Controls
$lblMode = New-Object System.Windows.Forms.Label
$lblMode.Text = "Optimization Level:"; $lblMode.ForeColor = [System.Drawing.Color]::White; $lblMode.Location = "15, 10"; $lblMode.AutoSize = $true

$comboMode = New-Object System.Windows.Forms.ComboBox
$comboMode.Location = "15, 30"; $comboMode.Size = "455, 25"; $comboMode.DropDownStyle = "DropDownList"
$comboMode.Items.AddRange(@("Basic (Green Only)", "Advanced (Green + Safe Yellow)")); $comboMode.SelectedIndex = 1

$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = "Filter by Name:"; $lblSearch.ForeColor = [System.Drawing.Color]::White; $lblSearch.Location = "15, 65"; $lblSearch.AutoSize = $true

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Location = "15, 85"; $txtSearch.Size = "455, 25"; $txtSearch.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45); $txtSearch.ForeColor = [System.Drawing.Color]::White; $txtSearch.BorderStyle = "FixedSingle"
$txtSearch.Add_TextChanged({ Update-ProcessGrid })

# Main DataGrid
$grid = New-Object System.Windows.Forms.DataGridView
$grid.Size = "455, 260"; $grid.Location = "15, 120"; $grid.BackgroundColor = [System.Drawing.Color]::FromArgb(25, 25, 25); $grid.ForeColor = [System.Drawing.Color]::White
$grid.RowHeadersVisible = $false; $grid.ReadOnly = $true; $grid.SelectionMode = "FullRowSelect"; $grid.AutoSizeColumnsMode = "Fill"; $grid.BorderStyle = "None"
$grid.EnableHeadersVisualStyles = $false; $grid.RowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
$grid.ColumnCount = 4
$grid.Columns[0].Name = "Process"; $grid.Columns[1].Name = "Memory"; $grid.Columns[2].Name = "Status"; $grid.Columns[3].Visible = $false

# Documentation Area
$txtDescription = New-Object System.Windows.Forms.TextBox
$txtDescription.Multiline = $true; $txtDescription.Location = "15, 395"; $txtDescription.Size = "455, 70"; $txtDescription.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40); $txtDescription.ForeColor = [System.Drawing.Color]::Cyan
$txtDescription.ReadOnly = $true; $txtDescription.BorderStyle = "None"; $txtDescription.Text = "Select a process to view its role..."
$grid.Add_CellClick({ if ($grid.SelectedRows.Count -gt 0) { $txtDescription.Text = $grid.SelectedRows[0].Cells[3].Value } })

# Metrics
$lblActiveCount = New-Object System.Windows.Forms.Label
$lblActiveCount.ForeColor = [System.Drawing.Color]::LightGray; $lblActiveCount.Location = "15, 475"; $lblActiveCount.AutoSize = $true
$lblDisabledCount = New-Object System.Windows.Forms.Label
$lblDisabledCount.ForeColor = [System.Drawing.Color]::LightGray; $lblDisabledCount.Location = "250, 475"; $lblDisabledCount.AutoSize = $true

# Button Builder
function Create-Button($text, $x, $y, $w, $bg, $fg, $action) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text; $btn.Location = "$x, $y"; $btn.Size = "$w, 45"
    $btn.FlatStyle = "Flat"; $btn.BackColor = $bg; $btn.ForeColor = $fg
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $btn.Add_Click($action); return $btn
}

# Footer Controls
$btnRun     = Create-Button "RUN OPTIMIZATION" 15 515 220 ([System.Drawing.Color]::LimeGreen) ([System.Drawing.Color]::Black) { Invoke-Optimization }
$btnRefresh = Create-Button "REFRESH LIST" 250 515 220 ([System.Drawing.Color]::FromArgb(60, 60, 60)) ([System.Drawing.Color]::White) { Update-ProcessGrid }
$btnRestore = Create-Button "RESTORE ALL" 15 570 455 ([System.Drawing.Color]::DarkRed) ([System.Drawing.Color]::White) { 
    $Global:RestoreList | ForEach-Object { if ($_.Path) { try { Start-Process $_.Path -WindowStyle Minimized -ErrorAction SilentlyContinue } catch {} } }
    $Global:RestoreList = @(); Update-ProcessGrid
}

$form.Controls.AddRange(@($lblMode, $comboMode, $lblSearch, $txtSearch, $grid, $txtDescription, $lblActiveCount, $lblDisabledCount, $btnRun, $btnRefresh, $btnRestore))

# Initialize Display
Update-ProcessGrid
$form.ShowDialog()
