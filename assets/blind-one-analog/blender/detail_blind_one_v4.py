"""Non-destructive V4 high-detail appearance study based on preserved V3."""
from pathlib import Path
import math, random, json
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'v4'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'v3'/'preserved-2026-09-12'/'TheBlindOne_V3.blend'))
random.seed(4401)
def log(msg):
    print('V4 | '+msg,flush=True)

def thread(name,points,radius,mat,radii=None):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D'
    data.resolution_u=3;data.bevel_depth=radius;data.bevel_resolution=2
    spline=data.splines.new('POLY');spline.points.add(len(points)-1)
    for i,(p,c) in enumerate(zip(spline.points,points)):
        p.co=(*c,1)
        if radii:p.radius=radii[i]
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    data.materials.append(mat);obj['CharacterAsset']=True
    return obj

def material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.92
    return m

stitchmat=material('V4 worn charcoal stitching',(.037,.032,.026))
crackmat=material('V4 aged mask hairline crevices',(.065,.052,.035))
skinmat=bpy.data.materials['V3 leathery charcoal skin']

log('Adding woven fabric, irregular weathering, and fine skin relief')
for mat in list(bpy.data.materials):
    if not mat.use_nodes or not mat.name.startswith('V3'):continue
    n=mat.node_tree.nodes;l=mat.node_tree.links
    bs=next((a for a in n if a.type=='BSDF_PRINCIPLED'),None)
    if not bs or 'eyes' in mat.name or 'darkness' in mat.name:continue
    tex=n.new('ShaderNodeTexCoord')
    # Object-space coordinates preserve thread density across garment pieces.
    macro=n.new('ShaderNodeTexNoise');macro.inputs['Scale'].default_value=7
    macro.inputs['Detail'].default_value=6;macro.inputs['Roughness'].default_value=.8
    l.new(tex.outputs['Object'],macro.inputs['Vector'])
    rough=n.new('ShaderNodeMapRange');rough.inputs['From Min'].default_value=0;rough.inputs['From Max'].default_value=1
    rough.inputs['To Min'].default_value=.64;rough.inputs['To Max'].default_value=.97
    l.new(macro.outputs['Fac'],rough.inputs['Value']);l.new(rough.outputs['Result'],bs.inputs['Roughness'])
    if any(s in mat.name for s in ['linen','bindings','folds']):
        # Two crossing thread families; a modulation breaks their perfect grid.
        warp=n.new('ShaderNodeTexWave');weft=n.new('ShaderNodeTexWave')
        warp.bands_direction='X';weft.bands_direction='Z'
        for wave in [warp,weft]:
            wave.inputs['Scale'].default_value=190
            wave.inputs['Distortion'].default_value=3
            wave.inputs['Detail Scale'].default_value=1.7
            l.new(tex.outputs['Object'],wave.inputs['Vector'])
        mix=n.new('ShaderNodeMath');mix.operation='MULTIPLY'
        l.new(warp.outputs['Color'],mix.inputs[0]);l.new(weft.outputs['Color'],mix.inputs[1])
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.27;bump.inputs['Distance'].default_value=.005
        if bs.inputs['Normal'].is_linked:l.new(bs.inputs['Normal'].links[0].from_socket,bump.inputs['Normal'])
        l.new(mix.outputs[0],bump.inputs['Height']);l.new(bump.outputs['Normal'],bs.inputs['Normal'])
        bs.inputs['Sheen Weight'].default_value=.055
    elif 'skin' in mat.name:
        pores=n.new('ShaderNodeTexVoronoi');pores.inputs['Scale'].default_value=155
        l.new(tex.outputs['Object'],pores.inputs['Vector'])
        bump=n.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.009;bump.inputs['Strength'].default_value=.3
        if bs.inputs['Normal'].is_linked:l.new(bs.inputs['Normal'].links[0].from_socket,bump.inputs['Normal'])
        l.new(pores.outputs['Distance'],bump.inputs['Height']);l.new(bump.outputs['Normal'],bs.inputs['Normal'])

log('Sculpting secondary folds and adding sewn seams')
for name in ['Long continuous robe','Loose blouse gathered into sash','Left sleeve','Right sleeve']:
    obj=bpy.data.objects.get(name)
    if not obj:continue
    # Additional diagonal compression folds grow near belt, elbows and cuffs.
    for v in obj.data.vertices:
        p=v.co;z=p.z
        if 'robe' in name:
            a=math.atan2(p.y/.4,p.x/.77)
            strength=.038*math.exp(-((z-6.45)/.58)**2)+.011
            d=strength*math.sin(z*17+a*3+.5*math.sin(z*9))
            p.x+=math.cos(a)*d;p.y+=math.sin(a)*d
        elif 'sleeve' in name:
            s=-1 if name.startswith('Left') else 1
            a=math.atan2(p.y,(p.x-s*1.0))
            d=.025*math.sin(z*27+a*2)*math.exp(-((z-7.1)/.62)**2)
            p.x+=math.cos(a)*d;p.y+=math.sin(a)*d
    sub=next((m for m in obj.modifiers if m.type=='SUBSURF'),None)
    if sub:sub.levels=2
    # Existing garment grids have 112 angular samples and 85 rows.
    for side in [7,49,63,105]:
        points=[]
        for row in range(3,81):
            v=obj.data.vertices[row*112+side].co.copy()
            angle=math.tau*side/112
            v+=Vector((math.cos(angle)*.021,math.sin(angle)*.021,0))
            points.append(v)
        thread(name+' raised sewn seam '+str(side),points,.004,stitchmat)
        for i in range(0,len(points)-1,2):
            p=points[i];q=points[i+1]
            tangent=Vector((-.009,.004,0))
            thread(name+' stitch '+str(side)+' '+str(i),[p-tangent,(p+q)*.5+tangent,q-tangent],.0025,stitchmat)

