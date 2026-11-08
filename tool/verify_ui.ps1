param(
    [ValidateSet('visual', 'native', 'screenshot-visual', 'screenshot-native', 'performance', 'ux')][string]$Mode = 'visual',
    [string]$Device = 'emulator-5560',
    [string]$ExpectedAvdName = 'ThreeHRecorder_Task021',
    [string]$ApplicationBinary,
    [string]$ArtifactDirectory,
    [switch]$Before,
    [ValidateSet('debug', 'profile')][string]$BuildMode = 'debug',
    [ValidateSet('before', 'after')][string]$PerformancePhase = 'before',
    [switch]$PreserveTestOutputs
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$properties = Get-Content -LiteralPath (Join-Path $repoRoot 'android/local.properties')
function LocalSdkPath([string]$key) {
    $line = $properties | Where-Object { $_.StartsWith($key + '=') } | Select-Object -First 1
    if (-not $line) { throw "Missing $key in android/local.properties" }
    return $line.Substring($key.Length + 1).Replace('\\', '\').Replace('\:', ':')
}
$adb = Join-Path (LocalSdkPath 'sdk.dir') 'platform-tools/adb.exe'
$flutter = Join-Path (LocalSdkPath 'flutter.sdk') 'bin/flutter.bat'
$name = (& $adb -s $Device shell getprop ro.boot.qemu.avd_name).Trim()
if ($LASTEXITCODE -ne 0 -or $name -ne $ExpectedAvdName) {
    throw "Refusing device $Device ($name). Use a dedicated test AVD named $ExpectedAvdName."
}
if ((& $adb -s $Device shell dumpsys activity services com.xrecorder.xrecorder) -match '\.recording\.CaptureService') {
    throw 'Refusing to stop/install while CaptureService is active on the test AVD.'
}
if ($Mode -eq 'performance' -and $BuildMode -ne 'profile') { throw 'Performance mode requires -BuildMode profile.' }

$target = switch ($Mode) {
    'ux' { 'integration_test/ux_interaction_test.dart' }
    'performance' { 'integration_test/performance_benchmark_test.dart' }
    'native' { 'integration_test/refinement_native_test.dart' }
    'screenshot-native' { 'integration_test/screenshot_native_test.dart' }
    'screenshot-visual' { 'integration_test/screenshot_visual_test.dart' }
    default { 'integration_test/refinement_visual_test.dart' }
}
$output = switch ($Mode) {
    'ux' { if ($Before) { 'build/verification/ui/task031/before' } else { 'build/verification/ui/task031/after' } }
    'performance' { "build/verification/performance/task03/$PerformancePhase" }
    'native' { 'build/verification/ui/task021/native' }
    'screenshot-native' { 'build/verification/ui/task022/native' }
    'screenshot-visual' { if ($Before) { 'build/verification/ui/task022/before' } else { 'build/verification/ui/task022/after' } }
    default { 'build/verification/ui/task021/after' }
}
if ($ArtifactDirectory) { $output = $ArtifactDirectory }
$arguments = @('build', 'apk', "--$BuildMode", '--no-tree-shake-icons', "--target=$target")
if ($Mode -eq 'performance') { $arguments += "--dart-define=PERF_LABEL=$PerformancePhase" }
if ($Mode -eq 'ux' -and -not $Before) { $arguments += '--dart-define=UX_AFTER=true' }
if ($PreserveTestOutputs) { $arguments += '--dart-define=PRESERVE_TEST_OUTPUTS=true' }
if ($Mode -eq 'visual') { $arguments += '--dart-define=TASK021_AFTER=true' }
if ($Mode -eq 'screenshot-visual' -and -not $Before) { $arguments += '--dart-define=TASK022_AFTER=true' }
$previousDirectory = Get-Location
$previousOutput = $env:UI_ARTIFACT_DIRECTORY
try {
    Set-Location -LiteralPath $repoRoot
    $env:UI_ARTIFACT_DIRECTORY = $output
    # Flutter's Android install fallback can uninstall after install -r fails.
    # Build separately; the QA runner only updates with adb and attaches to the
    # running VM. Its capacity/backup/UID checks abort without an uninstall.
    $ErrorActionPreference = 'Continue'
    if (-not $ApplicationBinary) {
        & $flutter @arguments
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $ApplicationBinary = Join-Path $repoRoot "build/app/outputs/flutter-apk/app-$BuildMode.apk"
    }
    $dart = Join-Path (LocalSdkPath 'flutter.sdk') 'bin/cache/dart-sdk/bin/dart.exe'
    & python tool/run_qa_existing_app.py --serial $Device --avd $ExpectedAvdName --apk $ApplicationBinary --output $output --adb $adb --dart $dart --driver test_driver/design_system_driver.dart
    $result = $LASTEXITCODE
} finally {
    Set-Location -LiteralPath $previousDirectory.Path
    if ($null -eq $previousOutput) { Remove-Item Env:UI_ARTIFACT_DIRECTORY -ErrorAction SilentlyContinue }
    else { $env:UI_ARTIFACT_DIRECTORY = $previousOutput }
}
exit $result
