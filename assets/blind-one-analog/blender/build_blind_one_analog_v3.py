"""V3 reference study. Run with Blender --background --python this_file.

Keeps V1/V2 intact. Real mesh surfaces, no reference-image projection.
The first deliverable is an unrigged visual study, not a tested game asset.
"""
from pathlib import Path
import importlib.util
import math
import random
import json
import bpy
import bmesh
from mathutils import Vector, Matrix

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / 'v3'
OUT.mkdir(exist_ok=True)
spec = importlib.util.spec_from_file_location('base', HERE / 'build_blind_one_analog_v1.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
random.seed(312)
parts = []

def log(s):
    print('V3 | ' + s, flush=True)

def mesh(name, verts, faces, mat, thickness=0, subdiv=0):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    for poly in data.polygons:
        poly.use_smooth = True
    if subdiv:
        mod = obj.modifiers.new('Soft fabric surface', 'SUBSURF')
        mod.levels = subdiv
    if thickness:
        mod = obj.modifiers.new('Fabric thickness', 'SOLIDIFY')
        mod.thickness = thickness
    parts.append(obj)
    return obj

def sphere(name, p, scale, mat):
    obj = base.ellipsoid(name, p, scale, mat, subdivisions=3)
    parts.append(obj)
    return obj

def interp(seq, t):
    f = t * (len(seq)-1)
    i = min(int(f), len(seq)-2)
    a = f-i
    p0,p1,p2,p3=seq[max(0,i-1)],seq[i],seq[i+1],seq[min(len(seq)-1,i+2)]
    return .5*((2*p1)+(-p0+p2)*a+(2*p0-5*p1+4*p2-p3)*a*a+(-p0+3*p1-3*p2+p3)*a*a*a)

def path_tube(name, coords, radii, mat, sides=14, samples=36):
    points = [Vector(p) for p in coords]
    vs, fs = [], []
    for j in range(samples):
        t = j/(samples-1)
        f = t*(len(points)-1)
        k = min(int(f), len(points)-2)
        u=f-k
        p0,p1,p2,p3 = points[max(k-1,0)],points[k],points[k+1],points[min(k+2,len(points)-1)]
        p = .5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)
        tangent = (p2-p1).normalized()
        axis = tangent.cross(Vector((0,1,0))).normalized()
        other = tangent.cross(axis).normalized()
        r=interp(radii,t)
        for i in range(sides):
            ang=math.tau*i/sides
            vs.append(p+r*(math.cos(ang)*axis+math.sin(ang)*other))
    for j in range(samples-1):
        for i in range(sides):
            a=j*sides+i; b=j*sides+(i+1)%sides
            fs.append((a,b,b+sides,a+sides))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple((samples-1)*sides+i for i in range(sides)))
    return mesh(name,vs,fs,mat)

def garment(name, levels, mat, folds=9, amp=.05, seed=1, ragged=.10):
    # levels are top-down (z, x, y, halfwidth, halfdepth).
    rng=random.Random(seed)
    phase=rng.random()*6
    vs,fs=[],[]
    rows,sides=85,112
    for j in range(rows):
        t=j/(rows-1)
        z,x,y,rx,ry=[interp([p[q] for p in levels],t) for q in range(5)]
        for i in range(sides):
            a=math.tau*i/sides
            # Smooth low-frequency folds that meander and gather at the waist.
            fold=amp*(math.sin(folds*a+.9*math.sin(t*5+a*2)+phase)+.37*math.sin((folds+4)*a-t*2.7))
            fine=.008*math.sin(39*a+19*t)*math.sin(13*t+3*a)
            diagonal=.037*math.sin(40*t+4*a)*math.exp(-((t-.16)/.19)**2)
            hem=ragged*(.55+.3*math.sin(19*a+phase)+.15*math.sin(37*a))*(t**36)
            vs.append((x+math.cos(a)*(rx+fold+fine), y+math.sin(a)*(ry+fold*.62+fine+diagonal), z+hem))
    for j in range(rows-1):
        for i in range(sides):
            a=j*sides+i; b=j*sides+(i+1)%sides
            # sparse holes in the final few rows of old cloth
            if j>rows-5 and math.sin(i*7.13+seed+j*.3)>.91:
                continue
            fs.append((a,b,b+sides,a+sides))
    obj=mesh(name,vs,fs,mat,.009)
    # Fine threads emerge from actual hem locations.
    for i in range(0,sides,7):
        p=Vector(vs[(rows-1)*sides+i]); length=rng.uniform(.04,.29)
        path_tube(name+' loose thread '+str(i),[p,p+Vector((.012,0,-length*.5)),p+Vector((-.006,.004,-length))],[.003,.002,.0007],dark,sides=5,samples=7)
    return obj

