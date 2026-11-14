"""Bounded TASK10 publication-window test; touches only this task's journal/media.

No capture-consent bypass: the input is the already recorded TASK10 MP4.
The current journal is task-created, verified by ID and archived before replacement.
"""
import hashlib
import json
from pathlib import Path
import uuid
import xml.etree.ElementTree as ET

import device_qa as q


def session(raw):
    return json.loads(ET.fromstring(raw).find("string[@name='session']").text)


q.identity()
original = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
assert session(original)['id'] == 'cf1507ee-8c55-4409-8557-b4ba02744189'
assert session(original)['state'] == 'failed'
source_uri = 'content://media/external/video/media/46'
source = q.adb('exec-out', 'content', 'read', '--uri', source_uri)
assert source == (q.ROOT / 'task10_recording_mute.mp4').read_bytes()
with (q.ROOT / 'journal_before_publication_fixture.xml').open('xb') as stream:
    stream.write(original)
archive = q.adb('exec-out', 'run-as', q.PACKAGE, 'tar', '-cf', '-', 'shared_prefs', 'files', 'no_backup')
with (q.ROOT / 'private_before_recovery_candidate.tar').open('xb') as stream:
    stream.write(archive)
apk = Path('build/app/outputs/flutter-apk/app-profile.apk')
print(q.adb('install', '-r', str(apk), timeout=90).decode(), flush=True)
(q.ROOT / 'recovery_apk_identity.json').write_text(json.dumps({
    'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(), 'bytes': apk.stat().st_size,
    'mode': 'profile', 'sourceNote': 'Unused Dart import removed after this build; no executable behavior delta.'
}, indent=2))
q.adb('shell', 'am', 'force-stop', q.PACKAGE)
fixture = session((q.ROOT / 'profile_capture_final_journal.xml').read_bytes())
fixture.update(id=str(uuid.uuid4()), state='finalizing', outputUri=None)
root = ET.Element('map')
ET.SubElement(root, 'string', name='session').text = json.dumps(fixture, separators=(',', ':'))
ET.SubElement(root, 'string', name='pending').text = source_uri
fixture_path = q.ROOT / 'publication_window_fixture.xml'
with fixture_path.open('xb') as stream:
    stream.write(ET.tostring(root, encoding='utf-8', xml_declaration=True))
remote = '/data/local/tmp/task10_publication_window_fixture.xml'
q.adb('push', str(fixture_path), remote)
q.adb('shell', 'run-as', q.PACKAGE, 'cp', remote, 'shared_prefs/capture_journal.xml')
print(q.adb('shell', 'am', 'start', '-W', '-n', q.PACKAGE + '/.MainActivity').decode(), flush=True)
q.run([{'wait': 2, 'save': 'publication_recovery_ui'}])
after = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
with (q.ROOT / 'publication_recovery_journal.xml').open('xb') as stream:
    stream.write(after)
result = session(after)
assert result['id'] == fixture['id']
assert result['state'] == 'completed', result
assert result['outputUri'] == source_uri
assert ET.fromstring(after).find("string[@name='pending']") is None
assert q.adb('exec-out', 'content', 'read', '--uri', source_uri) == source
checkpoint = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'files/capture_recovery/' + fixture['id'] + '.json')
with (q.ROOT / 'publication_recovery_checkpoint.json').open('xb') as stream:
    stream.write(checkpoint)
report = {
    'fixtureSessionId': fixture['id'], 'state': result['state'], 'originalUri': source_uri,
    'mediaBytesUnchanged': True, 'sha256': hashlib.sha256(source).hexdigest(),
    'pendingClearedOnlyWithCompletedJournal': True,
    'nativeChecks': 'Mp4RecoveryEngine structure, owner, tracks, dimensions and decoded video frame',
    'scope': 'Publication completed before process loss; existing task media URI reused, no duplicate output',
    'notCovered': 'IS_PENDING=1 publication, unfinished MP4 reconstruction, audio temp remux, API24-28'
}
(q.ROOT / 'publication_recovery_validation.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report), flush=True)
