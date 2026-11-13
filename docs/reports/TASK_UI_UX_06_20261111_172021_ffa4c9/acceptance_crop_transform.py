from qa06_interactions import *
try:
    q.click('Edit');q.click('Edit');q.click('Edit photo');q.click('Edited_1794327406739.png')
    with Video('UI06_acceptance_crop_transform'):
        tool('Crop')
        sliders=[n for n in q.nodes() if n.get('class')=='android.widget.SeekBar'];assert len(sliders)==4
        b=bounds(sliders[1]);x=(b[0]+b[2])//2;y=(b[1]+b[3])//2
        q.adb('shell','input','swipe',str(x),str(y),str(x-35),str(y),'350')
        tool('Transform');panel('Rotate 90°')
        q.rotate(1);q.labels();q.shot('acceptance_photo_crop_transform_landscape');q.rotate(0)
        q.click('Save copy');assert 'Media details' in q.labels()
        event('final-apk-photo-crop-quarter-turn-save-copy')
        q.shot('acceptance_crop_saved_details');q.back()
finally:q.restore();q.save_events('acceptance_crop_transform')