def drape(name, radius, depth, top, drop, width, mat, phase=0):
    vs,fs=[],[]
    for j in range(9):
        t=j/8
        for i in range(100):
            a=math.tau*i/100
            front=max(0,-math.sin(a))
            z=top-drop*front**1.45+width*(t-.5)+.011*math.sin(a*4+phase)+.004*math.sin(a*13+t*8+phase)
            r=radius+.025*math.sin(math.pi*t)+.006*math.sin(a*17+phase)
            vs.append((-.1+r*math.cos(a),-.025+(depth+.018*math.sin(t*math.pi))*math.sin(a),z))
    for j in range(8):
        for i in range(100):
            a=j*100+i;b=j*100+(i+1)%100
            fs.append((a,b,b+100,a+100))
    return mesh(name,vs,fs,mat,.008)

def material(name, dark_color, light_color, scale=20):
    mat=base.textured_material(name,dark_color,light_color,.93,scale,.2,(1,1,1))
    n=mat.node_tree.nodes;l=mat.node_tree.links
    bs=next(x for x in n if x.type=='BSDF_PRINCIPLED')
    bs.inputs['Sheen Weight'].default_value=.025
    bump=next(x for x in n if x.type=='BUMP')
    bump.inputs['Distance'].default_value=.035
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=260;noise.inputs['Detail'].default_value=2
    micro=n.new('ShaderNodeBump');micro.inputs['Distance'].default_value=.008;micro.inputs['Strength'].default_value=.24
    l.new(noise.outputs['Fac'],micro.inputs['Height']);l.new(bump.outputs['Normal'],micro.inputs['Normal']);l.new(micro.outputs['Normal'],bs.inputs['Normal'])
    return mat

log('Building new continuous garment surfaces')
base.clear_scene()
cloth=material('V3 faded charcoal linen',(.004,.004,.004),(.021,.022,.023),28)
dark=material('V3 deep cloth folds',(.005,.005,.004),(.023,.021,.018),35)
wrap=material('V3 weathered bindings',(.004,.004,.004),(.021,.022,.023),40)
skin=material('V3 leathery charcoal skin',(.006,.006,.006),(.027,.026,.025),24)
ivory=material('V3 stained bone ivory mask',(.25,.225,.18),(.58,.55,.46),19)
void=base.flat_material('V3 eye socket darkness',(.001,.001,.001),.99)
eye=base.emission_material('V3 pinprick eyes',(.72,.79,.83),2.4)

# Reference height = 10 units. Robe stops at lower calf; belt is high on torso.
garment('Long continuous robe',[(6.80,-.04,0,.64,.34),(6.40,-.01,.015,.72,.38),(5.1,0,.01,.73,.37),(3.5,-.02,.02,.78,.39),(2.05,-.02,0,.79,.40)],cloth,folds=9,amp=.105,seed=31,ragged=.14)
garment('Loose blouse gathered into sash',[(8.72,-.10,.055,.78,.32),(8.33,-.08,0,.80,.36),(7.70,-.06,-.005,.67,.33),(7.08,-.045,0,.66,.36),(6.77,-.04,0,.59,.30)],cloth,folds=8,amp=.027,seed=45,ragged=.03)
# Broad shoulder mantle tapers continuously into the neck.
garment('Worn shoulder mantle',[(9.05,-.13,.03,.27,.25),(8.86,-.11,.035,.52,.31),(8.61,-.10,.03,.88,.36),(8.18,-.09,.04,.81,.38)],cloth,folds=7,amp=.035,seed=62,ragged=.08)
for i in range(5):
    drape('Draped cowl layer '+str(i),.32+i*.065,.30+i*.033,9.00-i*.085,.31+i*.095,.18,cloth,i)
# A loose scarf hangs from the cowl to the sash, rather than a bare flat chest.
for k in range(2):
    vs=[];fs=[]
    for j in range(65):
        t=j/64
        for i in range(17):
            u=i/16-.5
            x=(-.45 if k==0 else .32)+u*.28+.055*math.sin(t*4+k)
            vs.append((x,-.405-.065*math.sin(t*math.pi)+.025*math.cos(u*12+t*3),8.64-t*(1.78-k*.13)+.02*math.sin(u*22)*t**30))
    for j in range(64):
        for i in range(16):
            a=j*17+i;fs.append((a,a+1,a+18,a+17))
    mesh('Loose scarf fall '+str(k),vs,fs,cloth,.009)
