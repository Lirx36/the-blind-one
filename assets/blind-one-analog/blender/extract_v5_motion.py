"""Extract the approved GLB's sampled local bone motion for Roblox playback."""
import json,struct,math
from pathlib import Path
root=Path(__file__).resolve().parents[3]
raw=(root/'assets/blind-one-analog/v5-rig-review/TheBlindOne_V5_RiggedReview.glb').read_bytes()
n=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+n]);binary=raw[28+n:]
def values(i):
    a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']];size={'SCALAR':1,'VEC3':3,'VEC4':4}[a['type']]
    assert a['componentType']==5126
    start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size*4)
    return [struct.unpack_from('<'+'f'*size,binary,start+k*stride) for k in range(a['count'])]
def array(v):return '{'+','.join(f'{x:.7g}' for x in v)+'}'
clip=doc['animations'][0];tracks={}
for channel in clip['channels']:
    node=channel['target']['node'];path=channel['target']['path'];sampler=clip['samplers'][channel['sampler']]
    times=[v[0] for v in values(sampler['input'])];keys=values(sampler['output']);samples=[]
    for frame in range(48):
        t=frame/24;index=next((i for i in range(len(times)-1) if times[i+1]>=t),len(times)-1)
        a=keys[index];b=keys[min(index+1,len(keys)-1)]
        alpha=0 if index==len(times)-1 else max(0,min(1,(t-times[index])/(times[index+1]-times[index])))
        if path=='rotation':
            dot=sum(x*y for x,y in zip(a,b))
            if dot<0:b=tuple(-x for x in b);dot=-dot
            if dot<.9995:
                angle=math.acos(min(1,dot));v=tuple((math.sin((1-alpha)*angle)*x+math.sin(alpha*angle)*y)/math.sin(angle) for x,y in zip(a,b))
            else:v=tuple(x+(y-x)*alpha for x,y in zip(a,b))
            length=math.sqrt(sum(x*x for x in v));v=tuple(x/length for x in v)
        else:v=tuple(x+(y-x)*alpha for x,y in zip(a,b))
        samples.append(v)
    tracks.setdefault(node,{})[path]=samples
lines=['-- Generated from approved V5 GLB. Local bind-relative transforms.','return { Frames = 48, Duration = 2, Bones = {']
for node,track in tracks.items():
    obj=doc['nodes'][node];name=obj['name'];rest=obj.get('translation',[0,0,0])+obj.get('rotation',[0,0,0,1])
    lines.append('['+json.dumps(name)+']={ Rest='+array(rest)+', Samples={')
    for f in range(48):
        t=track.get('translation',[obj.get('translation',[0,0,0])]*48)[f]
        q=track.get('rotation',[obj.get('rotation',[0,0,0,1])]*48)[f]
        lines.append(array(list(t)+list(q))+',')
    lines.append('}},')
lines.append('}}')
(root/'src/ReplicatedStorage/BlindOneV5Motion.luau').write_text('\n'.join(lines)+'\n')
print('Exported',len(tracks),'bone tracks')
