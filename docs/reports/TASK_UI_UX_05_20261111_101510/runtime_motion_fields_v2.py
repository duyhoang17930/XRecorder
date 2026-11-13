"""Read SDK objects without a compiler or application mutation."""
from pathlib import Path
exec((Path(__file__).with_name('verify_runtime_motion.py')).read_text().split('original=')[0])
lib=rpc('getObject',isolateId=isolate,objectId=library)
cls=next(x['id'] for x in lib['classes'] if x['name']=='PlatformDispatcher')
c=rpc('getObject',isolateId=isolate,objectId=cls)
static=next(x['id'] for x in c['fields'] if x['name']=='_instance')
def object_field(ref,name):
    obj=rpc('getObject',isolateId=isolate,objectId=ref['id'])
    return next(x['value'] for x in obj['fields'] if x['decl']['name']==name)
original=q.adb('shell','settings','get','global','transition_animation_scale').decode().strip()
results=[]
try:
    for value in ['0','1']:
        q.adb('shell','settings','put','global','transition_animation_scale',value);time.sleep(.8)
        dispatcher=rpc('getObject',isolateId=isolate,objectId=static)['staticValue']
        configuration=object_field(dispatcher,'_configuration')
        features=object_field(configuration,'accessibilityFeatures')
        bits=int(object_field(features,'_index')['valueAsString'])
        reduced=bool(bits&4)
        results.append({'transition_animation_scale':value,'featuresBits':bits,'disableAnimations':reduced})
        assert reduced==(value=='0'),results
finally:
    q.adb('shell','settings','delete','global','transition_animation_scale') if original=='null' else q.adb('shell','settings','put','global','transition_animation_scale',original)
    with (q.ROOT/'runtime_reduce_motion_fields_v2.json').open('x',encoding='utf8') as f:json.dump({'results':results,'restored':original,'source':'SDK dart:ui AccessibilityFeatures._kDisableAnimationsIndex == 1 << 2'},f,indent=2)
print('Flutter runtime disableAnimations toggled true/false; original restored.')
