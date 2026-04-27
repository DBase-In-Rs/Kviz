# build_aab.ps1 - builds a signed release AAB for Google Play
# Usage:
#   .\scripts\build_aab.ps1                  # auto-increment build number
#   .\scripts\build_aab.ps1 -Version "1.2.0" # also bump version name
#   .\scripts\build_aab.ps1 -NoBump          # keep current build number (re-sign only)
param(
    [string]$Version = "",       # e.g. "1.2.0" - if empty, reads from pubspec.yaml
    [switch]$NoBump              # skip build number increment
)

Set-Location $PSScriptRoot\..

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $repoRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
    $target = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $RelativePath))
    $repoPrefix = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $target.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to touch path outside repo: $target"
    }

    return $target
}

function Remove-RepoPathIfExists {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $target = Resolve-RepoPath $RelativePath
    if (Test-Path -LiteralPath $target) {
        Write-Host "Removing stale build output -> $RelativePath" -ForegroundColor DarkYellow
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

function Read-DartDefineValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) {
        return $value.Trim()
    }

    $secretsFile = "secrets\dart_defines.properties"
    if (Test-Path $secretsFile) {
        $line = Select-String "^$Name\s*=" $secretsFile | Select-Object -First 1
        if ($line) {
            return (($line.Line -split "=", 2)[1]).Trim()
        }
    }

    return ""
}

# 1. Read / bump build number
$buildNumberFile = "build_number.txt"
$buildNumber = [int](Get-Content $buildNumberFile -ErrorAction Stop).Trim()

if (-not $NoBump) {
    $buildNumber++
    Set-Content $buildNumberFile $buildNumber
    Write-Host "Build number -> $buildNumber" -ForegroundColor Cyan
} else {
    Write-Host "Build number (unchanged) -> $buildNumber" -ForegroundColor Yellow
}

# 2. Resolve version name
if ($Version -eq "") {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match "(?m)^version:\s*(\d+\.\d+\.\d+)") {
        $Version = $Matches[1]
    } else {
        Write-Error "Could not parse version from pubspec.yaml"; exit 1
    }
}
Write-Host "Version name -> $Version" -ForegroundColor Cyan

# 3. Update pubspec.yaml
$pubspec = Get-Content "pubspec.yaml" -Raw
$pubspec = $pubspec -replace "(?m)^version:.*$", "version: $Version+$buildNumber"
Set-Content "pubspec.yaml" $pubspec
Write-Host "pubspec.yaml updated -> version: $Version+$buildNumber" -ForegroundColor Green

# 4. Read Google Server Client ID (from env or secrets)
$googleClientId = Read-DartDefineValue "KVIZ_GOOGLE_SERVER_CLIENT_ID"
if (-not $googleClientId) {
    Write-Error "KVIZ_GOOGLE_SERVER_CLIENT_ID not set. Set env var or create secrets\dart_defines.properties"
    exit 1
}
$noAdsProductId = Read-DartDefineValue "KVIZ_IAP_NO_ADS_MONTHLY_ID"
$premierProductId = Read-DartDefineValue "KVIZ_IAP_PREMIER_MONTHLY_ID"

# 5. Flutter build
Write-Host "`nBuilding AAB release..." -ForegroundColor Cyan
$buildStartedAtUtc = (Get-Date).ToUniversalTime()
Remove-RepoPathIfExists "build\app"
Remove-RepoPathIfExists "android\app\build"
$splitDebugInfoDir = Resolve-RepoPath "build\symbols\android"
if (-not (Test-Path -LiteralPath $splitDebugInfoDir)) {
    New-Item -ItemType Directory -Path $splitDebugInfoDir | Out-Null
}

$flutterArgs = @(
    "build",
    "appbundle",
    "--release",
    "--obfuscate",
    "--split-debug-info=$splitDebugInfoDir",
    "--build-name=$Version",
    "--build-number=$buildNumber",
    "--dart-define=KVIZ_GOOGLE_SERVER_CLIENT_ID=$googleClientId"
)
if ($noAdsProductId) {
    $flutterArgs += "--dart-define=KVIZ_IAP_NO_ADS_MONTHLY_ID=$noAdsProductId"
    Write-Host "IAP no-ads product -> $noAdsProductId" -ForegroundColor Cyan
}
if ($premierProductId) {
    $flutterArgs += "--dart-define=KVIZ_IAP_PREMIER_MONTHLY_ID=$premierProductId"
    Write-Host "IAP premier product -> $premierProductId" -ForegroundColor Cyan
}
$flutterOutput = & flutter @flutterArgs 2>&1
$flutterBuildExitCode = $LASTEXITCODE

$aab = "build\app\outputs\bundle\release\app-release.aab"
$gradleAab = "android\app\build\outputs\bundle\release\app-release.aab"
$builtAab = @($aab, $gradleAab) |
    Where-Object { Test-Path -LiteralPath $_ } |
    Sort-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } -Descending |
    Select-Object -First 1

if (-not $builtAab) {
    $flutterOutput | ForEach-Object { Write-Host $_.ToString() }

    if ($flutterBuildExitCode -ne 0) {
        Write-Error "flutter build failed"
        exit 1
    }

    Write-Error "AAB was not created: $aab"
    exit 1
}

$flutterOutput |
    ForEach-Object { $_.ToString() } |
    Where-Object {
        $_ -notmatch '^Gradle build failed to produce an \.aab file\.' -and
        $_ -notmatch '^It''s likely that this file was generated under '
    } |
    ForEach-Object { Write-Host $_ }

$aabInfo = Get-Item -LiteralPath $builtAab
if ($aabInfo.LastWriteTimeUtc -lt $buildStartedAtUtc) {
    Write-Error "AAB is stale: $builtAab was last written at $($aabInfo.LastWriteTime)."
    exit 1
}

$manifestCandidates = @(
    "build\app\intermediates\merged_manifests\release\processReleaseManifest\AndroidManifest.xml",
    "build\app\intermediates\merged_manifest\release\processReleaseMainManifest\AndroidManifest.xml",
    "android\app\build\intermediates\merged_manifests\release\processReleaseManifest\AndroidManifest.xml",
    "android\app\build\intermediates\merged_manifest\release\processReleaseMainManifest\AndroidManifest.xml"
)
$manifest = $manifestCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $manifest) {
    Write-Error "Could not verify release manifest versionCode."
    exit 1
}

$manifestText = Get-Content -LiteralPath $manifest -Raw
if ($manifestText -notmatch 'android:versionCode="(\d+)"') {
    Write-Error "Could not parse versionCode from $manifest"
    exit 1
}

$actualVersionCode = [int]$Matches[1]
if ($actualVersionCode -ne $buildNumber) {
    Write-Error "Built versionCode mismatch: expected $buildNumber, got $actualVersionCode."
    exit 1
}

if ($builtAab -ne $aab) {
    $targetDir = Split-Path -Parent (Resolve-RepoPath $aab)
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir | Out-Null
    }
    Copy-Item -LiteralPath $builtAab -Destination $aab -Force
    Write-Host "Copied Gradle AAB to fastlane path -> $aab" -ForegroundColor DarkYellow
}

$size = [math]::Round((Get-Item $aab).Length / 1MB, 1)
Write-Host "`nAAB ready: $aab ($size MB)" -ForegroundColor Green
Write-Host "  version: $Version+$buildNumber (versionCode=$buildNumber)" -ForegroundColor Green
Write-Host "  split debug info: build\symbols\android" -ForegroundColor Green
exit 0
