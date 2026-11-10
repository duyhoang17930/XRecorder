import qa03 as q,json
try:
 q.click('Rectangle')
 q.roundtrip('Photo_Editor_v4','Photo editor',True)
 selected=[n.get('content-desc') for n in q.nodes() if n.get('selected')=='true']
 q.EVENTS.append({'photoSelectedAfterRotation':selected})
 assert 'Rectangle' in selected
 q.back();q.back()
 q.click('Sort media')
 q.roundtrip('Sort_sheet','Sort media',True)
 q.back()
 q.click('Edit');q.click('New video project')
 print(q.labels(),flush=True)
finally:
 q.restore();q.save_events('orientation_editor_run4')
