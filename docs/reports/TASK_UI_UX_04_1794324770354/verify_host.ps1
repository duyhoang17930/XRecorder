$ErrorActionPreference = 'Stop'
$dart = 'D:\Android\flutter\bin\cache\dart-sdk\bin\dart.exe'
$flutter = 'D:\Android\flutter\bin\cache\flutter_tools.snapshot'
function Check([string]$Name, [string[]]$Arguments) {
  $previousErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $lines = & $dart $flutter @Arguments 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorPreference
  $path = Join-Path $PSScriptRoot ($Name + '_' + [guid]::NewGuid().ToString('N') + '.txt')
  $stream = [IO.File]::Open($path, [IO.FileMode]::CreateNew)
  $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
  try { $writer.WriteLine('flutter ' + ($Arguments -join ' ')); foreach ($line in $lines) {$writer.WriteLine($line.ToString())}; $writer.WriteLine('Exit=' + $code) } finally { $writer.Dispose() }
  $lines | Select-Object -Last 12 | Write-Output
  Write-Output "$Name Exit=$code Log=$path"
  if ($code -ne 0) {exit $code}
}
Check 'analyze' @('analyze', '--no-pub')
Check 'editor_tests' @('test', '--no-pub', 'test/editor_hci_test.dart', 'test/photo_tools_test.dart', 'test/editor_effects_ui_test.dart', 'test/task09b_editor_interactions_test.dart', 'test/task09b_history_localization_test.dart', 'test/project_controller_test.dart', 'test/project_repository_test.dart', 'test/timeline_effects_test.dart', 'test/drawing_project_snapshot_test.dart', 'test/editor_preview_load_queue_test.dart', 'test/ux_interaction_test.dart', 'test/refinement_test.dart', 'test/global_layout_test.dart')
Check 'build' @('build', 'apk', '--debug', '--no-pub', '--target-platform', 'android-x64')
