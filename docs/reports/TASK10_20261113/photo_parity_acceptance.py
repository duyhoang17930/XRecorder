"""Actual main editor recheck for the image-scale defect and new photo stickers.

Only screenshot91 (registered TASK10 fixture) and newly saved copies are used.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

import device_qa as q

q.identity()
source = json.loads((q.ROOT / 'photo_annotation_gate1_source.json').read_text())
assert source['uri'] == 'content://media/external/images/media/91'
assert hashlib.sha256(q.adb('exec-out', 'content', 'read', '--uri', source['uri'])).hexdigest() == source['sha256']
q.click('Photo')
for _ in range(8):
    if 'Actions for ' + source['name'] in q.labels(q.tree()[1]):
        break
    q.adb('shell', 'input', 'swipe', '550', '1800', '550', '850', '400')
q.click('Actions for ' + source['name'])
q.click('Open details')
q.click('Crop & annotate a copy')
q.save('photo_parity_fixed_open')

# Reproduce the original literal UI sequence, with the same synthetic caption.
q.adb('shell', 'input', 'swipe', '400', '650', '650', '900', '500')
q.click('Shapes')
q.click('Rectangle')
q.click('Color')
q.click('Yellow ink')
q.adb('shell', 'input', 'swipe', '450', '800', '650', '1000', '500')
q.click('Text')
_, nodes = q.tree()
field = next(n for n in nodes if n.get('hint') == 'Text to place on photo')
x, y, right, bottom = map(int, re.findall(r'\d+', field.get('bounds')))
q.tap((x + right) // 2, (y + bottom) // 2)
q.adb('shell', 'input', 'text', 'TASK10_PHOTO')
assert next(n for n in q.tree()[1] if n.get('hint') == 'Text to place on photo').get('text') == 'TASK10_PHOTO'
q.click('Apply')
q.save('photo_parity_fixed_same_caption')


def image_box(name):
    """Case-specific frame estimate, based only on unannotated sky and white frame.

    Final pixel validation must account for the known1logical-pixel crop guide.
    This estimate never fits annotation pixels or changes a saved artifact.
    """
    data = subprocess.check_output(['build/task03/ffmpeg/ffmpeg.exe', '-v', 'error', '-i',
        str(q.ROOT / (name + '.png')), '-frames:v', '1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
    width, height = 1080, 2400
    assert len(data) == width * height * 3
    def white(x, y):
        i = (y * width + x) * 3
        return min(data[i:i+3]) > 248
    runs = []
    start = None
    for x in range(150, 931):
        if not white(x, 450):
            if start is None:
                start = x
        elif start is not None:
            runs.append((start, x)); start = None
    if start is not None:
        runs.append((start, 931))
    left, right = max(runs, key=lambda v: v[1] - v[0])
    assert 350 < right - left < 800
    # Restore the white half-stroke cropped from each side by the sky detector.
    left -= 1; right += 1
    top = next(y for y in range(340, 401) if not white(540, y) and all(white(540, k) for k in range(y-8, y))) - 1
    image_width = right - left
    image_height = round(image_width * 2048 / 922)
    return [left, top, image_width, image_height]


def drag(box, start, end):
    x, y, width, height = box
    values = [round(x + start[0] * width), round(y + start[1] * height),
              round(x + end[0] * width), round(y + end[1] * height)]
    q.adb('shell', 'input', 'swipe', *map(str, values), '500')


q.click('All tools')
q.click('Star')
q.save('photo_parity_fixed_star_mode')
star_box = image_box('photo_parity_fixed_star_mode')
drag(star_box, (.08, .18), (.36, .31))
q.save('photo_parity_fixed_star')
q.click('Sticker')
q.click('Heart')
q.click('Color')
q.click('Cyan ink')
q.save('photo_parity_fixed_heart_mode')
heart_box = image_box('photo_parity_fixed_heart_mode')
drag(heart_box, (.10, .54), (.28, .64))
q.save('photo_parity_fixed_heart')
q.click('Undo photo edit')
q.save('photo_parity_fixed_heart_undo')
q.click('Redo photo edit')
q.save('photo_parity_fixed_before_save')
final_box = image_box('photo_parity_fixed_before_save')
q.click('Save copy')
labels = q.save('photo_parity_fixed_saved')
name = next(label for label in labels if re.fullmatch(r'Edited_[0-9]+\.png', label))
rows = q.adb('shell', 'content', 'query', '--uri', 'content://media/external/images/media',
             '--projection', '_id:_display_name:owner_package_name:_size').decode().splitlines()
row = next(r for r in rows if '_display_name=' + name + ',' in r)
assert q.PACKAGE in row
uri = 'content://media/external/images/media/' + re.search(r'_id=(\d+)', row).group(1)
data = q.adb('exec-out', 'content', 'read', '--uri', uri)
with (q.ROOT / 'photo_parity_fixed.png').open('xb') as out:
    out.write(data)
registry = json.loads((q.ROOT / 'task_created_media.json').read_text())
registry.append({'uri': uri, 'case': 'photo_stickers_and_parity', 'source': source['uri'],
                 'evidence': 'photo_parity_fixed_ui_result.json'})
(q.ROOT / 'task_created_media.json').write_text(json.dumps(registry, indent=2))
assert hashlib.sha256(q.adb('exec-out', 'content', 'read', '--uri', source['uri'])).hexdigest() == source['sha256']
result = {'uiStatus': 'PASS', 'outputPixels': 'PENDING_VALIDATION', 'uri': uri, 'name': name,
          'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'sourceByteExact': True,
          'sameCaption': 'TASK10_PHOTO', 'starInk': 'Yellow', 'heartInk': 'Cyan',
          'heartUndoRedoExercised': True, 'estimatedFinalImageBox': final_box,
          'starModeImageBox': star_box, 'heartModeImageBox': heart_box,
          'apkIdentity': 'photo_parity_profile_install.json'}
with (q.ROOT / 'photo_parity_fixed_ui_result.json').open('x') as out:
    json.dump(result, out, indent=2)
print(json.dumps(result), flush=True)
