"""Check packaged assets and native alignment: python tool/verify_release.py APK."""
import struct
import sys
import zipfile
from pathlib import Path

apk = Path(sys.argv[1])
failures = []
with zipfile.ZipFile(apk) as archive, apk.open('rb') as source:
    names = archive.namelist()
    if any('/assets/media/' in name for name in names):
        failures.append('Reference/sample media is packaged')
    for asset in ('assets/fonts/OFL.txt', 'assets/licenses/Media3-APACHE-2.0.txt',
                  'assets/licenses/CheckerFramework-LICENSE.txt',
                  'assets/licenses/ANDROID_DEPENDENCIES.txt'):
        if 'assets/flutter_assets/' + asset not in names:
            failures.append('Missing license: ' + asset)
    for item in archive.infolist():
        if not item.filename.endswith('.so'):
            continue
        data = archive.read(item)
        if data[:4] != b'\x7fELF':
            failures.append('Invalid ELF: ' + item.filename)
            continue
        endian = '<' if data[5] == 1 else '>'
        is64 = data[4] == 2
        offset = struct.unpack_from(endian + ('Q' if is64 else 'I'), data, 32 if is64 else 28)[0]
        size, count = struct.unpack_from(endian + 'HH', data, 54 if is64 else 42)
        alignments = []
        for i in range(count):
            header = offset + size * i
            if struct.unpack_from(endian + 'I', data, header)[0] == 1:
                alignment = struct.unpack_from(endian + ('Q' if is64 else 'I'), data, header + (48 if is64 else 28))[0]
                alignments.append(alignment)
                if is64 and alignment < 16384:
                    failures.append('64-bit ELF segment alignment: ' + item.filename)
        if item.compress_type == zipfile.ZIP_STORED:
            source.seek(item.header_offset + 26)
            name_length, extra_length = struct.unpack('<HH', source.read(4))
            start = item.header_offset + 30 + name_length + extra_length
            if is64 and start % 16384:
                failures.append('64-bit ZIP alignment: ' + item.filename)
        print(f'{item.filename}: ELF LOAD alignments {alignments}')
if failures:
    raise SystemExit('\n'.join(failures))
print('Packaged assets and 64-bit 16 KB alignment checks passed. Device testing is still required.')
