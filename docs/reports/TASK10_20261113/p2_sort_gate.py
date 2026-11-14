"""Real shared library sort controls, independent app-owned MediaStore oracle.

Compares visible leading titles for each unique sort/kind; does not claim every
off-screen item or tie identity is inspected. No media is changed.
"""
import json
import re
import device_qa as q

q.identity()
prefs = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')
results = []
state = {'kind': 'Video', 'sort': 'Newest', 'sheet': True}


def provider(kind):
    collection = 'video/media' if kind == 'Video' else 'images/media'
    columns = '_id:_display_name:_size:date_added' + (':duration' if kind == 'Video' else '')
    raw = q.adb('shell', 'content', 'query', '--uri', 'content://media/external/' + collection,
        '--projection', columns, '--where', '"owner_package_name=\'com.xrecorder.xrecorder\' AND is_pending=0"').decode()
    pattern = r'Row: \d+ _id=(\d+), _display_name=(.*), _size=(\d+), date_added=(\d+)' + (r', duration=(\d+)' if kind == 'Video' else '')
    rows = []
    for line in raw.splitlines():
        match = re.fullmatch(pattern, line)
        assert match, line
        values = match.groups()
        rows.append({'id': 'content://media/external/' + collection + '/' + values[0],
            'name': values[1], 'size': int(values[2]), 'created': int(values[3]),
            'duration': int(values[4]) if kind == 'Video' else 0})
    assert len(rows) > 2
    return rows


try:
    for kind in ['Video', 'Photo']:
        rows = provider(kind)
        if kind != state['kind']:
            q.click(kind)
            state = {'kind': kind, 'sort': 'Newest', 'sheet': False}
        choices = ['Newest', 'Oldest', 'Name', 'Largest'] + (['Longest'] if kind == 'Video' else [])
        for choice in choices:
            if not state['sheet']:
                q.click(state['sort'])  # Actual chip; Sort media is a tooltip node.
                state['sheet'] = True
            labels = q.labels(q.tree()[1])
            assert all(x in labels for x in choices)
            assert ('Longest' in labels) == (kind == 'Video')
            q.click(choice)
            state['sort'] = choice
            state['sheet'] = False
            _, nodes = q.tree()
            actual = [n.get('content-desc')[len('Actions for '):] for n in nodes
                      if n.get('content-desc', '').startswith('Actions for ')]
            key = {'Newest': lambda r: (-r['created'], r['id']),
                   'Oldest': lambda r: (r['created'], r['id']),
                   'Name': lambda r: (r['name'].lower(), r['id']),
                   'Largest': lambda r: (-r['size'], r['id']),
                   'Longest': lambda r: (-r['duration'], r['id'])}[choice]
            expected = [r['name'] for r in sorted(rows, key=key)]
            count = min(2, len(actual))
            result = {'kind': kind, 'choice': choice, 'providerRows': len(rows),
                'visibleLeadingTitles': actual[:count], 'expectedLeadingTitles': expected[:count],
                'checkedVisibleItems': count, 'status': 'PASS' if count >= 1 and actual[:count] == expected[:count] else 'FAIL'}
            results.append(result)
            with (q.ROOT / 'p2_sort_progress.json').open('w') as out:
                json.dump(results, out, indent=2)
            assert result['status'] == 'PASS', result
            print(json.dumps(result), flush=True)
        q.click(state['sort']); state['sheet'] = True
        q.click('Newest'); state['sheet'] = False; state['sort'] = 'Newest'
    q.save('p2_sort_photo_restored')
    assert prefs == q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')
    with (q.ROOT / 'p2_sort_validation.json').open('x') as out:
        json.dump({'status': 'PASS', 'cases': results, 'uniqueSortKindCases': len(results),
                   'preferencesByteExact': True, 'restoredSort': 'Newest',
                   'scope': 'visible leading titles and all menu choices; no exhaustive offscreen/tie-identity claim'}, out, indent=2)
finally:
    # Restore only this test's transient sort state; no content mutations.
    if state['sheet']:
        q.adb('shell', 'input', 'keyevent', '4')
        state['sheet'] = False
    if state['sort'] != 'Newest':
        q.click(state['sort'])
        q.click('Newest')
