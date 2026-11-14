"""Add bounded TASK10 region labels without altering existing translated values."""
import json
from pathlib import Path

keys = ['regionCapture', 'regionCaptureHint', 'regionWidth', 'regionHeight', 'regionUnavailable']
values = {
    'en': ['Record region', 'Adjust the highlighted area. After approval, the app minimizes and records that part of the screen. Rotation stops and saves the recording.', 'Width', 'Height', 'Screen dimensions are unavailable. Go back and try again.'],
    'vi': ['Quay một vùng', 'Điều chỉnh vùng được tô sáng. Sau khi được cho phép, ứng dụng thu nhỏ và quay vùng đó trên màn hình. Xoay màn hình sẽ dừng và lưu video.', 'Chiều rộng', 'Chiều cao', 'Không lấy được kích thước màn hình. Hãy quay lại và thử lại.'],
    'es': ['Grabar una zona', 'Ajusta la zona resaltada. Tras el permiso, la app se minimiza y graba esa parte de la pantalla. Al girar, se detiene y guarda la grabación.', 'Ancho', 'Alto', 'No se puede obtener el tamaño de la pantalla. Vuelve atrás e inténtalo de nuevo.'],
    'pt_BR': ['Gravar uma área', 'Ajuste a área destacada. Após a permissão, o app é minimizado e grava essa parte da tela. Girar a tela encerra e salva a gravação.', 'Largura', 'Altura', 'As dimensões da tela não estão disponíveis. Volte e tente novamente.'],
    'fr': ['Enregistrer une zone', 'Ajustez la zone en surbrillance. Après autorisation, l’application se réduit et enregistre cette partie de l’écran. La rotation arrête et sauvegarde l’enregistrement.', 'Largeur', 'Hauteur', 'Les dimensions de l’écran sont indisponibles. Revenez en arrière et réessayez.'],
    'de': ['Bereich aufnehmen', 'Passe den markierten Bereich an. Nach der Zustimmung wird die App minimiert und nimmt diesen Bildschirmbereich auf. Drehen beendet und speichert die Aufnahme.', 'Breite', 'Höhe', 'Die Bildschirmgröße ist nicht verfügbar. Gehe zurück und versuche es erneut.'],
    'id': ['Rekam area', 'Sesuaikan area yang disorot. Setelah izin diberikan, aplikasi diminimalkan dan merekam bagian layar tersebut. Rotasi menghentikan dan menyimpan rekaman.', 'Lebar', 'Tinggi', 'Ukuran layar tidak tersedia. Kembali dan coba lagi.'],
    'ja': ['範囲を録画', '強調表示された範囲を調整します。許可後、アプリが最小化され、その範囲を録画します。画面を回転すると録画を停止して保存します。', '幅', '高さ', '画面サイズを取得できません。戻って再試行してください。'],
    'ko': ['영역 녹화', '강조된 영역을 조정하세요. 권한을 허용하면 앱이 최소화되고 해당 화면 영역이 녹화됩니다. 화면을 회전하면 녹화가 중지되고 저장됩니다.', '너비', '높이', '화면 크기를 가져올 수 없습니다. 뒤로 가서 다시 시도하세요.'],
    'zh_Hans': ['区域录屏', '调整高亮区域。授权后，应用将最小化并录制该屏幕区域。旋转屏幕会停止并保存录制。', '宽度', '高度', '无法获取屏幕尺寸。请返回后重试。'],
    'hi': ['क्षेत्र रिकॉर्ड करें', 'हाइलाइट किए गए क्षेत्र को समायोजित करें। अनुमति के बाद ऐप छोटा होकर स्क्रीन का वही हिस्सा रिकॉर्ड करता है। स्क्रीन घुमाने पर रिकॉर्डिंग रुककर सहेज दी जाती है।', 'चौड़ाई', 'ऊँचाई', 'स्क्रीन का आकार उपलब्ध नहीं है। वापस जाकर फिर कोशिश करें।'],
    'ar': ['تسجيل منطقة', 'اضبط المنطقة المحددة. بعد الموافقة، يُصغّر التطبيق ويسجّل ذلك الجزء من الشاشة. يؤدي تدوير الشاشة إلى إيقاف التسجيل وحفظه.', 'العرض', 'الارتفاع', 'أبعاد الشاشة غير متاحة. ارجع وحاول مرة أخرى.'],
}
for alias, origin in [('pt', 'pt_BR'), ('zh', 'zh_Hans')]:
    values[alias] = values[origin]
for locale, labels in values.items():
    path = Path('lib/l10n') / f'app_{locale}.arb'
    source = path.read_text(encoding='utf8')
    existing = json.loads(source)
    addition = {}
    for key, value in zip(keys, labels):
        if key in existing:
            assert existing[key] == value
            continue
        addition[key] = value
        if locale == 'en':
            addition['@' + key] = {'description': 'Region recording selector: ' + key + '.'}
    if addition:
        # Preserve every existing byte except the final object delimiter.
        suffix = json.dumps(addition, ensure_ascii=False, indent=2)[1:]
        path.write_text(source.rstrip()[:-1].rstrip() + ',' + suffix + '\n', encoding='utf8')