# Frayed hems: local strands, with uneven lengths and free ends.
robe=bpy.data.objects['Long continuous robe']
for side in range(112):
    p=robe.data.vertices[84*112+side].co.copy()
    for j in range(2):
        length=random.uniform(.04,.27)
        off=Vector((random.uniform(-.015,.015),random.uniform(-.014,.014),0))
        thread('Robe hem fibre %d %d'%(side,j),[p+off,p+off+Vector((.006,0,-length*.5)),p+off+Vector((-.005,.005,-length))],.0018,stitchmat,[1,.8,.1])

log('Adding mask cracks, hand creases, and weathered wraps')
mask=bpy.data.objects['Curved elongated ivory faceplate']
def maskpoint(row,col):
    v=mask.data.vertices[max(0,min(64,row))*41+max(0,min(40,col))].co.copy()
    v.y-=.017
    return mask.matrix_world@v
for idx,(r,c,dr,dc,length) in enumerate([(8,10,1,1,18),(15,32,1,-1,15),(33,19,1,-1,13),(41,28,1,0,15),(6,24,1,0,14)]):
    pts=[]
    for j in range(length):
        col=c+int(j*dc*.3)+random.choice([-1,0,0,0,1])
        pts.append(maskpoint(r+j*dr,col))
    thread('Fine branching mask fissure '+str(idx),pts,.0016,crackmat)

for name in ['Left organic exposed forearm','Right organic exposed forearm','Left palm','Right palm']:
    obj=bpy.data.objects[name]
    tex=bpy.data.textures.new(name+' fine wrinkled skin',type='CLOUDS');tex.noise_scale=.055;tex.noise_depth=2
    sub=obj.modifiers.new('Organic skin smoothing','SUBSURF');sub.levels=1
    dis=obj.modifiers.new('Fine skin irregularity','DISPLACE');dis.texture=tex;dis.strength=.009
for obj in list(bpy.data.objects):
    if 'Thin crossed hood wrap' in obj.name or 'thin shin binding' in obj.name:
        for v in obj.data.vertices:
            p=v.co;p.z+=.013*math.sin(p.x*17+p.y*13)+.006*math.sin(p.x*51-p.y*28)

# Better presentation uses a textured neutral studio ground, not image effects.
floor=bpy.data.objects['PreviewFloor_NOT_EXPORTED']
floor.location.z=.012
floor_mat=floor.data.materials[0];nodes=floor_mat.node_tree.nodes;links=floor_mat.node_tree.links
bs=nodes.get('Principled BSDF')
noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=85;noise.inputs['Detail'].default_value=3
bump=nodes.new('ShaderNodeBump');bump.inputs['Distance'].default_value=.015;bump.inputs['Strength'].default_value=.25
links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
scene=bpy.context.scene;scene.cycles.samples=96
scene.render.resolution_x=1200;scene.render.resolution_y=1600
scene.render.threads_mode='FIXED';scene.render.threads=8
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.32
for obj in bpy.data.objects:
    if obj.type=='LIGHT':
        obj.data.color=(.88,.92,1)
        if obj.name=='SoftFrontKey':obj.location=(-4,-5,9);obj.data.energy=1800;obj.data.size=3.5
        if obj.name=='SoftFrontFill':obj.data.energy=350
        if obj.name=='BackSilhouetteRim':obj.data.energy=1300;obj.data.size=4
        obj.rotation_euler=(Vector((0,0,5))-obj.location).to_track_quat('-Z','Y').to_euler()
camera=scene.camera
def view(pos,target,scale):
    camera.location=pos;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
scene['Status']='V4 high-detail appearance study; awaiting approval; unrigged'
view((0,-22,5.1),(0,0,5.1),10.8)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'TheBlindOne_V4_Detail.blend'))
for name,pos,target,scale in [('front',(0,-22,5.1),(0,0,5.1),10.8),('back',(0,22,5.1),(0,0,5.1),10.8),('detail',(3,-18,8.4),(-.1,0,8.25),3.8)]:
    view(pos,target,scale)
    scene.render.filepath=str(OUT/('TheBlindOne_V4_'+name+'.png'))
    bpy.ops.render.render(write_still=True);log('Rendered '+name)
view((0,-22,5.1),(0,0,5.1),10.8)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'TheBlindOne_V4_Detail.blend'))
(OUT/'review_status.json').write_text(json.dumps({'status':'awaiting user appearance approval','rigged':False,'game_integrated':False,'reference_parity':'not identical; procedural approximation','source':'preserved V3'},indent=2))
log('Detail pass complete')
