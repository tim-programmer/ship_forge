# Ship Forge

A Godot 4 tool that builds textured spaceships from sliders.

1. Install Godot 4 (standard build, not .NET) from https://godotengine.org/download
2. Project Manager -> Import -> select this folder's `project.godot` -> Open
3. Press F5.

Left-drag orbits, wheel zooms. Randomize rolls a new ship. "Export .glb" writes the
model (with its textures embedded) plus PNGs and a params JSON to the `user://exports`
folder; the path is printed in the panel. Import the .glb into any engine or Blender.

Files:
- `ship_mesh.gd`    geometry: fuselage profile, wings, canards, fins, engines, greebles
- `ship_texture.gd` procedural albedo + emission texture
- `main.gd`         scene, orbit camera, UI. Add a new slider by adding a row to `SLIDERS`.
