"""Targeted real P1 localization/AX regression; restore preferences exactly."""
import json
import argparse
from pathlib import Path
import re
import xml.etree.ElementTree as ET
import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', default='2')
parser.add_argument('--notices', action='store_true')
parser.add_argument('--guide-only', action='store_true')
parser.add_argument('--locales', nargs='+', choices=['vi', 'ar'], default=['vi', 'ar'])
parser.add_argument('--core-labels', action='store_true')
args = parser.parse_args()
assert re.fullmatch('[a-z0-9]+', args.attempt)
q.identity()
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()


def prefs():
    return q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')


def values(raw):
    return json.loads(ET.fromstring(raw).find("string[@name='document']").text)['values']


def arb(locale):
    return json.loads(Path('lib/l10n/app_' + locale + '.arb').read_text(encoding='utf8'))


def root_settings():
    q.adb('shell', 'am', 'force-stop', q.PACKAGE)
    # Wait for Android's actual first display before attaching UIAutomator.
    # Cold launch is currently slow; that performance defect stays separate.
    launched = q.adb('shell', 'am', 'start', '-W', '-n', q.PACKAGE + '/.MainActivity', timeout=60)
    assert b'Status: ok' in launched
    q.click(arb(values(prefs())['appLocale'])['settings'])


def choose(locale):
    current = arb(values(prefs())['appLocale'])
    q.click(current['appLanguage'])
    _, nodes = q.tree()
    search = next(n for n in nodes if n.get('class') == 'android.widget.EditText')
    assert not search.get('text'), 'Preserve any existing user search'
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', search.get('bounds')))
    q.tap((x1+x2)//2, (y1+y2)//2)
    q.adb('shell', 'input', 'text', locale)
    q.click({'en': 'English', 'vi': 'Tiếng Việt', 'ar': 'العربية'}[locale])
    assert values(prefs())['appLocale'] == locale


before = prefs()
baseline = values(before)
assert baseline['appLocale'] == 'en'
results = []
try:
    root_settings()
    for locale in args.locales:
        choose(locale)
        strings = arb(locale)
        expected = baseline.copy(); expected['appLocale'] = locale
        assert values(prefs()) == expected
        q.click(strings['recordingSettings'])
        q.adb('shell', 'input', 'swipe', '550', '1800', '550', '850', '400')
        _, nodes = q.tree()
        labels = q.labels(nodes)
        assert any(strings['recordingSettings'] in label for label in labels)
        assert not any('Audio & Video Settings' in label for label in labels)
        if args.core_labels:
            for key in ['autoSensor', 'mixedStream', 'mute', 'off']:
                assert any(strings[key] in label for label in labels), key
        sliders = [n for n in nodes if n.get('class') == 'android.widget.SeekBar']
        assert len(sliders) == 2, [(n.get('text'), n.get('content-desc')) for n in sliders]
        unit = strings['accessibilityValue40'].replace('{value1}', '').strip()
        for slider in sliders:
            assert unit in (slider.get('text', '') + ' ' + slider.get('content-desc', ''))
        if not args.guide_only:
            q.save('recording_title_gain' + args.attempt + '_' + locale)
        if args.notices:
            assert any(strings['captureProtectedAudioNotice'] in label for label in labels)
            assert any(strings['captureUnsupportedDevice'] in label for label in labels)
            q.adb('shell', 'input', 'swipe', '550', '1800', '550', '1300', '300')
            q.click(strings['captureTouchGuidance'])
            guide = q.labels(q.tree()[1])
            assert any(strings['captureTouchGuidanceBody'] in label for label in guide)
            assert strings['captureTouchGuidance'] in guide and 'Show touches' not in guide
            q.save('recording_touch_guide' + args.attempt + '_' + locale)
            q.click(strings['close'])
        if args.notices and not args.guide_only:
            assert any(strings['captureNoLimit'] in label for label in q.labels(q.tree()[1]))
            q.click(strings['captureAutoStop'])
            _, dialog = q.tree()
            assert any(strings['captureDurationHint'] in label for label in q.labels(dialog))
            field = next(n for n in dialog if n.get('class') == 'android.widget.EditText')
            assert field.get('text') == '0', 'Preserve any unexpected existing duration'
            x1, y1, x2, y2 = map(int, re.findall(r'\d+', field.get('bounds')))
            q.tap((x1+x2)//2, (y1+y2)//2)
            q.adb('shell', 'input', 'keyevent', 'KEYCODE_MOVE_END')
            q.adb('shell', 'input', 'keyevent', 'KEYCODE_DEL')
            q.adb('shell', 'input', 'text', '86401')
            q.click(strings['save'])
            assert any(strings['captureDurationInvalid'] in label for label in q.labels(q.tree()[1]))
            q.save('recording_duration_error' + args.attempt + '_' + locale)
            q.click(strings['cancel'])
            assert values(prefs()) == expected
        q.adb('shell', 'input', 'keyevent', '4')
        assert values(prefs()) == expected
        assert any(strings['appLanguage'] in label for label in q.labels(q.tree()[1]))
        results.append({'locale': locale, 'localizedTitle': True, 'gainSliders': 2,
                        'spokenUnitLocalized': True, 'backPreservesCanonicalSettings': True,
                        'noticeHelpChecked': args.notices,
                        'invalidDurationChecked': args.notices and not args.guide_only})
        print(json.dumps(results[-1]), flush=True)
finally:
    if values(prefs())['appLocale'] != 'en':
        root_settings()
        choose('en')
    assert prefs() == before
    with (q.ROOT / ('recording_title_gain_runtime' + args.attempt + '.json')).open('x') as out:
        json.dump({'results': results, 'preferencesByteExactAfterRestore': True,
                   'scope': 'Real page/AX labels and Back; not TalkBack or linguistic acceptance'}, out, indent=2)
assert len(results) == len(args.locales)
