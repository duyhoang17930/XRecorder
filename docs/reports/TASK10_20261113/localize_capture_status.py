"""Complete the reproduced root recorder/status localization gaps, preserving metadata values."""
import json
from pathlib import Path

keys = 'captureReady captureRecorderTitle capturePreparing captureAllowScreen captureStarting captureStopping captureError captureAllowScreenshot captureSavingScreenshot captureCapturingScreenshot captureStartsIn captureScreenshotIn'.split()
values = {
'en': 'Ready|Screen recorder|Preparing|Allow screen capture|Starting|Stopping|Error|Allow screenshot|Saving screenshot|Capturing screenshot|Starting in {seconds}s|Screenshot in {seconds}s',
'vi': 'Sẵn sàng|Quay màn hình|Đang chuẩn bị|Cho phép quay màn hình|Đang bắt đầu|Đang dừng|Lỗi|Cho phép chụp màn hình|Đang lưu ảnh chụp|Đang chụp màn hình|Bắt đầu sau {seconds} giây|Chụp sau {seconds} giây',
'de': 'Bereit|Bildschirmaufnahme|Vorbereitung|Bildschirmaufnahme erlauben|Wird gestartet|Wird gestoppt|Fehler|Screenshot erlauben|Screenshot wird gespeichert|Screenshot wird aufgenommen|Start in {seconds} s|Screenshot in {seconds} s',
'es': 'Listo|Grabador de pantalla|Preparando|Permitir captura de pantalla|Iniciando|Deteniendo|Error|Permitir captura de imagen|Guardando captura|Capturando pantalla|Inicio en {seconds} s|Captura en {seconds} s',
'fr': 'Prêt|Enregistreur d’écran|Préparation|Autoriser la capture d’écran|Démarrage|Arrêt en cours|Erreur|Autoriser la capture d’image|Enregistrement de la capture|Capture d’écran en cours|Démarrage dans {seconds} s|Capture dans {seconds} s',
'pt_BR': 'Pronto|Gravador de tela|Preparando|Permitir captura da tela|Iniciando|Parando|Erro|Permitir captura de imagem|Salvando captura|Capturando tela|Início em {seconds} s|Captura em {seconds} s',
'id': 'Siap|Perekam layar|Menyiapkan|Izinkan perekaman layar|Memulai|Menghentikan|Kesalahan|Izinkan tangkapan layar|Menyimpan tangkapan layar|Mengambil tangkapan layar|Mulai dalam {seconds} dtk|Tangkapan dalam {seconds} dtk',
'ja': '準備完了|画面レコーダー|準備中|画面録画を許可|開始中|停止中|エラー|スクリーンショットを許可|スクリーンショットを保存中|スクリーンショットを撮影中|{seconds}秒後に開始|{seconds}秒後に撮影',
'ko': '준비됨|화면 녹화|준비 중|화면 녹화 허용|시작 중|중지 중|오류|스크린샷 허용|스크린샷 저장 중|스크린샷 촬영 중|{seconds}초 후 시작|{seconds}초 후 촬영',
'zh_Hans': '准备就绪|屏幕录制|正在准备|允许录屏|正在开始|正在停止|错误|允许截图|正在保存截图|正在截图|{seconds}秒后开始|{seconds}秒后截图',
'hi': 'तैयार|स्क्रीन रिकॉर्डर|तैयारी हो रही है|स्क्रीन रिकॉर्डिंग की अनुमति दें|शुरू हो रहा है|रुक रहा है|त्रुटि|स्क्रीनशॉट की अनुमति दें|स्क्रीनशॉट सहेजा जा रहा है|स्क्रीनशॉट लिया जा रहा है|{seconds} सेकंड में शुरू|{seconds} सेकंड में स्क्रीनशॉट',
'ar': 'جاهز|مسجل الشاشة|جارٍ التحضير|السماح بتسجيل الشاشة|جارٍ البدء|جارٍ الإيقاف|خطأ|السماح بلقطة الشاشة|جارٍ حفظ لقطة الشاشة|جارٍ التقاط الشاشة|البدء خلال {seconds} ث|لقطة الشاشة خلال {seconds} ث',
}
values['pt'] = values['pt_BR']
values['zh'] = values['zh_Hans']
for locale, text in values.items():
    entries = text.split('|'); assert len(entries) == len(keys)
    path = Path(f'lib/l10n/app_{locale}.arb'); original = path.read_text(encoding='utf8'); data = json.loads(original)
    added = {}
    for key, value in zip(keys, entries):
        assert key not in data
        added[key] = value
        # ICU metadata for placeholders belongs to every locale.
        meta = {'description': 'Root recording status or countdown. No persisted settings values change.'}
        if '{seconds}' in value: meta['placeholders'] = {'seconds': {'type': 'int'}}
        if locale == 'en' or '{seconds}' in value: added['@' + key] = meta
    path.write_text(original.rstrip()[:-1].rstrip() + ',' + json.dumps(added,ensure_ascii=False,indent=2)[1:-1] + '\n}\n',encoding='utf8')
p = Path('lib/l10n/message_catalog.dart'); text = p.read_text(encoding='utf8')
arms = ''.join(f'  {json.dumps(v,ensure_ascii=False)} => l10n.{k},\n' for k,v in zip(keys[:10],values['en'].split('|')[:10]))
text = text.replace(') => switch (source) {\n', ') => switch (source) {\n' + arms, 1)
text = text.replace('  _ => source,', '''  final text when RegExp(r'^Starting in [0-9]+s$').hasMatch(text) => l10n.captureStartsIn(int.parse(text.substring(12, text.length - 1))),
  final text when RegExp(r'^Screenshot in [0-9]+s$').hasMatch(text) => l10n.captureScreenshotIn(int.parse(text.substring(14, text.length - 1))),
  _ => source,''')
p.write_text(text,encoding='utf8')
print('Added12 root/status messages in14 ARBs; countdown metadata and stored selections preserved.')
