"""Fill reproduced untranslated recording notices; preserve every existing value."""
import json
from pathlib import Path

keys = ['captureProtectedAudioNotice', 'captureUnsupportedDevice', 'captureTouchGuidance',
        'captureTouchGuidanceBody', 'captureDurationHint', 'captureDurationInvalid']
translations = {
    'en': [
        'Protected audio may be silent. Android may ask for audio access.',
        'Not supported by this device', 'Touch-indicator guidance',
        'To show taps, enable Show taps manually in Android Developer options, if available. 3HRecorder cannot observe touches in other apps. The system indicator may appear in full-screen recordings. Turn it off afterward if you no longer need it.',
        '1–86400 seconds, or 0 for no limit.', 'Enter 0–86400 seconds'],
    'vi': [
        'Âm thanh được bảo vệ có thể không thu được. Android có thể yêu cầu quyền truy cập âm thanh.',
        'Thiết bị này không hỗ trợ', 'Hướng dẫn hiển thị thao tác chạm',
        'Để hiển thị thao tác chạm, hãy tự bật Hiển thị thao tác chạm trong Tùy chọn nhà phát triển của Android, nếu có. 3HRecorder không thể theo dõi thao tác chạm trong ứng dụng khác. Chỉ báo của hệ thống có thể xuất hiện trong bản quay toàn màn hình. Hãy tắt sau khi không còn cần dùng.',
        '1–86400 giây, hoặc 0 để không giới hạn.', 'Nhập từ 0 đến 86400 giây'],
    'ar': [
        'قد لا يُسجَّل الصوت المحمي. قد يطلب Android إذن الوصول إلى الصوت.',
        'هذا الجهاز لا يدعم هذه الميزة', 'إرشادات إظهار اللمسات',
        'لإظهار اللمسات، فعّل خيار إظهار اللمسات يدويًا في خيارات المطوّر في Android إن كان متاحًا. لا يستطيع 3HRecorder رصد اللمسات في التطبيقات الأخرى. قد يظهر مؤشر النظام في تسجيلات الشاشة الكاملة. أوقفه بعد الانتهاء إذا لم تعد بحاجة إليه.',
        'من 1 إلى 86400 ثانية، أو 0 بلا حد.', 'أدخل مدة من 0 إلى 86400 ثانية'],
    'de': [
        'Geschütztes Audio wird möglicherweise nicht aufgenommen. Android kann nach Audiozugriff fragen.',
        'Von diesem Gerät nicht unterstützt', 'Hinweise zu Berührungsanzeigen',
        'Aktiviere Berührungen anzeigen bei Bedarf manuell in den Android-Entwickleroptionen, sofern verfügbar. 3HRecorder kann keine Berührungen in anderen Apps erfassen. Die Systemanzeige kann in Vollbildaufnahmen erscheinen. Schalte sie danach aus, wenn du sie nicht mehr benötigst.',
        '1–86400 Sekunden oder 0 für unbegrenzt.', 'Gib 0–86400 Sekunden ein'],
    'es': [
        'Es posible que el audio protegido no se grabe. Android puede solicitar acceso al audio.',
        'Este dispositivo no lo admite', 'Ayuda para mostrar toques',
        'Para mostrar los toques, activa manualmente Mostrar toques en las opciones para desarrolladores de Android, si está disponible. 3HRecorder no puede detectar toques en otras apps. El indicador del sistema puede aparecer en grabaciones de pantalla completa. Desactívalo después si ya no lo necesitas.',
        '1–86400 segundos, o 0 para no limitar.', 'Introduce entre 0 y 86400 segundos'],
    'fr': [
        'Le son protégé peut ne pas être enregistré. Android peut demander l’accès au son.',
        'Non pris en charge par cet appareil', 'Aide pour afficher les appuis',
        'Pour afficher les appuis, activez manuellement Afficher les appuis dans les options pour les développeurs Android, si disponible. 3HRecorder ne peut pas détecter les appuis dans d’autres applications. L’indicateur système peut apparaître dans les enregistrements en plein écran. Désactivez-le ensuite si vous n’en avez plus besoin.',
        '1–86400 secondes, ou 0 sans limite.', 'Saisissez entre 0 et 86400 secondes'],
    'hi': [
        'सुरक्षित ऑडियो रिकॉर्ड नहीं हो सकता है। Android ऑडियो का ऐक्सेस माँग सकता है।',
        'यह डिवाइस इस सुविधा का समर्थन नहीं करता', 'टच संकेत दिखाने की जानकारी',
        'टच दिखाने के लिए Android के डेवलपर विकल्पों में टच दिखाएँ को खुद चालू करें, अगर यह उपलब्ध हो। 3HRecorder दूसरे ऐप्लिकेशन में किए गए टच नहीं देख सकता। सिस्टम का संकेत पूरी स्क्रीन की रिकॉर्डिंग में दिख सकता है। ज़रूरत खत्म होने पर इसे बंद कर दें।',
        '1–86400 सेकंड, या कोई सीमा नहीं रखने के लिए 0।', '0–86400 सेकंड दर्ज करें'],
    'id': [
        'Audio yang dilindungi mungkin tidak terekam. Android dapat meminta akses audio.',
        'Tidak didukung oleh perangkat ini', 'Panduan indikator sentuhan',
        'Untuk menampilkan sentuhan, aktifkan Tampilkan ketukan secara manual di Opsi developer Android, jika tersedia. 3HRecorder tidak dapat mendeteksi sentuhan di aplikasi lain. Indikator sistem dapat muncul dalam rekaman layar penuh. Nonaktifkan setelah selesai jika tidak diperlukan lagi.',
        '1–86400 detik, atau 0 tanpa batas.', 'Masukkan 0–86400 detik'],
    'ja': [
        '保護された音声は録音できない場合があります。Android が音声へのアクセス許可を求めることがあります。',
        'このデバイスではサポートされていません', 'タップ表示のガイド',
        'タップを表示するには、Android の開発者向けオプションで「タップを表示」を手動で有効にしてください。利用できない場合もあります。3HRecorder は他のアプリでのタップを検出できません。システムの表示が全画面録画に映る場合があります。不要になったら無効にしてください。',
        '1～86400秒、無制限にする場合は0。', '0～86400秒を入力してください'],
    'ko': [
        '보호된 오디오는 녹음되지 않을 수 있습니다. Android에서 오디오 접근 권한을 요청할 수 있습니다.',
        '이 기기에서는 지원되지 않습니다', '탭 표시 안내',
        '탭을 표시하려면 Android 개발자 옵션에서 탭 표시를 직접 켜세요. 기기에 따라 제공되지 않을 수 있습니다. 3HRecorder는 다른 앱의 터치를 감지할 수 없습니다. 시스템 표시가 전체 화면 녹화에 포함될 수 있습니다. 더 이상 필요하지 않으면 꺼 주세요.',
        '1~86400초 또는 제한 없음은 0입니다.', '0~86400초를 입력하세요'],
    'pt': [
        'O áudio protegido pode não ser gravado. O Android pode pedir acesso ao áudio.',
        'Não suportado por este dispositivo', 'Ajuda para mostrar toques',
        'Para mostrar os toques, ative manualmente Mostrar toques nas opções de programador do Android, se disponível. O 3HRecorder não consegue detetar toques noutras aplicações. O indicador do sistema pode aparecer nas gravações de ecrã inteiro. Desative-o quando deixar de ser necessário.',
        '1–86400 segundos, ou 0 sem limite.', 'Introduza entre 0 e 86400 segundos'],
    'pt_BR': [
        'O áudio protegido pode não ser gravado. O Android pode solicitar acesso ao áudio.',
        'Não é compatível com este dispositivo', 'Ajuda para mostrar toques',
        'Para mostrar os toques, ative manualmente Mostrar toques nas opções do desenvolvedor do Android, se disponível. O 3HRecorder não consegue detectar toques em outros apps. O indicador do sistema pode aparecer em gravações de tela inteira. Desative-o quando não precisar mais dele.',
        '1–86400 segundos, ou 0 sem limite.', 'Digite entre 0 e 86400 segundos'],
    'zh': [
        '受保护的音频可能无法录制。Android 可能会请求音频访问权限。',
        '此设备不支持', '触摸指示器使用说明',
        '若要显示点按位置，请在 Android 开发者选项中手动开启“显示点按操作”（如有此选项）。3HRecorder 无法检测其他应用中的触摸操作。系统指示器可能出现在全屏录制中。不再需要时请将其关闭。',
        '1–86400 秒，输入 0 表示不限时。', '请输入 0–86400 秒'],
}
translations['zh_Hans'] = translations['zh']
for locale, values in translations.items():
    path = Path('lib/l10n/app_' + locale + '.arb')
    before = json.loads(path.read_text(encoding='utf8'))
    assert len(values) == len(keys)
    additions = dict(zip(keys, values))
    assert all(key not in before for key in additions), 'Run once; never replace existing translations'
    after = {**before, **additions}
    if locale == 'en':
        for key in keys:
            after['@' + key] = {'description': 'Recording settings notice or bounded auto-stop validation. Presentation only.'}
    assert all(after[key] == value for key, value in before.items())
    path.write_text(json.dumps(after, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
print('Added6recording notice/validation keys to14ARBs; preserved existing values')
