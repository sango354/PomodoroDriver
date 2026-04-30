$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$godotExe = Join-Path $repoRoot "tools/godot-spine-4.1.3/godot-4.1-4.1.3-stable.exe"
$projectDir = Join-Path $repoRoot "game"
$presetPath = Join-Path $projectDir "export_presets.cfg"
$buildDir = Join-Path $repoRoot "builds/windows"
$exePath = Join-Path $buildDir "Pomodoro.exe"
$zipPath = Join-Path $buildDir "Pomodoro-windows-x64.zip"
$infoPath = Join-Path $buildDir "build-info.txt"
$logDir = Join-Path $buildDir "logs"
$templateVersion = "4.1.3.stable"
$templateDir = Join-Path $env:APPDATA "Godot/export_templates/$templateVersion"
$templatePackage = Join-Path $repoRoot "tools/downloads/spine-godot-templates-4.1-4.1.3-stable.tpz"
$presetName = "Windows Desktop"
$musicManifestPath = Join-Path $projectDir "data/music_manifest.json"
$localizationCsvPath = Join-Path $projectDir "data/localization.csv"
$localizationManifestPath = Join-Path $projectDir "data/localization_manifest.json"

function Write-Step {
    param([string] $Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Require-File {
    param(
        [string] $Path,
        [string] $Description
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description not found: $Path"
    }
}

function Invoke-BuildProcess {
    param(
        [string] $FilePath,
        [string] $Arguments,
        [string] $LogName,
        [int] $TimeoutSeconds = 120,
        [int[]] $AllowedExitCodes = @(0)
    )

    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $stdoutPath = Join-Path $logDir "$LogName.out.log"
    $stderrPath = Join-Path $logDir "$LogName.err.log"

    $command = "`"$FilePath`" $Arguments > `"$stdoutPath`" 2> `"$stderrPath`""
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $env:ComSpec
    $startInfo.Arguments = "/d /s /c `"$command`""
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $false
    $startInfo.RedirectStandardError = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void] $process.Start()

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try {
            $process.Kill()
        } catch {
        }
        throw "Process timed out after $TimeoutSeconds seconds: $FilePath $Arguments"
    }

    $stdout = if (Test-Path -LiteralPath $stdoutPath) { [string](Get-Content -LiteralPath $stdoutPath -Raw) } else { "" }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { [string](Get-Content -LiteralPath $stderrPath -Raw) } else { "" }
    if ($null -eq $stdout) {
        $stdout = ""
    }
    if ($null -eq $stderr) {
        $stderr = ""
    }

    $combinedOutput = "$stdout`n$stderr"
    if ($combinedOutput -match "SCRIPT ERROR|Parse Error") {
        if ($stdout.Trim().Length -gt 0) {
            Write-Host $stdout
        }
        if ($stderr.Trim().Length -gt 0) {
            Write-Host $stderr
        }
        throw "Godot reported a script error. Logs: $logDir"
    }

    if ($process.ExitCode -notin $AllowedExitCodes) {
        if ($stdout.Trim().Length -gt 0) {
            Write-Host $stdout
        }
        if ($stderr.Trim().Length -gt 0) {
            Write-Host $stderr
        }
        throw "Process failed with exit code $($process.ExitCode): $FilePath $Arguments. Logs: $logDir"
    }

    return $stdout
}

function Ensure-SpineTemplates {
    $releaseTemplate = Join-Path $templateDir "windows_release_x86_64.exe"
    if (Test-Path -LiteralPath $releaseTemplate -PathType Leaf) {
        return
    }

    if (-not (Test-Path -LiteralPath $templatePackage -PathType Leaf)) {
        throw "Spine Godot export templates are missing. Expected either $releaseTemplate or $templatePackage"
    }

    Write-Step "Installing Spine Godot export templates"
    New-Item -ItemType Directory -Force -Path $templateDir | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($templatePackage)
    try {
        foreach ($entry in $zip.Entries) {
            $target = Join-Path $templateDir $entry.FullName
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    } finally {
        $zip.Dispose()
    }
}

function Stop-ExistingBuild {
    $normalizedExePath = [System.IO.Path]::GetFullPath($exePath)
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -eq "Pomodoro" -and
            $_.Path -ne $null -and
            [System.IO.Path]::GetFullPath($_.Path) -eq $normalizedExePath
        } |
        Stop-Process -Force
}

function Write-WindowsExportPreset {
    $content = @'
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="data/*.csv,data/*.json,assets/music/*.mp3,assets/music/*.ogg,assets/music/*.wav,assets/videos/break/*.mp4,assets/videos/break/*.ogv"
exclude_filter=""
export_path="../builds/windows/Pomodoro.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/embed_pck=true
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
codesign/enable=false
codesign/timestamp=true
codesign/timestamp_server_url=""
codesign/digest_algorithm=1
codesign/description=""
codesign/custom_options=PackedStringArray()
application/modify_resources=true
application/icon=""
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_version=""
application/company_name=""
application/product_name="Pomodoro"
application/file_description="Pomodoro"
application/copyright=""
application/trademarks=""
'@

    Set-Content -LiteralPath $presetPath -Value $content -Encoding ASCII
}

function Write-MusicManifest {
    $musicDir = Join-Path $projectDir "assets/music"
    $files = @()
    if (Test-Path -LiteralPath $musicDir -PathType Container) {
        $files = Get-ChildItem -LiteralPath $musicDir -File |
            Where-Object { $_.Extension.ToLowerInvariant() -in @(".mp3", ".ogg", ".wav") } |
            Sort-Object Name |
            ForEach-Object { "res://assets/music/$($_.Name)" }
    }
    $manifest = @{
        generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
        files = @($files)
    }
    $json = $manifest | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath $musicManifestPath -Value $json -Encoding UTF8
}

function Write-LocalizationManifest {
    if (-not (Test-Path -LiteralPath $localizationCsvPath -PathType Leaf)) {
        throw "Localization CSV not found: $localizationCsvPath"
    }

    $rows = Import-Csv -LiteralPath $localizationCsvPath -Encoding UTF8
    $manifestRows = [ordered]@{}
    foreach ($row in $rows) {
        $key = [string]$row.key
        if ([string]::IsNullOrWhiteSpace($key)) {
            continue
        }
        $entry = [ordered]@{}
        foreach ($language in @("en", "zh_TW", "zh_CN", "ja", "ko", "fr", "de", "it", "ru", "es_ES", "pt_BR")) {
            $entry[$language] = [string]$row.$language
        }
        $manifestRows[$key] = $entry
    }

    $manifest = [ordered]@{
        generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
        rows = $manifestRows
    }
    $json = $manifest | ConvertTo-Json -Depth 6
    Set-Content -LiteralPath $localizationManifestPath -Value $json -Encoding UTF8
}

Require-File -Path $godotExe -Description "Spine-enabled Godot editor"
Require-File -Path (Join-Path $projectDir "project.godot") -Description "Godot project"

Ensure-SpineTemplates

Write-Step "Preparing Windows export preset"
Write-WindowsExportPreset
Write-MusicManifest
Write-LocalizationManifest

Write-Step "Cleaning previous Windows build"
Stop-ExistingBuild
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Remove-Item -LiteralPath $exePath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $infoPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $buildDir "Pomodoro.pck") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $buildDir "Pomodoro.tmp") -Force -ErrorAction SilentlyContinue

