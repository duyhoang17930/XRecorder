"""Structural/heuristic inventory of every ARB. Never grades linguistic quality."""
from pathlib import Path
import json,re,subprocess

root=Path.cwd();out=Path(__file__).parent
en=json.loads((root/'lib/l10n/app_en.arb').read_text(encoding='utf8'))
keys={k for k in en if not k.startswith('@')}
catalog=[];matrix=[]
proper=re.compile(r'^(?:[\d\s.,/×%+·°–\-]+|AndroidX|JSpecify|Guava|Kotlin|RNNoise|ReLinker|(?:H\.[\d]+.*)|(?:\d+[pK].*)|(?:\d+ Mbps)|[KMGT]iB|Lucide.*|Manrope.*)$')
for p in sorted((root/'lib/l10n').glob('app_*.arb')):
    data=json.loads(p.read_text(encoding='utf8'));tag=p.stem[4:]
    old=json.loads(subprocess.check_output(['git','show','HEAD:lib/l10n/'+p.name]).decode('utf8'))
    entries=[];structural=[]
    if {k for k in data if not k.startswith('@')}!=keys:structural.append('key-set-mismatch')
    for k in sorted(keys):
        text=data.get(k,'');source=en[k];flags=[]
        expected=set(re.findall(r'\{([A-Za-z][A-Za-z0-9]*)\s*[,}]',source))
        actual=set(re.findall(r'\{([A-Za-z][A-Za-z0-9]*)\s*[,}]',text))
        if expected!=actual:structural.append(k+':placeholder-mismatch')
        if '\ufffd' in text:structural.append(k+':replacement-character')
        if tag!='en' and text==source and len(source)>7 and not proper.fullmatch(source) and not k.startswith('speechLanguage'):
            flags.append('same-as-English-review-context')
        if len(text)>max(180,len(source)*2.5):flags.append('overlong-review')
        if '⁇' in text:flags.append('suspicious-question-mark')
        if re.search(r'(.{30,100})(?:\s*[-.;]?\s*\1){2}',text,re.I):flags.append('repeated-clause')
        if tag not in ['en'] and re.search(r'\b(?:Originals Unchanged|Export Queue|Save a copy|Lời bài hát)\b',text,re.I):flags.append('mixed-or-injected-copy')
        entries.append({'key':k,'source':source,'translation':text,'flags':flags,'changedFromHead':text!=old.get(k)})
    if tag=='ar':
        for k in ['itemCount','clipCount','segmentCount']:
            for c in ['zero','one','two','few','many','other']:
                if c+'{' not in data[k]:structural.append(k+':missing-plural-'+c)
    matrix.append({'locale':tag,'keys':len(keys),'changed':sum(e['changedFromHead'] for e in entries),'flagged':sum(bool(e['flags']) for e in entries),'structuralErrors':structural,'linguisticAcceptance':'NATIVE_SPEAKER_REVIEW_REQUIRED'})
    catalog.append({'locale':tag,'entries':entries})
with (out/'localization_review_catalog.json').open('x',encoding='utf8') as f:json.dump(catalog,f,ensure_ascii=False,indent=2)
with (out/'localization_review_matrix.json').open('x',encoding='utf8') as f:json.dump(matrix,f,ensure_ascii=False,indent=2)
hardcoded=[]
for p in (root/'lib').rglob('*.dart'):
    if 'generated' in p.parts or p.name=='message_catalog.dart':continue
    for line,text in enumerate(p.read_text(encoding='utf8').splitlines(),1):
        if re.search(r"(?:\bText\(|\blabel:\s*)['\"][A-Za-z][A-Za-z &,:/?.-]{3,}['\"]",text):
            hardcoded.append({'path':str(p.relative_to(root)),'line':line,'source':text.strip(),'requiresContextReview':True})
with (out/'hardcoded_ui_review.json').open('x',encoding='utf8') as f:json.dump(hardcoded,f,ensure_ascii=False,indent=2)
print(json.dumps(matrix))
assert not any(row['structuralErrors'] for row in matrix)