for i in range(3):
    drape('Crushed waist sash '+str(i),.67,.40,6.86-i*.08,.04,.12,wrap,i+4)
sphere('Back sash knot',(.02,.45,6.74),(.16,.10,.13),wrap)
# Flat fabric tails, broad and flexible, at the back knot.
for k in range(2):
    vs=[];fs=[]
    for j in range(45):
        t=j/44
        for i in range(12):
            u=i/11-.5
            vs.append((.02+u*(.20-.035*t)+(k-.5)*.2*t+.065*math.sin(t*5+k),.445+.04*math.sin(t*6+k)+.018*math.sin(u*14),6.77-t*(2.7-k*.65)+.045*math.sin(u*12)*t**20))
    for j in range(44):
        for i in range(11):
            a=j*12+i;fs.append((a,a+1,a+13,a+12))
    mesh('Back sash hanging tail '+str(k),vs,fs,wrap,.01)

log('Building long limbs and five-digit curved hands')
for side,s in [('Left',-1),('Right',1)]:
    offset=.08 if s<0 else -.08
    garment(side+' sleeve',[(8.66+offset,s*.77,.02,.10,.13),(8.30+offset,s*.90,.01,.24,.23),(7.35+offset,s*1.01,-.015,.18,.19),(6.45+offset,s*1.05,-.02,.18,.18),(5.85+offset,s*1.08,-.035,.22,.18)],cloth,folds=7,amp=.022,seed=71+s,ragged=.13)
    wrist=(s*1.13,-.05,4.20+offset)
    path_tube(side+' organic exposed forearm',[(s*1.075,-.03,5.99+offset),(s*1.10,-.025,5.65+offset),(s*1.11,-.06,4.82+offset),wrist],[.15,.12,.079,.092],skin,sides=24,samples=50)
    palm=sphere(side+' palm',(s*1.14,-.075,3.99+offset),(.15,.09,.27),skin)
    for i,length in enumerate([.64,.79,.83,.69]):
        x=s*(1.14+(i-1.5)*.078)
        z=3.83+offset-abs(i-1.5)*.025
        path_tube(side+' finger '+str(i+1),[(x,-.085,z),(x-s*.006,-.09,z-length*.35),(x-s*.040,-.14,z-length*.73),(x-s*.15,-.18,z-length)],[.041,.037,.029,.012],skin,sides=12,samples=30)
        path_tube(side+' hand tendon '+str(i),[(s*1.12,-.135,4.25+offset),(x,-.164,4.0+offset),(x,-.14,z)],[.009,.007,.004],skin,sides=6,samples=16)
    path_tube(side+' thumb',[(s*1.02,-.065,4.04+offset),(s*.92,-.10,3.85+offset),(s*.91,-.15,3.59+offset),(s*.96,-.18,3.52+offset)],[.055,.043,.029,.012],skin,sides=14,samples=30)
    x=s*.40
    path_tube(side+' leg',[(x,0,3.1),(x,.015,2.15),(x,.03,1.37),(x,-.01,.24)],[.19,.145,.11,.105],skin,sides=24,samples=50)
    # Fine diagonal wraps conform to the shin instead of thick stacked blocks.
    for j in range(13):
        z=.49+j*.12
        vs=[];fs=[]
        for row in range(4):
            for i in range(48):
                a=math.tau*i/48;r=.112+(z-.5)*.025
                vs.append((x+r*math.cos(a),.01+r*math.sin(a),z+.048*math.sin(a)+row*.035))
        for row in range(3):
            for i in range(48):
                a=row*48+i;b=row*48+(i+1)%48;fs.append((a,b,b+48,a+48))
        mesh(side+' thin shin binding '+str(j),vs,fs,wrap,.004)
    sphere(side+' heel',(x,.05,.19),(.17,.20,.17),skin)
    sphere(side+' foot',(x,-.20,.16),(.21,.35,.125),skin)
    for i in range(5):
        sphere(side+' toe '+str(i),(x+s*(i-2)*.077,-.47+abs(i-1)*.021,.105),(.051-i*.004,.12-i*.01,.065-i*.005),skin)

