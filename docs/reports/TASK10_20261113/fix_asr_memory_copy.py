from pathlib import Path
import json,re
copy={"en":"Not enough memory. Close other apps and try a shorter video.","vi":"Không đủ bộ nhớ. Đóng ứng dụng khác và thử video ngắn hơn.","de":"Nicht genug Arbeitsspeicher. Schließe andere Apps und versuche ein kürzeres Video.","es":"No hay suficiente memoria. Cierra otras aplicaciones y prueba con un vídeo más corto.","fr":"Mémoire insuffisante. Fermez les autres applications et essayez une vidéo plus courte.","pt":"Memória insuficiente. Feche outros aplicativos e tente um vídeo mais curto.","pt_BR":"Memória insuficiente. Feche outros aplicativos e tente um vídeo mais curto.","id":"Memori tidak cukup. Tutup aplikasi lain dan coba video yang lebih pendek.","ja":"メモリが不足しています。他のアプリを閉じて、より短い動画でお試しください。","ko":"메모리가 부족합니다. 다른 앱을 닫고 더 짧은 동영상으로 다시 시도하세요.","zh":"内存不足。请关闭其他应用，然后尝试较短的视频。","zh_Hans":"内存不足。请关闭其他应用，然后尝试较短的视频。","ar":"الذاكرة غير كافية. أغلق التطبيقات الأخرى وجرّب فيديو أقصر.","hi":"पर्याप्त मेमोरी नहीं है। अन्य ऐप बंद करें और छोटा वीडियो आज़माएँ।"}
for locale,value in copy.items():
 p=Path('lib/l10n/app_'+locale+'.arb')
 s=p.read_text(encoding='utf8')
 s,n=re.subn(r'(\"speechLowMemory\": )\"[^\"\n]*\"',lambda m:m.group(1)+json.dumps(value,ensure_ascii=False),s)
 assert n==1,locale
 p.write_text(s,encoding='utf8')
print('Updated low-memory guidance in 14 ARBs; no resource keys or stored values changed.')
