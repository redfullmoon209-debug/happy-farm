"""Run with Blender --background --python tools/import_kungfu.py -- source.fbx.
Append 5 independent equipment meshes to the existing female glTF without
rewriting its skeleton, old meshes, buffers, animations, or materials.
Run only on an isolated import branch; nearest-surface weights require visual QA.
"""
import bpy, json, sys, struct, tempfile, shutil, copy
from pathlib import Path
from mathutils.kdtree import KDTree
import numpy as np

root = Path.cwd()
target = root / "assets/characters/modular/Female"
model = target / "Female_Modular.gltf"
src = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
slots = {"Head": ("headwear", "Master_Head", "Mask"),
         "Shirt": ("top", "Starter_top", "Shirt"),
         "Gloves": ("gloves", "Starter_gloves", "Gloves"),
         "Skirt": ("bottom", "Starter_bottom", "Skirt"),
         "Boots": ("shoes", "Starter_shoes", "Boots")}
names = {"Female_KungFu_" + p: v for p, v in slots.items()}
old = json.loads(model.read_text())
assert not any(n.get("name") in names for n in old["nodes"]), "Already imported"
old_nodes = {n.get("name"): n for n in old["nodes"]}
parent = next(n for n in old["nodes"] if old["nodes"].index(old_nodes["Starter_top"]) in n.get("children", []))
skin = old_nodes["Starter_top"]["skin"]
assert all(old_nodes[v[1]]["skin"] == skin for v in slots.values())
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(src))
chosen = {}
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name in names:
        chosen[o.name] = o
    else:
        bpy.data.objects.remove(o, do_unlink=True)
assert set(chosen) == set(names), f"Missing expected meshes: {set(names)-set(chosen)}"
bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = next(iter(chosen.values()))
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
tmp = Path(tempfile.mkdtemp(prefix="farmflex-kungfu-"))
bpy.ops.export_scene.gltf(filepath=str(tmp/"kungfu.gltf"), export_format="GLTF_SEPARATE", export_yup=True, use_selection=True, export_animations=False)
new = json.loads((tmp/"kungfu.gltf").read_text())
assert not new.get("skins"), "Source unexpectedly skinned"
def get_array(doc, folder, i):
    a=doc["accessors"][i]; v=doc["bufferViews"][a["bufferView"]]
    typ={5121:"<u1",5123:"<u2",5125:"<u4",5126:"<f4"}[a["componentType"]]
    count={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}[a["type"]]
    dt=np.dtype(typ)
    raw=(folder/doc["buffers"][v["buffer"]]["uri"]).read_bytes()
    offset=v.get("byteOffset",0)+a.get("byteOffset",0)
    stride=v.get("byteStride",count*dt.itemsize)
    arr=np.ndarray((a["count"],count),dtype=dt,buffer=raw,offset=offset,strides=(stride,dt.itemsize)).copy()
    if a.get("normalized") and dt.kind=="u": arr=arr.astype(np.float32)/np.iinfo(dt).max
    return arr
# Weight lookup from the corresponding existing slot in exactly the same local bind coordinates.
weights_blob=bytearray()
weight_buffer=len(old["buffers"])+len(new["buffers"])
keys=("buffers","bufferViews","accessors","images","samplers","textures","materials","meshes")
off={k:len(old.get(k,[])) for k in keys}
def append_attr(arr, component):
    while len(weights_blob)%4: weights_blob.append(0)
    start=len(weights_blob); data=arr.tobytes(); weights_blob.extend(data)
    idx=len(old["bufferViews"])
    old["bufferViews"].append({"buffer":weight_buffer,"byteOffset":start,"byteLength":len(data),"target":34962})
    ai=len(old["accessors"])
    old["accessors"].append({"bufferView":idx,"componentType":component,"count":len(arr),"type":"VEC4"})
    return ai
# Copy new assets with distinct names and remap every index.
for k in keys: old.setdefault(k,[])
for i,b in enumerate(new["buffers"]):
    uri=f"KungFu_geometry_{i}.bin"; shutil.copyfile(tmp/b["uri"],target/uri); old["buffers"].append(dict(b,uri=uri))
for v in new["bufferViews"]: old["bufferViews"].append(dict(v,buffer=v["buffer"]+off["buffers"]))
for a in new["accessors"]:
    assert "sparse" not in a
    old["accessors"].append(dict(a,bufferView=a["bufferView"]+off["bufferViews"]))
for i,img in enumerate(new.get("images",[])):
    assert "uri" in img and not img["uri"].startswith("data:")
    uri="KungFu_texture_"+str(i)+Path(img["uri"]).suffix
    shutil.copyfile(tmp/img["uri"],target/uri); old["images"].append(dict(img,uri=uri))