log('Building wrapped head and small eyes')
head_start=len(parts)
sphere('Cloth hood silhouette',(0,.02,9.43),(.43,.36,.57),dark)
# Cloth follows the rounded skull, with small irregular crossed folds.
for j in range(11):
    z=9.20+j*.072
    r=.435*math.sqrt(max(.04,1-((z-9.43)/.60)**2))
    drape('Thin crossed hood wrap '+str(j),r,r*.80,z,.045,.112,wrap,j*.7)
sphere('Recessed eye band',(0,-.315,9.32),(.36,.10,.13),void)
# Long tapered mask, curved across its width; nose is a subtle central ridge.
vs=[];fs=[]
for j in range(65):
    t=j/64
    w=interp([.285,.29,.25,.19,.115,.018],t)
    for i in range(41):
        u=i/40*2-1
        vs.append((u*w,-.375-.09*(1-u*u)-.052*math.exp(-u*u*20)*math.sin(math.pi*t),9.23-1.00*t+.008*math.sin(u*4+t*11)))
for j in range(64):
    for i in range(40):
        a=j*41+i;fs.append((a,a+1,a+42,a+41))
mesh('Curved elongated ivory faceplate',vs,fs,ivory,.024)
seam_points=[]
for j in range(30):
    t=j/29;u=.024*math.sin(t*17)
    seam_points.append((u,-.467-.052*math.sin(math.pi*t),9.23-t))
path_tube('Fine central mask seam',seam_points,[.0028]*30,wrap,sides=6,samples=90)
for s in [-1,1]:
    sphere('Pinprick eye '+str(s),(s*.178,-.414,9.35),(.017,.012,.015),eye)
# Rotate the entire head together; never distort the face relative to its hood.
pivot=Vector((0,0,8.68)); rot=Matrix.Rotation(math.radians(-13),4,'Y') @ Matrix.Rotation(math.radians(7),4,'X')
for obj in parts[head_start:]:
    obj.matrix_world=Matrix.Translation(Vector((-.12,-.07,0))) @ Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ obj.matrix_world

log('Saving editable source and rendering the actual geometry')
# Small geometric wrinkles survive lighting changes and are editable modifiers.
wrinkle=bpy.data.textures.new('Uneven worn fabric relief',type='CLOUDS')
wrinkle.noise_scale=.095;wrinkle.noise_depth=2
for obj in parts:
    if obj.data.materials and obj.data.materials[0] in [cloth,wrap,dark] and len(obj.data.vertices)>1000:
        sub=obj.modifiers.new('Cloth surface smoothing','SUBSURF');sub.levels=1
        disp=obj.modifiers.new('Subtle uneven cloth relief','DISPLACE');disp.texture=wrinkle;disp.strength=.015;disp.texture_coords='GLOBAL'
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED';scene.render.threads=8
scene.render.resolution_x=800;scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
camera=base.add_stage()
backdrop=bpy.data.objects.get('PreviewBackdrop_NOT_EXPORTED')
backdrop.hide_render=True
world=scene.world.node_tree.nodes['Background']
world.inputs['Color'].default_value=(.30,.29,.27,1)
world.inputs['Strength'].default_value=.45
for light in bpy.data.lights:
    light.color=(1,.95,.88)
    if light.name=='SoftFrontKey':light.energy=1500
    if light.name=='SoftFrontFill':light.energy=550
camera.data.type='ORTHO';camera.data.ortho_scale=10.8
base.point_camera(camera,(0,-22,5.1),(0,0,5.1))
scene['Status']='V3 unrigged reference study; not yet validated in Roblox'
scene['Reference']='User pinprick-eye front/back sheet, 2026-09-12'
for obj in parts: obj['CharacterAsset']=True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'TheBlindOne_V3.blend'))
report={'mesh_objects':len(parts),'vertices':sum(len(o.data.vertices) for o in parts),'status':'unrigged visual study, procedural shaders require baking for game export'}
(OUT/'build_report.json').write_text(json.dumps(report,indent=2))
for name,pos in [('front',(0,-22,5.1)),('three_quarter',(11,-20,5.1)),('back',(0,22,5.1))]:
    base.point_camera(camera,pos,(0,0,5.1))
    scene.render.filepath=str(OUT/('TheBlindOne_V3_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
    log('Rendered '+name)
base.point_camera(camera,(0,-22,5.1),(0,0,5.1))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'TheBlindOne_V3.blend'))
log('Visual study complete')
