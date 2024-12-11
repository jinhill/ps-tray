# ps2exe .\sing-box-tray.ps1 .\sing-box-tray.exe -noConsole -icon "sing-box.ico" -requireAdmin

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$global:ProgressPreference = "SilentlyContinue"

# 定义全局变量
#$workDirectory = [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
$workDirectory = ".\"
$appName = "Sing-Box Tray"
$jobName = "SingBoxJob"
$appPath = Join-Path $workDirectory "sing-box-latest.exe"
$configPath = Join-Path $workDirectory "config_v11.json"
$iconPathRunning = Join-Path $workDirectory "sing-box.ico"
$iconPathStopped = Join-Path $workDirectory "sing-box-stop.ico"

# 获取版本信息
function Get-Version {
    param([string]$source)
    if ($source -eq "local") {
		return (& $appPath version).Split("`n")[0].Split(" ")[2]
    } elseif ($source -eq "latest") {
        $apiUrl = "https://api.github.com/repos/SagerNet/sing-box/tags"
        $response = Invoke-WebRequest -Uri $apiUrl -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            return ($response.Content | ConvertFrom-Json)[0].name -replace "^v"
        }
        return $null
    }
}

# 比较版本号，返回布尔值表示是否需要更新
function Compare-Version {

    param(
        [string]$localVersion,
        [string]$remoteVersion
    )

    # 去掉 '-beta' 后缀，但保留版本号后面的数字部分
    $localVersion = $localVersion -replace '-beta', ''
    $remoteVersion = $remoteVersion -replace '-beta', ''
	#Write-Host "本地版本1: $localVersion ,最新版本1: $remoteVersion " 
    # 比较版本号
    if ($localVersion -lt $remoteVersion) {
        return $true  # 本地版本较低
    } elseif ($localVersion -gt $remoteVersion) {
        return $false  # 本地版本较高
    }

    return $false  # 两个版本相同
}

# 更新操作
function Update {
    $localVersion = Get-Version -source "local"
    $latestVersion = Get-Version -source "latest"
    if ($null -eq $latestVersion) {
        [System.Windows.Forms.MessageBox]::Show("无法获取最新版本信息", $appName)
        return
    }

    if (Compare-Version $localVersion $latestVersion) {
        if ([System.Windows.Forms.MessageBox]::Show("新版本可用 ($latestVersion)，是否要升级？", "更新提示", [System.Windows.Forms.MessageBoxButtons]::YesNo) -eq "Yes") {
            try {
                $downloadUrl = "https://github.com/SagerNet/sing-box/releases/download/v$latestVersion/sing-box-$latestVersion-windows-amd64.zip"
                $zipFile = Join-Path $workDirectory "sing-box.zip"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -ErrorAction Stop
                
                $tempDir = Join-Path $workDirectory "temp"
                Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force -ErrorAction Stop
                
                JobAction -action "Stop"
                Copy-Item -Path (Join-Path $tempDir "sing-box-$latestVersion-windows-amd64\sing-box.exe") -Destination $appPath -Force
                
                Remove-Item -Path $tempDir -Recurse -Force
                Remove-Item -Path $zipFile -Force
                JobAction -action "Start" -message "服务已成功更新"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("更新失败：$_", $appName)
            }
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("当前版本: $localVersion, 已是最新", $appName)
    }
}

# 服务操作
function JobAction {
    param($action, $message)
    $process = Get-Process -Name "sing-box-latest" -ErrorAction SilentlyContinue
    switch ($action) {
        "Start" {
            if (-not $process) {
                Start-Process -FilePath $appPath -ArgumentList "run", "-c", $configPath, "-D", $workDirectory -WindowStyle Hidden
                if ($message) { [System.Windows.Forms.MessageBox]::Show($message, $appName) }
            } else {
                [System.Windows.Forms.MessageBox]::Show("服务已在运行", $appName)
            }
        }
        "Stop" {
            if ($process) {
                Stop-Process -Id $process.Id -Force
                if ($message) { [System.Windows.Forms.MessageBox]::Show($message, $appName) }
            }
        }
    }
    UpdateTrayIcon
}

# 更新托盘图标
function UpdateTrayIcon {
    $iconPath = if (Get-Process -Name "sing-box-latest" -ErrorAction SilentlyContinue) { $iconPathRunning } else { $iconPathStopped }
    $notifyIcon.Icon = [System.Drawing.Icon]::new($iconPath)
}

# 创建托盘图标
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
# 初始化托盘图标
UpdateTrayIcon
$notifyIcon.Visible = $true
$notifyIcon.Text = "$appName Control"

# 创建上下文菜单
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
@(
	@{Text="控制面板"; Action={Start-Process "http://127.0.0.1:9095"}},
    @{Text="启动服务"; Action={JobAction -action "Start" -message "服务已启动"}},
    @{Text="停止服务"; Action={JobAction -action "Stop" -message "服务已停止"}},
    @{Text="检查更新"; Action={Update}},
    @{Text="退出"; Action={
        JobAction -action "Stop"
        $notifyIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    }}
) | ForEach-Object {
    $menuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuItem.Text = $_.Text
    $menuItem.Add_Click($_.Action)
    $contextMenu.Items.Add($menuItem) | Out-Null
}

$notifyIcon.ContextMenuStrip = $contextMenu
JobAction -action "Start"
# 保持脚本运行以保持托盘图标可见
[System.Windows.Forms.Application]::Run()
