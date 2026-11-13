from qa06_interactions import *
def canvas():
    candidates=[bounds(n) for n in q.nodes() if n.get('class')=='android.view.View' and n.get('scrollable')=='true']
    return max((b for b in candidates if b[1]>100 and b[3]<650),key=lambda b:(b[2]-b[0])*(b[3]-b[1]))
def point(b,x,y):return (round(b[0]+(b[2]-b[0])*x),round(b[1]+(b[3]-b[1])*y))
def drag(a,b):q.adb('shell','input','swipe',str(a[0]),str(a[1]),str(b[0]),str(b[1]),'450')
try:
    q.click('Edit');q.click('Edit');q.click('Edit photo');q.click('Edited_1794327406739.png')
    with Video('UI06_acceptance_eraser_roundtrip'):
        tool('Shapes');q.click('Rectangle');b=canvas();drag(point(b,.2,.25),point(b,.75,.65))
        q.shot('acceptance_eraser_before')
        tool('Drawing');q.click('Eraser');b=canvas();drag(point(b,.2,.25),point(b,.23,.28))
        q.shot('acceptance_eraser_after')
        q.click('Undo photo edit');q.click('Redo photo edit')
        q.back();labels=q.labels();assert 'Discard photo edits?' not in labels and 'Create' in labels,labels
        event('single-shape-erased-undo-redo-back-clean')
    q.click('Settings');q.click('Settings')
finally:q.restore();q.save_events('acceptance_eraser_roundtrip')