Write-Step "Running headless project validation"
Invoke-BuildProcess -FilePath $godotExe -Arguments "--headless --path `"$projectDir`" --quit" -LogName "validate-project" -TimeoutSeconds 120 -AllowedExitCodes @(0, 1) | Out-Null

Write-Step "Exporting Windows release build"
Invoke-BuildProcess -FilePath $godotExe -Arguments "--headless --path `"$projectDir`" --export-release `"$presetName`" `"..\builds\windows\Pomodoro.exe`"" -LogName "export-windows" -TimeoutSeconds 600 -AllowedExitCodes @(0, 1) | Out-Null

if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw "Expected build output was not created: $exePath"
}
if (Test-Path -LiteralPath (Join-Path $buildDir "Pomodoro.tmp") -PathType Leaf) {
    throw "Godot left Pomodoro.tmp behind. Close any running Pomodoro.exe window and run the build again."
}

Write-Step "Verifying exported executable"
Invoke-BuildProcess -FilePath $exePath -Arguments "--headless --quit" -LogName "verify-export" -TimeoutSeconds 120 -AllowedExitCodes @(0, 1) | Out-Null

Write-Step "Creating zip package"
Compress-Archive -Path $exePath -DestinationPath $zipPath -Force

$exeHash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash
$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
$exeItem = Get-Item -LiteralPath $exePath
$zipItem = Get-Item -LiteralPath $zipPath
$godotVersion = (Invoke-BuildProcess -FilePath $godotExe -Arguments "--version" -LogName "godot-version" -TimeoutSeconds 30).Trim()

$buildInfo = @(
    "Pomodoro Windows Build"
    "Generated: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz"))"
    "Godot: $godotVersion"
    ""
    "Executable: $exePath"
    "Executable bytes: $($exeItem.Length)"
    "Executable SHA256: $exeHash"
    ""
    "Package: $zipPath"
    "Package bytes: $($zipItem.Length)"
    "Package SHA256: $zipHash"
)

Set-Content -LiteralPath $infoPath -Value $buildInfo -Encoding UTF8

Write-Step "Build outputs"
Get-ChildItem -LiteralPath $buildDir | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
Write-Host ""
Write-Host "EXE SHA256: $exeHash"
Write-Host "ZIP SHA256: $zipHash"
Write-Host ""
Write-Host "Build info: $infoPath"
