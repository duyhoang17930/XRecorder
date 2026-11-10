"""Safety regression: a failed install must never lead to data removal."""
import importlib.util
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('qa_runner', ROOT / 'tool/run_qa_existing_app.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class InstallSafetyTest(unittest.TestCase):
    def test_driver_success_needs_completed_report_when_status_is_present(self):
        root = ROOT / 'build/verification/task09b'
        root.mkdir(parents=True, exist_ok=True)
        for payload, incomplete in [({'status': 'IN_PROGRESS'}, True),
                                    ({'partial': True}, True), ({'status': 'PASS'}, False),
                                    ({'partial': False}, False), ({'suites': {'native': 'PASS'}}, False)]:
            directory = Path(tempfile.mkdtemp(prefix='completion_', dir=root))
            path = directory / 'emulator_verification.json'
            original = json.dumps(payload).encode()
            runner.write_new(path, original)
            self.assertEqual(runner.completion_report_error(directory) is not None, incomplete)
            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(runner.completion_report_error(directory, True) is None, payload.get('status') == 'PASS')

    def test_external_absence_requires_readable_parent_and_exact_probe(self):
        for code, out, err, expected in [
            (0, b'ABSENT\n', b'', True),
            (0, b'PRESENT\n', b'', False),
        ]:
            def adb(*args, **kwargs):
                self.assertEqual(args[0], 'shell')
                self.assertNotIn('mkdir', args[1])
                return subprocess.CompletedProcess(args, code, out, err)
            self.assertEqual(runner.external_path_absent(adb), expected)
        for code, out, err in [(1, b'', b'Permission denied'), (0, b'', b''),
                               (0, b'ABSENT\n', b'cannot inspect')]:
            with self.assertRaisesRegex(RuntimeError, 'external'):
                runner.external_path_absent(lambda *a, **k: subprocess.CompletedProcess(a, code, out, err))

    def test_offline_checkpoint_is_byte_verified_and_cannot_be_reused(self):
        fixture = Path(tempfile.mkdtemp(prefix='checkpoint_v1_', dir=ROOT / 'build/verification/task08'))
        snapshot = fixture / 'snapshot'
        snapshot.mkdir()
        rows = []
        for name in ['config.ini', 'userdata-qemu.img.qcow2', 'encryptionkey.img']:
            data = ('retained fixture ' + name).encode()
            runner.write_new(snapshot / name, data)
            rows.append({'relativePath': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        identity = 'package:com.xrecorder.xrecorder uid:10217'
        manifest = fixture / 'manifest_v1.json'
        runner.write_new(manifest, json.dumps({
            'kind': 'offline_avd_checkpoint', 'serial': 'emulator-5566',
            'avd': 'ThreeHRecorder_TASK08_API36', 'packageIdentity': identity,
            'qemuExitedBeforeCopy': True, 'allSourceAndCopySha256Exact': True,
            'snapshotDirectory': str(snapshot), 'files': rows,
        }).encode())
        result = runner.validate_offline_checkpoint(manifest, ROOT, 'emulator-5566',
                                                   'ThreeHRecorder_TASK08_API36', identity)
        self.assertEqual(result['filesVerified'], 3)
        runner.write_new(Path(result['installClaim']), b'claimed by earlier update')
        with self.assertRaisesRegex(RuntimeError, 'already used'):
            runner.validate_offline_checkpoint(manifest, ROOT, 'emulator-5566',
                                               'ThreeHRecorder_TASK08_API36', identity)

    def test_validation_reports_never_overwrite_earlier_evidence(self):
        fixture = Path(tempfile.mkdtemp(prefix='validator_v1_', dir=ROOT / 'build/verification/task08'))
        for script, report, args in [
            ('validate_editor_audio.py', 'signal_validation.json', ['--directory', str(fixture), '--offline']),
            ('validate_p2_p3_outputs.py', 'validation.json', [str(fixture), '--ffmpeg-directory', str(fixture)]),
        ]:
            original = b'earlier evidence\x00\xff'
            runner.write_new(fixture / report, original)
            result = subprocess.run([sys.executable, str(ROOT / 'tool' / script), *args], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'preserve earlier evidence', result.stderr)
            self.assertEqual((fixture / report).read_bytes(), original)

    def test_truncated_archive_rejected_even_with_successful_adb_exit(self):
        fixture = Path(tempfile.mkdtemp(prefix='archive_v1_', dir=ROOT / 'build/verification/task08'))
        path = fixture / 'truncated_v1.tar'
        runner.write_new(path, b'incomplete transport payload')
        with self.assertRaisesRegex(RuntimeError, 'Incomplete QA archive'):
            runner.validate_tar(path)

    def test_complete_archive_accepted_with_declared_regular_bytes(self):
        fixture = Path(tempfile.mkdtemp(prefix='archive_v1_', dir=ROOT / 'build/verification/task08'))
        path = fixture / 'complete_v1.tar'
        with path.open('xb') as stream, tarfile.open(fileobj=stream, mode='w') as archive:
            entry = tarfile.TarInfo('files/fixture.bin')
            entry.size = 4
            archive.addfile(entry, io.BytesIO(b'\x00\x01\x02\xff'))
        self.assertEqual(runner.validate_tar(path), {'members': 1, 'regularFileBytes': 4})

    def test_existing_evidence_collision_keeps_original_bytes(self):
        fixture = Path(tempfile.mkdtemp(prefix='evidence_v1_', dir=ROOT / 'build/verification/task08'))
        path = fixture / 'evidence_v1.bin'
        runner.write_new(path, b'original evidence\x00\xff')
        with self.assertRaises(FileExistsError):
            runner.write_new(path, b'new content must not replace earlier evidence')
        self.assertEqual(path.read_bytes(), b'original evidence\x00\xff')

    def invoke(self, *, free_kb, install_ok=False, serial='emulator-5566', install_only=False,
               avd='ThreeHRecorder_TASK08_API36'):
        # Evidence is retained: TASK08 does not delete even temporary fixtures.
        fixture = Path(tempfile.mkdtemp(prefix='runner_', dir=ROOT / 'build/verification/task08'))
        apk = fixture / 'fixture.apk'
        apk.write_bytes(b'QA installer failure fixture, not an Android package')
        calls = []
        package_queries = 0

        def command(args, **kwargs):
            nonlocal package_queries
            calls.append(args)
            if args[-3:] == ['emu', 'avd', 'name']:
                out = b'ThreeHRecorder_TASK08_API36\nOK\n'
            elif args[-3:] == ['df', '-k', '/data']:
                out = f'Filesystem 1K-blocks Used Available Use% Mounted\n/data 9999999 1 {free_kb} 1% /data\n'.encode()
            elif 'install' in args:
                return subprocess.CompletedProcess(args, 0 if install_ok else 1,
                    b'Success' if install_ok else b'Failure [INSTALL_FAILED_INSUFFICIENT_STORAGE]', b'')
            elif 'package' in args and 'packages' in args:
                package_queries += 1
                out = b'' if package_queries == 1 else b'package:com.xrecorder.xrecorder uid:10217'
            else:
                out = b''
            return subprocess.CompletedProcess(args, 0, out, b'')

        argv = ['runner', '--serial', serial, '--avd', avd,
                '--apk', str(apk), '--output', str(fixture / 'evidence')]
        if install_only:
            argv.append('--install-only')
        with patch.object(sys, 'argv', argv), patch.object(subprocess, 'run', command):
            if install_only and install_ok:
                self.assertEqual(runner.main(), 0)
                error_text = ''
            else:
                with self.assertRaises(RuntimeError) as error:
                    runner.main()
                error_text = str(error.exception)
        self.assertFalse(any('uninstall' in c or 'clear' in c for c in calls))
        self.assertFalse(any('start' in c for c in calls))
        return calls, error_text

    def test_install_only_updates_once_and_never_launches(self):
        calls, error = self.invoke(free_kb=2 * 1024 * 1024, install_ok=True, install_only=True)
        self.assertEqual(error, '')
        self.assertEqual(sum('install' in c for c in calls), 1)

    def test_install_failure_aborts_without_retry_or_launch(self):
        calls, error = self.invoke(free_kb=2 * 1024 * 1024)
        self.assertIn('without uninstall or retry', error)
        self.assertEqual(sum('install' in c for c in calls), 1)

    def test_low_storage_rejected_before_install(self):
        calls, error = self.invoke(free_kb=300 * 1024)
        self.assertIn('Insufficient safe install margin', error)
        self.assertFalse(any('install' in c for c in calls))

    def test_personal_emulator_rejected_before_any_adb(self):
        calls, error = self.invoke(free_kb=2 * 1024 * 1024, serial='emulator-5554')
        self.assertIn('dedicated', error)
        self.assertEqual(calls, [])

    def test_recovery_device_rejected_by_serial_or_name_before_any_adb(self):
        for serial, avd in [
            ('emulator-5560', 'ThreeHRecorder_TASK09_API36'),
            ('emulator-5568', 'ThreeHRecorder_Task021'),
        ]:
            with self.subTest(serial=serial, avd=avd):
                calls, error = self.invoke(free_kb=2 * 1024 * 1024,
                                           serial=serial, avd=avd)
                self.assertIn('dedicated', error)
                self.assertEqual(calls, [])


if __name__ == '__main__':
    unittest.main()
