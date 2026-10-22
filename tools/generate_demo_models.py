from pathlib import Path
import json
import struct
root = Path('D:/fix-my-town/assets/models')
root.mkdir(parents=True, exist_ok=True)

def write_model(name, boxes):
    blob = bytearray()
    views, accessors, meshes, nodes, materials = [], [], [], [], []
    def buffer(values, fmt, target):
        while len(blob) % 4:
            blob.append(0)
        offset = len(blob)
        packed = struct.pack('<' + fmt * len(values), *values)
        blob.extend(packed)
        views.append(dict(buffer=0, byteOffset=offset, byteLength=len(packed), target=target))
        return len(views) - 1
    for center, size, color in boxes:
        x,y,z = [n/2 for n in size]
        verts = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        faces = [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]
        normals = [(0,0,-1),(0,0,1),(-1,0,0),(1,0,0),(0,1,0),(0,-1,0)]
        positions, normal_data, indices = [], [], []
        for face, normal in zip(faces,normals):
            start = len(positions)//3
            for index in face:
                positions.extend(verts[index]); normal_data.extend(normal)
            indices.extend([start,start+1,start+2,start,start+2,start+3])
        pos_view = buffer(positions,'f',34962)
        norm_view = buffer(normal_data,'f',34962)
        idx_view = buffer(indices,'H',34963)
        base = len(accessors)
        accessors.extend([
            dict(bufferView=pos_view,componentType=5126,count=24,type='VEC3',min=[-x,-y,-z],max=[x,y,z]),
            dict(bufferView=norm_view,componentType=5126,count=24,type='VEC3'),
            dict(bufferView=idx_view,componentType=5123,count=36,type='SCALAR')])
        materials.append(dict(pbrMetallicRoughness=dict(baseColorFactor=[*color,1],metallicFactor=0,roughnessFactor=.85)))
        meshes.append(dict(primitives=[dict(attributes=dict(POSITION=base,NORMAL=base+1),indices=base+2,material=len(materials)-1)]))
        nodes.append(dict(name='Part'+str(len(nodes)),mesh=len(meshes)-1,translation=center))
    payload = dict(asset=dict(version='2.0',generator='Fix My Town original placeholder generator'),scene=0,scenes=[dict(nodes=list(range(len(nodes))))],nodes=nodes,meshes=meshes,materials=materials,buffers=[dict(byteLength=len(blob))],bufferViews=views,accessors=accessors)
    meta = json.dumps(payload,separators=(',',':')).encode()
    meta += b' ' * ((-len(meta))%4)
    blob += b'\x00' * ((-len(blob))%4)
    result = struct.pack('<III',0x46546c67,2,12+8+len(meta)+8+len(blob)) + struct.pack('<II',len(meta),0x4e4f534a)+meta+struct.pack('<II',len(blob),0x004e4942)+blob
    (root/(name+'.glb')).write_bytes(result)

write_model('house_demo', [([0,1,0],[3,2,1.3],[.82,.65,.45]),([0,2.1,0],[3.3,.3,1.6],[.66,.29,.24]),([-.8,1.1,.67],[.5,.5,.05],[.8,.9,.85]),([.8,1.1,.67],[.5,.5,.05],[.8,.9,.85])])
write_model('repair_van_demo', [([0,.45,0],[.8,.55,1.3],[.25,.55,.78]),([0,.85,.2],[.7,.4,.6],[.8,.9,.85]),([0,1.12,0],[.6,.15,.2],[.9,.45,.3])] + [([x,.2,z],[.15,.3,.3],[.15,.2,.22]) for x in [-.45,.45] for z in [-.4,.4]])
for kind in ['house','repair_van']:
    (root.parents[1]/'scenes/visuals'/f'{kind}_alternate.tscn').write_text(f'''[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://assets/models/{kind}_demo.glb" id="1"]

[node name="ModelWrapper" type="Node3D"]

[node name="Model" parent="." instance=ExtResource("1")]
scale = {"Vector3(1.5, 1.5, 2.5)" if kind == "house" else "Vector3(2, 1.5, 2)"}
''',encoding='utf-8')
print('Created two original GLB replacement fixtures')
