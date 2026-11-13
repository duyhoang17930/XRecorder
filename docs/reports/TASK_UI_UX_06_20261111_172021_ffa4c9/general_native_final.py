from qa06_interactions import *
try:
    # Enter from the root after the isolated photo/video runs.
    for _ in range(5):
        if all(t in q.labels() for t in ['Video','Photo','Settings']):break
        q.back()
    with Video('UI06_final_general_workflow_v3'):
        for tab in ['Video','Photo','Edit','Settings']:
            q.click(tab);q.click(tab)
            q.shot('final_v3_header_'+tab.lower())
            nodes=q.nodes()
            brand=next(n for n in nodes if (n.get('content-desc') or n.get('text','')).splitlines()[:1]==['3HRECORDER'])
            q.EVENTS.append({'case':'root-header','tab':tab,'brandBounds':bounds(brand)})
        create=next(n for n in q.nodes() if n.get('clickable')=='true' and n.get('content-desc')=='Create')
        b=bounds(create);x=(b[0]+b[2])//2;y=(b[1]+b[3])//2
        for count in [2,3,5]:
            for _ in range(count):
                q.adb('shell','input','tap',str(x),str(y));time.sleep(.04)
            labels=q.labels();titles=[s.splitlines()[0] for s in labels]
            assert 'Record screen' in titles and 'Screenshot' in titles and 'Editing Studio' in titles,labels
            assert 'Start Recording' not in labels
            q.EVENTS.append({'case':'rapid-create','taps':count,'sheetStable':True,'labels':labels})
            if count==5:q.shot('final_v2_create_compact')
            q.back()
        q.click('Video');q.click('Video')
        q.click('Edited_ca13829a-b90f-4ac0-96f1-8723256517db.mp4',True)
        q.shot('final_media_details_edit_video')
        before=projects();q.click('Edit video');time.sleep(.5)
        assert len(projects()-before)==1
        q.back();q.click('Edit video');time.sleep(.4)
        assert len(projects()-before)==1
        event('details-edit-video-reuses-launch-project')
        q.back();q.click('Rename',True)
        fieldnode=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
        old=fieldnode.get('text')
        q.click('Clear text');q.shot('final_rename_media_clear')
        assert not next(n for n in q.nodes() if n.get('class')=='android.widget.EditText').get('text')
        q.click('Cancel');event('rename-clear-cancel-no-submit')
        q.back();q.click('Settings');q.click('Settings')
        for _ in range(3):
            q.adb('shell','input','swipe','205','730','205','180','120')
            q.adb('shell','input','swipe','205','180','205','730','120')
        q.click('Settings');q.shot('final_settings_after_flings')
        event('settings-six-flings-no-persistent-distortion-observed')
finally:q.restore();q.save_events('general_native_final_v3')
