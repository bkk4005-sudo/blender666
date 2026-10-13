"""Portable unscaled template using asset properties verified in this project."""
from pathlib import Path
from xml.etree import ElementTree as ET

out = Path(__file__).resolve().parents[1] / "assets/weapon/CombatWeaponTemplate.rbxmx"
root = ET.Element("roblox", version="4")
def item(kind, name, parent):
    node = ET.SubElement(parent, "Item", {"class": kind, "referent": "null"})
    props = ET.SubElement(node, "Properties")
    ET.SubElement(props, "string", name="Name").text = name
    return node, props
def content(props, name, value):
    ET.SubElement(ET.SubElement(props, "Content", name=name), "url").text = value
def vector(props, name, xyz):
    node = ET.SubElement(props, "Vector3", name=name)
    for axis, value in zip("XYZ", xyz): ET.SubElement(node, axis).text = str(value)
model, _ = item("Model", "StraightSword", root)
mesh, props = item("MeshPart", "AshenOath_Greatsword", model)
content(props, "MeshId", "rbxassetid://139047510233988")
vector(props, "Size", (1.5134029388427735, 4.710000038146973, .3773673176765442))
vector(props, "MeshSize", (1.5134029388427735, 4.710000038146973, .3773673176765442))
for name, value in {"Anchored": "false", "CanCollide": "false", "CanTouch": "false", "CanQuery": "false", "Massless": "true"}.items():
    ET.SubElement(props, "bool", name=name).text = value
_, surface = item("SurfaceAppearance", "SurfaceAppearance", mesh)
for name, asset in {"ColorMap": 136130758953102, "NormalMap": 139522448011869,
                    "MetalnessMap": 97914543082669, "RoughnessMap": 104238439149413}.items():
    content(surface, name, f"rbxassetid://{asset}")
ET.ElementTree(root).write(out, encoding="utf-8", xml_declaration=True)
print(out, out.stat().st_size)
