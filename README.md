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

## Quick start

1. **Library** — Set the asset folder (Browse…), optionally narrow formats or search.
2. **Pick** — Click a thumbnail → green banner appears, ghost follows your cursor in the 3D view.
3. **Place** — Click in the viewport to stamp. Keeps placing until **RMB** or **ESC**.
4. **Refine** — Everything below the thumbnails is optional: modes, randomisation, paint, collision, etc.

| Key / action | Effect |
|---|---|
| **Click thumbnail** | Pick asset, start ghost |
| **Ctrl+click thumbnail** | Add/remove from paint pool (amber dot) |
| **Click in 3D view** | Stamp |
| **Alt+Click in 3D view** | Stamp and auto-select for immediate transform |
| **Hold LMB** (paint mode) | Stroke-paint |
| **Space** (when idle) | Re-pick last used asset |
| **RMB / ESC** | Cancel placement |
| **Alt+scroll** in 3D | Nudge height offset (Shift = larger step) |
| **Ctrl+scroll** over thumbnails | Resize thumbnail cards |

Thumbnails load lazily so big folders stay usable. **Ctrl+scroll** over the thumbnail grid changes card size. **Alt+scroll** in the 3D view nudges **height offset** (hold **Shift** for larger steps).

## Placement modes

| Mode | How it works |
|------|-------------|
| Free | Hovers on a horizontal plane at any height |
| Grid | Snaps to a configurable XZ grid with a live overlay |
| Surface | Raycasts onto any physics surface, seats flush |
| Vertex | Corner-to-corner snap like Blender |

When vertex snap locks, a **cyan line** links the matching ghost corner to the scene corner in the viewport.

## Features at a glance

| Feature | What it does |
|---|---|
| **Surface default** | Assets seat flush on physics surfaces — no more floating props |
| **Multi-asset pool** | Ctrl+click multiple thumbnails; each stamp picks randomly — natural-looking scatter in one brush stroke |
| **Paint mode** | Hold LMB to stroke-plant assets along your cursor path |
| **Slope filter** | Set max slope° to skip walls/ceilings during paint |
| **Erase mode** | Toggle on, click near any placed asset to remove it (undoable) |
| **MultiMesh paint** | All painted instances share one draw call — huge performance win |
| **Collision wrap** | Auto-add StaticBody/RigidBody/Area3D per placement |
| **Replace selected** | Select nodes in scene tree → "Replace Selected" swaps them for the current asset, keeping transforms |
| **Parent node** | Target any node as placement parent — no more everything-at-root mess |
| **Undo/redo** | Full EditorUndoRedoManager support for every operation |
| **Session counter** | Live `[N]` count in the banner so you know how many you've placed |
| **Alt+click** | Place and immediately select the new node for manual tweaks |
| **Space** | Re-pick last used asset without touching the thumbnail browser |

**MultiMesh paint** batches instances for performance; it does **not** auto-generate per-instance collision bodies (use single placement + collision, or add bodies manually).

## License

MIT — free to use in personal and commercial projects.
