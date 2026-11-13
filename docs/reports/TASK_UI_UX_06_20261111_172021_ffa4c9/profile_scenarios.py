def stats(events, name):
    values = []
    stack = {}
    for e in events:
        if e.get('name') != name:
            continue
        key = (e.get('pid'), e.get('id')) if e.get('ph') in ['b', 'e'] else (e.get('pid'), e.get('tid'))
        if e.get('ph') == 'X':
            values.append(e['dur'] / 1000)
        elif e.get('ph') in ['B', 'b']:
            stack.setdefault(key, []).append(e['ts'])
        elif e.get('ph') in ['E', 'e'] and stack.get(key):
            values.append((e['ts'] - stack[key].pop()) / 1000)
    values.sort()
    if not values:
        return {'frames': 0}
    pct = lambda p: values[min(len(values) - 1, math.ceil(len(values) * p) - 1)]
    return {'frames': len(values), 'meanMs': statistics.mean(values), 'p50Ms': pct(0.5), 'p90Ms': pct(0.9), 'p99Ms': pct(0.99), 'maxMs': max(values), 'over16_67ms': sum((v > 1000 / 60 for v in values))}
