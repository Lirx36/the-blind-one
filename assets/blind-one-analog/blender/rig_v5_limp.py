"""Separate skinned V4 copy and review animation. Never modifies gameplay or V4."""
from pathlib import Path
import bpy, math, json, hashlib, traceback
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'v5-rig-review'
OUT.mkdir(exist_ok=True)
def run():
    source=ROOT/'v4'/'TheBlindOne_V4_RobloxPreview.blend'
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(source))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in meshes:
        world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH': bpy.data.objects.remove(o,do_unlink=True)
    data=bpy.data.armatures.new('BlindOneSkeleton')
    rig=bpy.data.objects.new('BlindOneV5Rig',data);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    def bone(n,h,t,parent=None):
        b=data.edit_bones.new(n);b.head=h;b.tail=t
        if parent:b.parent=data.edit_bones[parent]
    bone('Root',(0,0,0),(0,0,1))
    bone('Hips',(0,0,6.5),(0,0,7.1),'Root')
    bone('Spine',(0,0,7.1),(-.1,0,8.6),'Hips')
    bone('Head',(-.1,0,8.6),(-.2,0,9.7),'Spine')
    bone('Robe',(0,0,6.5),(0,0,2.1),'Hips')
    for side,s in [('L',-1),('R',1)]:
        off=.08 if s<0 else -.08
        bone('UpperArm.'+side,(s*.78,0,8.6+off),(s*1.075,-.03,5.99+off),'Spine')
        bone('Forearm.'+side,(s*1.075,-.03,5.99+off),(s*1.13,-.05,4.2+off),'UpperArm.'+side)
        bone('Hand.'+side,(s*1.13,-.05,4.2+off),(s*1.14,-.1,3.45+off),'Forearm.'+side)
        bone('Thigh.'+side,(s*.4,0,6.5),(s*.4,-.18,3.25),'Hips')
        bone('Shin.'+side,(s*.4,-.18,3.25),(s*.4,0,.3),'Thigh.'+side)
        bone('Foot.'+side,(s*.4,0,.3),(s*.4,-.5,.12),'Shin.'+side)
    bpy.ops.object.mode_set(mode='OBJECT')
    def blend(z,center,width,low,high):
        t=max(0,min(1,(z-center)/width+.5));t=t*t*(3-2*t)
        return {low:1-t,high:t}
    for o in meshes:
        groups={b.name:o.vertex_groups.new(name=b.name) for b in data.bones}
        category=o.get('RobloxMaterialCategory','cloth')
        # Material batches contain unrelated islands. Classify whole islands,
        # so fingers and loose hem threads cannot switch to another limb midway.
        adjacency=[[] for _ in o.data.vertices]
        for edge in o.data.edges:
            a,b=edge.vertices;adjacency[a].append(b);adjacency[b].append(a)
        regions={};seen=set()
        for vertex in o.data.vertices:
            if vertex.index in seen:continue
            stack=[vertex.index];seen.add(vertex.index);island=[]
            while stack:
                index=stack.pop();island.append(index)
                for neighbor in adjacency[index]:
                    if neighbor not in seen:seen.add(neighbor);stack.append(neighbor)
            center=sum((o.matrix_world@o.data.vertices[i].co for i in island),Vector())/len(island)
            cx,cy,cz=center
            region='body'
            if 'sleeve' in o.name.lower() or (abs(cx)>.86 and 3<cz<8.55):region='arm'
            if cz<3.2 and category in ('skin','binding') and abs(cx)<.8:region='leg'
            if o.name in ('Long continuous robe','Loose blouse gathered into sash','Worn shoulder mantle'):region='body'
            for i in island:regions[i]=(region,'L' if cx<0 else 'R')
        for v in o.data.vertices:
            p=o.matrix_world@v.co;x,y,z=p;side='L' if x<0 else 'R'
            region,side=regions[v.index]
            if region=='arm':
                if z<4.65:w=blend(z,4.2,.32,'Hand.'+side,'Forearm.'+side)
                elif z<6.5:w=blend(z,6.0,.55,'Forearm.'+side,'UpperArm.'+side)
                else:w=blend(z,8.45,.5,'UpperArm.'+side,'Spine')
            elif region=='leg':
                w=blend(z,.34,.28,'Foot.'+side,'Shin.'+side) if z<.8 else blend(z,3.25,.65,'Shin.'+side,'Thigh.'+side)
            elif z<6.8:w=blend(z,6.5,.5,'Robe','Hips')
            else:w=blend(z,8.75,.45,'Spine','Head') if z>8 else blend(z,7.05,.65,'Hips','Spine')
            for n,weight in w.items():
                if weight>0:groups[n].add([v.index],weight,'REPLACE')
        o.parent=rig
        mod=o.modifiers.new('Skin deformation','ARMATURE');mod.object=rig
    scene=bpy.context.scene;scene.render.fps=24;scene.frame_start=1;scene.frame_end=48
    def set_world(n,h,t):
        b=rig.pose.bones[n];rest=data.bones[n]
        rot=(rest.tail_local-rest.head_local).rotation_difference(Vector(t)-Vector(h))@rest.matrix_local.to_quaternion()
        b.matrix=Matrix.Translation(Vector(h))@rot.to_matrix().to_4x4()
        bpy.context.view_layer.update()
    def leg(side,phase,bob):
        s=-1 if side=='L' else 1
        # Unequal stance: injured right foot stays down longer and barely clears floor.
        u=phase%1;stance=.58 if side=='L' else .76
        if u<stance: y=-.48+.96*u/stance;lift=0
        else:
            t=(u-stance)/(1-stance);smooth=t*t*(3-2*t)
            y=.48-.96*smooth;lift=math.sin(math.pi*t)*(.19 if side=='L' else .035)
        hip=Vector((s*.4,0,6.5+bob));ankle=Vector((s*.4,y,.3+lift))
        a=(data.bones['Thigh.'+side].tail_local-data.bones['Thigh.'+side].head_local).length
        b=(data.bones['Shin.'+side].tail_local-data.bones['Shin.'+side].head_local).length
        d=(ankle-hip).length;direction=(ankle-hip).normalized()
        along=(a*a-b*b+d*d)/(2*d);height=math.sqrt(max(0,a*a-along*along))
        forward=Vector((0,-1,0));perp=(forward-direction*forward.dot(direction)).normalized()
        knee=hip+direction*along+perp*height
        set_world('Thigh.'+side,hip,knee);set_world('Shin.'+side,knee,ankle)
        set_world('Foot.'+side,ankle,ankle+Vector((0,-.5,-.18)))
    for f in range(1,50):
        scene.frame_set(f);phase=(f-1)/48;theta=phase*math.tau
        buckle=max(0,math.sin(theta))**6
        bob=-.09-.13*buckle
        for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
        rig.pose.bones['Hips'].location=(0,bob,0)
        rig.pose.bones['Spine'].rotation_euler=(math.radians(3+2*buckle),0,math.radians(1.2*math.sin(theta)))
        rig.pose.bones['Head'].rotation_euler=(math.radians(-2+1.8*math.sin(theta-.8)),math.radians(2*math.sin(theta*.0+theta-.6)),0)
        rig.pose.bones['Robe'].rotation_euler=(math.radians(1.5*math.sin(theta-.5)),0,0)
        for side,offset in [('L',0),('R',math.pi)]:
            wave=math.sin(theta+offset-.65)
            rig.pose.bones['UpperArm.'+side].rotation_euler=(math.radians((8 if side=='L' else 4)*wave),0,math.radians(1.5*wave))
            rig.pose.bones['Forearm.'+side].rotation_euler=(math.radians(4+3*math.sin(theta+offset-1.1)),0,0)
            rig.pose.bones['Hand.'+side].rotation_euler=(math.radians(7*math.sin(theta+offset-1.5)),0,math.radians(3*wave))
        bpy.context.view_layer.update()
        leg('L',phase,bob);leg('R',phase+.5,bob)
        for b in rig.pose.bones:
            b.keyframe_insert('location',frame=f);b.keyframe_insert('rotation_euler',frame=f);b.keyframe_insert('scale',frame=f)
    rig.animation_data.action.name='BlindOne_UnsettlingLimp_Review'
    scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/'TheBlindOne_V5_RiggedReview.glb'),export_format='GLB',use_selection=True,export_skins=True,export_animations=True,export_frame_range=True,export_force_sampling=True,export_extras=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'TheBlindOne_V5_RiggedReview.blend'))
    report={'source_unchanged':hashlib.sha256(source.read_bytes()).hexdigest()==digest,'bones':len(data.bones),'meshes':len(meshes),'frames':48,'status':'Rigged review copy; not Roblox-import tested','triangles':sum(len(o.data.polygons) for o in meshes)}
    (OUT/'report.json').write_text(json.dumps(report,indent=2))
    # Neutral lit animation review: actual mesh deformation, no generated imagery.
    camdata=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',camdata);scene.collection.objects.link(cam);scene.camera=cam
    cam.location=(11,-21,6);cam.rotation_euler=(Vector((0,0,5))-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=10.7
    scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED';scene.render.threads=8
    scene.render.resolution_x=384;scene.render.resolution_y=512;scene.render.resolution_percentage=100
    scene.world.color=(.22,.22,.22)
    scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.3,.3,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
    for name,pos,power,size in [('Key',(3,-8,12),2100,8),('Rim',(-4,4,9),1800,6)]:
        light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
        o=bpy.data.objects.new(name,light);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,5))-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.image_settings.file_format='PNG'
    for f in range(1,49,2):
        scene.frame_set(f);scene.render.filepath=str(OUT/f'frame_{f:03}.png');bpy.ops.render.render(write_still=True)
        (OUT/'progress.txt').write_text(f'Rendered {f}/47')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'TheBlindOne_V5_RiggedReview.blend'))
    (OUT/'DONE').write_text('Review complete')
try:run()
except Exception:
    (OUT/'ERROR.txt').write_text(traceback.format_exc());raise
