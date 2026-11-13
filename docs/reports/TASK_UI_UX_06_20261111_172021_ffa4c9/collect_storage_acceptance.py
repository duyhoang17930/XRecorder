"""One final metadata walk; never follows reparse points or reads disk images."""
import os,pathlib,json,shutil,stat,sys
root=pathlib.Path.cwd();out=pathlib.Path(__file__).parent
before=json.loads((out/'baseline.json').read_text(encoding='utf8'))
def logical(directory):
    total=0;files=0;skipped=[];stack=[directory]
    while stack:
        parent=stack.pop()
        with os.scandir(parent) as entries:
            for entry in entries:
                meta=entry.stat(follow_symlinks=False)
                if entry.is_symlink() or getattr(meta,'st_file_attributes',0)&0x400:
                    skipped.append(entry.path);continue
                if stat.S_ISDIR(meta.st_mode):stack.append(entry.path)
                elif stat.S_ISREG(meta.st_mode):total+=meta.st_size;files+=1
    return {'logicalBytes':total,'files':files,'skippedReparsePoints':skipped}
build=logical(root/'build');evidence=logical(out);backups=logical(root/'build/verification/uiux06')
report={'beforeBuildBytes':before['buildBytes'],'afterBuild':build,'buildGrowthBytes':build['logicalBytes']-before['buildBytes'],'beforeFreeBytes':before['freeBytes'],'afterFreeBytes':shutil.disk_usage(root).free,'newUi06Evidence':evidence,'newUi06SafeInstallBackups':backups,'newEvidenceAndBackupsBytes':evidence['logicalBytes']+backups['logicalBytes'],'newAvds':0,'newFullAvdSnapshots':0,'filesDeletedByTask':0,'allocatedSize':'Not measured reliably; these are logical sizes, including existing sparse QCOW2 containers. Free-space deltas also include other workspace activity.','preservation':'No clean/cache/evidence deletion. Existing TASK08/09B AVD disks and snapshots retained. QA AVD resumed with no snapshot load/save.'}
with (out/(sys.argv[1] if len(sys.argv)>1 else 'storage_acceptance.json')).open('x',encoding='utf8') as f:json.dump(report,f,indent=2)
print(json.dumps(report,indent=2))
