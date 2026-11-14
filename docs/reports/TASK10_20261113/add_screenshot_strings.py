"""Add configurable screenshot delay copy, preserving existing ARB text."""
import json
from pathlib import Path

keys = ['screenshotDelay', 'screenshotDelaySummary', 'screenshotWithDelay']
labels = {
    'en': ['Screenshot delay', 'Screenshot minimizes the app after approval · {seconds}s delay.', 'Screenshot · {seconds}s delay'],
    'vi': ['Độ trễ chụp màn hình', 'Ứng dụng thu nhỏ sau khi được cho phép · chụp sau {seconds} giây.', 'Chụp màn hình · sau {seconds} giây'],
    'es': ['Retardo de captura', 'La app se minimiza tras el permiso · captura en {seconds} s.', 'Captura · retardo de {seconds} s'],
    'pt_BR': ['Atraso da captura', 'O app é minimizado após a permissão · captura em {seconds} s.', 'Captura · atraso de {seconds} s'],
    'fr': ['Délai de capture', 'L’application se réduit après autorisation · capture dans {seconds} s.', 'Capture · délai de {seconds} s'],
    'de': ['Screenshot-Verzögerung', 'Die App wird nach der Zustimmung minimiert · Screenshot nach {seconds} s.', 'Screenshot · nach {seconds} s'],
    'id': ['Jeda tangkapan layar', 'Aplikasi diminimalkan setelah izin · tangkapan setelah {seconds} dtk.', 'Tangkapan layar · jeda {seconds} dtk'],
    'ja': ['スクリーンショットの待ち時間', '許可後にアプリが最小化されます · {seconds}秒後に撮影。', 'スクリーンショット · {seconds}秒後'],
    'ko': ['스크린샷 지연', '권한 허용 후 앱이 최소화됩니다 · {seconds}초 후 촬영.', '스크린샷 · {seconds}초 후'],
    'zh_Hans': ['截图延迟', '授权后应用将最小化 · {seconds}秒后截图。', '截图 · 延迟{seconds}秒'],
    'hi': ['स्क्रीनशॉट में देरी', 'अनुमति के बाद ऐप छोटा होता है · {seconds} सेकंड बाद स्क्रीनशॉट।', 'स्क्रीनशॉट · {seconds} सेकंड बाद'],
    'ar': ['تأخير لقطة الشاشة', 'يُصغّر التطبيق بعد الموافقة · تُلتقط الشاشة بعد {seconds} ثانية.', 'لقطة شاشة · بعد {seconds} ثانية'],
}
labels['pt'] = labels['pt_BR']; labels['zh'] = labels['zh_Hans']
for locale, values in labels.items():
    path = Path('lib/l10n') / f'app_{locale}.arb'
    text = path.read_text(encoding='utf8'); previous = json.loads(text); additions = {}
    for key, value in zip(keys, values):
        if key in previous:
            assert previous[key] == value
            continue
        additions[key] = value
        if locale == 'en':
            metadata = {'description': 'Screenshot delay preference or action label.'}
            if '{seconds}' in value: metadata['placeholders'] = {'seconds': {'type': 'String'}}
            additions['@' + key] = metadata
    if additions:
        path.write_text(text.rstrip()[:-1].rstrip() + ',' + json.dumps(additions, ensure_ascii=False, indent=2)[1:] + '\n', encoding='utf8')
