# Plonk

> Drop assets into your Godot 4 world — fast.

[![Godot 4.1+](https://img.shields.io/badge/Godot-4.1%2B-478CBF?logo=godotengine)](https://godotengine.org/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![GDScript](https://img.shields.io/badge/Language-GDScript-355E9B)](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/)

**Repository:** [github.com/youssof20/plonk-godot](https://github.com/youssof20/plonk-godot)

A lightweight, open-source 3D asset placement plugin for Godot 4.
Browse your asset folder, pick a mesh, and click to place — with surface snapping,
vertex alignment, paint mode, and MultiMesh support built in.

## Install

1. Copy `addons/plonk/` into your project's `addons/` folder.
2. Project → Project Settings → Plugins → Enable **Plonk**.
3. The Plonk dock appears on the left panel.

## Placement modes

| Mode | How it works |
|------|-------------|
| Free | Hovers on a horizontal plane at any height |
| Grid | Snaps to a configurable XZ grid with a live overlay |
| Surface | Raycasts onto any physics surface, seats flush |
| Vertex | Corner-to-corner snap like Blender |

## License

MIT — free to use in personal and commercial projects.
