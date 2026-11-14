import json
from pathlib import Path

copy = {
    'en': 'Drag across the photo to size and place the sticker.',
    'vi': 'Kéo trên ảnh để đặt và chỉnh kích thước sticker.',
    'de': 'Ziehe über das Foto, um den Sticker zu platzieren und seine Größe festzulegen.',
    'es': 'Arrastra sobre la foto para colocar la pegatina y ajustar su tamaño.',
    'fr': 'Faites glisser sur la photo pour placer l’autocollant et définir sa taille.',
    'pt_BR': 'Arraste sobre a foto para posicionar o adesivo e definir o tamanho.',
    'id': 'Seret pada foto untuk menempatkan stiker dan mengatur ukurannya.',
    'ja': '写真上をドラッグしてステッカーの位置とサイズを指定します。',
    'ko': '사진 위를 드래그해 스티커의 위치와 크기를 정하세요.',
    'zh_Hans': '在照片上拖动以放置贴纸并调整大小。',
    'hi': 'स्टिकर रखने और उसका आकार तय करने के लिए फ़ोटो पर खींचें।',
    'ar': 'اسحب على الصورة لتحديد موضع الملصق وحجمه.',
}
copy['pt'] = copy['pt_BR']
copy['zh'] = copy['zh_Hans']
for locale, value in copy.items():
    path = Path(f'lib/l10n/app_{locale}.arb')
    text = path.read_text(encoding='utf8')
    assert 'photoDragSticker' not in json.loads(text)
    added = {'photoDragSticker': value}
    if locale == 'en':
        added['@photoDragSticker'] = {'description': 'Photo editor instruction for a colored vector sticker. Drag sets its bounds; source is unchanged.'}
    path.write_text(text.rstrip()[:-1].rstrip() + ',' + json.dumps(added, ensure_ascii=False, indent=2)[1:-1] + '\n}\n', encoding='utf8')
print('Added1photo sticker instruction to14ARBs; existing star/heart labels reused.')
