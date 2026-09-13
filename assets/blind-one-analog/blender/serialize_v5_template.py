"""Save the inspected Studio template as a Rojo-loadable model, including joints."""
from pathlib import Path
import json, xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[3]
folder=root/'assets/blind-one-analog/v5-rig-review'
rows=json.loads((folder/'StudioTemplateSnapshot.json').read_text())
xml=ET.Element('roblox',version='4')
items={}
for row in rows:
    item=ET.Element('Item',{'class':row['class'],'referent':'RBX'+str(row['id'])})
    items[row['id']]=item
    properties=ET.SubElement(item,'Properties')
    for name,prop in row['properties'].items():
        kind=prop['type'];value=prop.get('value');entry=ET.SubElement(properties,kind,name=name)
        if kind=='CoordinateFrame':
            for key,v in zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],value):ET.SubElement(entry,key).text=str(v)
        elif kind in ('Vector3','Color3'):
            for key,v in zip(['X','Y','Z'] if kind=='Vector3' else ['R','G','B'],value):ET.SubElement(entry,key).text=str(v)
        elif kind=='Content':ET.SubElement(entry,'url' if value else 'null').text=value or None
        elif kind=='Ref':entry.text='RBX'+str(value) if value else 'null'
        elif kind=='bool':entry.text=str(value).lower()
        else:entry.text=str(value)
for row in rows:(items[row['parent']] if row.get('parent') else xml).append(items[row['id']])
ET.indent(xml)
ET.ElementTree(xml).write(folder/'BlindOneV5Template.rbxmx',encoding='utf-8',xml_declaration=True)
assert sum(r['class']=='Motor6D' for r in rows)==26
assert sum(r['class']=='Bone' for r in rows)==17
print('Serialized',len(rows),'instances, 26 mesh joints and 17 bones')
