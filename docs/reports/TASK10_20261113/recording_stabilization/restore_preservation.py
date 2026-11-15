"""Restore only the preference normalization introduced by this QA run."""
import hashlib
import json
from pathlib import Path
import sys
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).parent
sys.path.insert(0, str(root.parent))
import device_qa as q

q.identity()
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
baseline = root / 'mixed_zero_mic_settings_before.xml'
original = baseline.read_bytes()
current = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')
document = lambda raw: json.loads(ET.fromstring(raw).find("string[@name='document']").text)
expected = document(original)
expected['values'].setdefault('screenshotDelay', '3s')
if current != original:
    assert document(current) == expected, 'Unexpected settings change; preserve and inspect'
    q.adb('shell', 'am', 'force-stop', q.PACKAGE)
    subprocess.run(q.ADB + ['exec-in', 'run-as', q.PACKAGE, 'tee',
        'shared_prefs/app_settings.xml'], input=original, capture_output=True, check=True, timeout=30)
assert q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml') == original
before = json.loads((root / 'current_metadata.json').read_text())
results = {}
for path, sha in before.items():
    if path in ['shared_prefs/capture_journal.xml', 'files/profileInstalled']:
        continue  # Actual task capture journal and platform install marker may change.
    actual = q.adb('exec-out', 'run-as', q.PACKAGE, 'sha256sum', path).split()[0].decode()
    results[path] = actual == sha
model = q.adb('shell', 'run-as', q.PACKAGE, 'ls', 'no_backup/speech_models').decode().strip()
report = {'currentAvd': q.identity(), 'currentSettingsByteExactToSessionEntry': True,
    'originalDraftsByteExact': sum(path.startswith('files/projects/') and same for path, same in results.items()),
    'monitoredFiles': results, 'allMonitoredFilesByteExact': all(results.values()),
    'currentModelDirectoryListing': model, 'historicalTinyModelPreservationVerified': False,
    'historicalRecoveryCheckpointStateReproduced': False,
    'expectedChanges': ['task-created media and fixture files', 'actual capture journal', 'platform install marker'],
    'noUserMediaModelDraftDeletionRequested': True}
with (root / 'final_preservation.json').open('x') as stream:
    json.dump(report, stream, indent=2)
print(json.dumps(report, indent=2))
assert report['allMonitoredFilesByteExact'] and report['originalDraftsByteExact'] == 8
