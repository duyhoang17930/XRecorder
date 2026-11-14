"""Fallback locale contracts allow regional wording but never missing arguments."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tool.check_l10n import ROOT, validate


class FallbackLocaleTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        for path in (ROOT / 'lib/l10n').glob('*.arb'):
            shutil.copyfile(path, self.directory / path.name)

    def update(self, key, value):
        path = self.directory / 'app_pt.arb'
        data = json.loads(path.read_text(encoding='utf8'))
        if value is None:
            del data[key]
        else:
            data[key] = value
        path.write_text(json.dumps(data, ensure_ascii=False), encoding='utf8')

    def test_preserves_valid_portuguese_regional_wording(self):
        self.assertEqual([], validate(self.directory))
        self.update('captureScreenshot', 'Captura de ecrã')
        self.assertEqual([], validate(self.directory))

    def test_missing_fallback_key_is_rejected(self):
        self.update('captureScreenshot', None)
        self.assertTrue(any('fallback keys differ' in issue for issue in validate(self.directory)))

    def test_fallback_placeholder_loss_is_rejected(self):
        self.update('onboardingProgress', 'Passo {current}')
        self.assertTrue(any('pt/onboardingProgress: placeholders' in issue
                            for issue in validate(self.directory)))


if __name__ == '__main__':
    unittest.main()
