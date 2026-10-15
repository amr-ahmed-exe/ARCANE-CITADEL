# Executed inside Blender via execute_blender_code after setting ASSET_NAME
import bpy, os

os.makedirs("assets/3d", exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
for obj in bpy.context.selected_objects:
    if obj.type == 'MESH':
        obj.location = (0.0, 0.0, 0.0)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

bpy.ops.export_scene.fbx(
    filepath=f"assets/3d/{ASSET_NAME}.fbx",
    use_selection=True,
    axis_forward='-Z',
    axis_up='Y',
    apply_scale_options='FBX_SCALE_ALL'
)
