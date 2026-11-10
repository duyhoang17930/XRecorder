$ErrorActionPreference = 'Stop'
$dart = 'D:\Android\flutter\bin\cache\dart-sdk\bin\dart.exe'
$flutter = 'D:\Android\flutter\bin\cache\flutter_tools.snapshot'
function Invoke-Check([string]$Name, [string[]]$Arguments) {
  $lines = & $dart $flutter @Arguments 2>&1
  $code = $LASTEXITCODE
  $path = Join-Path $PSScriptRoot ($Name + '_' + [guid]::NewGuid().ToString('N') + '.txt')
  $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew)
  $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
  try {
    $writer.WriteLine('flutter ' + ($Arguments -join ' '))
    foreach ($line in $lines) { $writer.WriteLine($line.ToString()) }
    $writer.WriteLine('Exit=' + $code)
  } finally { $writer.Dispose() }
  $lines | Select-Object -Last 4 | Write-Output
  Write-Output "$Name Exit=$code Log=$path"
  if ($code -ne 0) { exit $code }
}
Invoke-Check 'final_analyzer' @('analyze', '--no-pub')
Invoke-Check 'final_regression' @('test', '--no-pub', 'test/ui_ux_03_test.dart', 'test/onboarding_test.dart', 'test/ui_startup_navigation_test.dart', 'test/refinement_test.dart', 'test/ui_ux_02c_test.dart', 'test/global_layout_test.dart', 'test/settings_persistence_test.dart', 'test/settings_accessibility_test.dart', 'test/support_test.dart', 'test/photo_tools_test.dart', 'test/ux_interaction_test.dart')
Invoke-Check 'final_build' @('build', 'apk', '--debug', '--no-pub', '--target-platform', 'android-x64')