old["samplers"].extend(new.get("samplers",[]))
for tex in new.get("textures",[]):
    assert not tex.get("extensions"), "Unsupported texture extension"
    t=copy.deepcopy(tex); t["source"]+=off["images"]
    if "sampler" in t: t["sampler"]+=off["samplers"]
    old["textures"].append(t)
def remap_textures(obj):
    if isinstance(obj,dict):
        for k,v in obj.items():
            if k.lower().endswith("texture") and isinstance(v,dict) and "index" in v: v["index"]+=off["textures"]
            remap_textures(v)
    elif isinstance(obj,list):
        for x in obj: remap_textures(x)
for mat in new.get("materials",[]):
    mat=copy.deepcopy(mat); remap_textures(mat); old["materials"].append(mat)
old["extensionsUsed"]=sorted(set(old.get("extensionsUsed",[])+new.get("extensionsUsed",[])))
if new.get("extensionsRequired"): old["extensionsRequired"]=sorted(set(old.get("extensionsRequired",[])+new["extensionsRequired"]))
node_names=set()
for n in new["nodes"]:
    if n.get("name") not in names: continue
    name=n["name"]; node_names.add(name)
    assert "mesh" in n and not n.get("children") and not any(k in n for k in ("matrix","translation","rotation","scale")), f"Nonidentity transform for {name}"
    slot,reference,label=names[name]
    donor=old["meshes"][old_nodes[reference]["mesh"]]
    dp=[]; dj=[]; dw=[]
    for p in donor["primitives"]:
        at=p["attributes"]
        dp.append(get_array(old,target,at["POSITION"])); dj.append(get_array(old,target,at["JOINTS_0"])); dw.append(get_array(old,target,at["WEIGHTS_0"]))
    positions=np.concatenate(dp); joints=np.concatenate(dj); weights=np.concatenate(dw)
    tree=KDTree(len(positions))
    for idx,pt in enumerate(positions): tree.insert(tuple(pt),idx)
    tree.balance()
    mesh=copy.deepcopy(new["meshes"][n["mesh"]])
    for p in mesh["primitives"]:
        assert not p.get("targets") and not p.get("extensions")
        pos=get_array(new,tmp,p["attributes"]["POSITION"])
        assert np.max(np.abs(pos))<2.0, f"Unexpected scale: {name}"
        assert np.max(pos[:,1])>0.05 and np.min(pos[:,1])>-0.15, f"Unexpected orientation: {name}"
        j=np.zeros((len(pos),4),dtype="<u2"); w=np.zeros((len(pos),4),dtype="<f4")
        distances=[]
        for idx,pt in enumerate(pos):
            nearest=tree.find_n(tuple(pt),4); distances.append(nearest[0][2]); blend={}
            for _,di,d in nearest:
                factor=1.0/max(d,0.0001)**2
                for joint,weight in zip(joints[di],weights[di]):
                    if weight>0: blend[int(joint)]=blend.get(int(joint),0.0)+float(weight)*factor
            top=sorted(blend.items(),key=lambda x:-x[1])[:4]; total=sum(x[1] for x in top)
            assert total>0
            for k,(joint,weight) in enumerate(top): j[idx,k]=joint; w[idx,k]=weight/total
        assert np.percentile(distances,95)<0.15, f"Poor fit: {name}"
        print(name,"vertices",len(pos),"95% donor distance",np.percentile(distances,95))
        p["attributes"]={k:v+off["accessors"] for k,v in p["attributes"].items()}
        if "indices" in p: p["indices"]+=off["accessors"]
        if "material" in p: p["material"]+=off["materials"]
        p["attributes"]["JOINTS_0"]=append_attr(j,5123)
        p["attributes"]["WEIGHTS_0"]=append_attr(w,5126)
    mi=len(old["meshes"]); old["meshes"].append(mesh)
    ni=len(old["nodes"]); old["nodes"].append({"name":name,"mesh":mi,"skin":skin}); parent["children"].append(ni)
assert node_names==set(names)
assert len(old["buffers"])==weight_buffer
(target/"KungFu_weights.bin").write_bytes(weights_blob)
old["buffers"].append({"uri":"KungFu_weights.bin","byteLength":len(weights_blob)})
# Keep all existing catalog IDs, add separate five-piece set.
catalog=root/"scripts/FemaleWardrobe.gd"
txt=catalog.read_text()
assert "female_kungfu_top" not in txt
entries=[]
for name,(slot,_,label) in names.items():
    entries.append('    "female_kungfu_'+slot+'": '+json.dumps({"gender":"female","set":"kungfu","slot":slot,"mesh":name,"name":"KungFu "+label,"price":0},ensure_ascii=False))
txt=txt.replace("const ITEMS = {","const ITEMS = {\n"+",\n".join(entries)+",",1)
catalog.write_text(txt)
model.write_text(json.dumps(old,ensure_ascii=False,indent=2))
print("KUNGFU IMPORT COMPLETE: five meshes, original skin and legacy assets retained")
