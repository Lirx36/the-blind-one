import json, struct
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'v5-rig-review/TheBlindOne_V5_RiggedReview.glb'
b=p.read_bytes();n=struct.unpack_from('<I',b,12)[0]
d=json.loads(b[20:20+n]);raw=b[28+n:]
for animation in d['animations']:
    for channel in animation['channels']:
        path=channel['target']['path']
        if path not in ('scale','weights'):continue
        assert path=='scale', 'Unexpected animated morph weights'
        a=d['accessors'][animation['samplers'][channel['sampler']]['output']]
        v=d['bufferViews'][a['bufferView']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0)
        values=[struct.unpack_from('<fff',raw,start+i*v.get('byteStride',12)) for i in range(a['count'])]
        error=max(abs(x-1) for row in values for x in row)
        print(d['nodes'][channel['target']['node']]['name'],error)
        assert error<0.00001, 'Nonidentity scale animation'
print('All scale tracks are identity within 0.00001; no morph-weight tracks.')
