import pathlib,json,re
root=pathlib.Path(__file__).parent
def rows(names):
    return {r['scenario']:r for name in names for r in json.loads((root/name).read_text())}
before=rows(['baseline_profile_summary.json','baseline_editor_v2_editor_profile_summary.json','baseline_editor_v2_video_profile_summary.json'])
after=rows(['after_profile_summary.json','after_editor_profile_summary.json','after_video_profile_summary.json'])
comparisons=[]
for name,old in before.items():
    current=after[name]
    comparisons.append({'scenario':name,'before':{'build':old['build'],'raster':old['raster']},'after':{'build':current['build'],'raster':current['raster']}})
memory={}
for label,file in [('baseline','baseline_editor_v2_mem_after.txt'),('after','after_mem_after.txt')]:
    text=(root/file).read_text();memory[label]={key:int(re.search(key+r':\s+(\d+)',text)[1]) for key in ['TOTAL PSS','TOTAL RSS']}
report={'comparisons':comparisons,'memoryKb':memory,'device':'ThreeHRecorder_TASK09B_API36, SwiftShader, 411x920/160dpi, Light/English/font1.0','measurementRevision':'UI06 presentation candidate before final Studio route and accessibility lifecycle fixes. Final debug/profile rebuilt and functionally retested; no equivalent final frame benchmark after those fixes.','datasetDifference':'App media remained the same before these samples; one UI06 QA draft had been added to Studio. Root-tab comparison is not a perfectly identical data set. Editor benchmarks use the same retained image URI and unchanged UI04 SAF project.','limitations':['Build/raster trace durations, not presented-frame counts or certified FPS.','Rotation has only6–8 frame samples; no performance PASS from that sample.','Later session resumed with a personal emulator also running; no control or benchmarking on that device.','No authorized hardware-GPU/physical-device acceptance; overall performance PARTIAL.']}
with (root/'performance_comparison.json').open('x',encoding='utf8') as f:json.dump(report,f,indent=2)
for row in comparisons:
    print(row['scenario'],row['before']['build']['p90Ms'],row['after']['build']['p90Ms'],row['before']['raster']['p90Ms'],row['after']['raster']['p90Ms'])
print(memory)
