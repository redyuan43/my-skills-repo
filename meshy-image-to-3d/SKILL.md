---
name: meshy-image-to-3d
description: Convert one cleanly previewed object image into Meshy 3D output via the Meshy MCP server. Use when the user asks to generate 3D from an image with Meshy, wants background cleanup before Meshy, or invokes $meshy-image-to-3d. Produces a human preview page first, then after explicit confirmation calls Meshy image-to-3d and downloads GLB plus print-ready OBJ.
---

# Meshy Image to 3D

Use this skill for image-to-3D jobs that should pass a clean-background image into Meshy.

## Workflow

1. Resolve the user's input image to an absolute local path.
2. Run the preview script:

```bash
python3 ~/.codex/skills/meshy-image-to-3d/scripts/prepare_preview.py /absolute/path/to/image.jpg --open
```

3. Read the JSON output. It includes:
   - `clean_image`: transparent PNG to send to Meshy
   - `white_image`: white-background preview
   - `html`: preview page opened for the user
   - `output_dir`: preview artifact directory
4. Stop before spending Meshy credits. Ask the user to confirm that the previewed clean image should be used.
5. After confirmation, create a dedicated output folder under `~/Desktop/meshy-3d/<run-id>/`.
6. Call Meshy MCP tools in this order:
   - `meshy_image_to_3d`
   - `meshy_get_task_status`
   - `meshy_download_model` twice
7. Run the post-processing checks below before reporting completion.

## Meshy Defaults

Use these default generation arguments unless the user says otherwise:

```json
{
  "file_path": "<clean_image>",
  "ai_model": "latest",
  "target_formats": ["glb", "obj"],
  "should_texture": true,
  "image_enhancement": true,
  "remove_lighting": true,
  "response_format": "json"
}
```

Wait for completion with:

```json
{
  "task_id": "<task_id>",
  "task_type": "image-to-3d",
  "wait": true,
  "timeout_seconds": 300,
  "response_format": "json"
}
```

Download:

```json
{
  "task_id": "<task_id>",
  "task_type": "image-to-3d",
  "format": "glb",
  "include_textures": true,
  "save_to": "~/Desktop/meshy-3d/<run-id>/model.glb"
}
```

```json
{
  "task_id": "<task_id>",
  "task_type": "image-to-3d",
  "format": "obj",
  "include_textures": true,
  "print_ready": true,
  "print_height_mm": 75,
  "save_to": "~/Desktop/meshy-3d/<run-id>/model_print_ready.obj"
}
```

Use absolute paths for `save_to`.

## Output Location

- Always create a dedicated folder under `~/Desktop/meshy-3d/` for generated model files.
- Use a meaningful run id, for example `~/Desktop/meshy-3d/coco_love_robot_20260523/` or `~/Desktop/meshy-3d/<run-id>/`.
- Keep all related outputs together in that folder: source preview, GLB, OBJ, MTL, textures, STL, repaired STL, scaled STL, Bambu/3MF exports, and preview screenshots.
- Do not scatter generated files directly on the Desktop unless the user explicitly asks for a copy there.

## Post-Processing for 3D Printing

Always help the user find the right local files and launch the next tool when they ask about viewing, repairing, slicing, Bambu Studio, multicolor printing, or forgotten 3D workflow steps.

### Size and units

- STL files do not store units. Slicers usually interpret raw STL numbers as millimeters.
- Meshy STL exports may import far too large. Check dimensions with `trimesh` when available:

```bash
python3 - <<'PY'
import trimesh
p = "/absolute/path/to/model.stl"
m = trimesh.load_mesh(p, process=False)
print("extents:", m.extents.tolist())
print("bounds:", m.bounds.tolist())
PY
```

- If needed, create a print-ready STL by scaling to the requested height, centering on XY, and placing the bottom at `Z=0`.
- For figurines, default to `75mm` height unless the user specifies another size.
- Meshy `meshy_download_model` can make OBJ print-ready with `print_ready:true` and `print_height_mm:75`; still verify dimensions locally.

### OBJ textures

- OBJ textures require the OBJ, MTL, and texture image to live together.
- If the OBJ references a missing `.mtl`, create one that matches the OBJ `usemtl` name and points `map_Kd` at the downloaded base color PNG.
- Example for Meshy output:

```mtl
newmtl Material.005
Ka 1.000000 1.000000 1.000000
Kd 1.000000 1.000000 1.000000
Ks 0.000000 0.000000 0.000000
d 1.000000
illum 2
map_Kd model_print_ready_base_color.png
```

### Preview on Ubuntu

- Preferred quick viewer on this Ubuntu machine: `f3d`.
- Install if missing:

```bash
sudo apt-get update && sudo apt-get install -y f3d
```

- Open a textured OBJ or GLB:

```bash
f3d /absolute/path/to/model_print_ready.obj
```

- Generate a screenshot preview:

```bash
f3d /absolute/path/to/model_print_ready.obj \
  --output=/absolute/path/to/previews/f3d_obj_preview.png \
  --resolution=1200,900
```

- Use F3D for fast visual checks, Bambu Studio for slicing and multicolor conversion, and Blender only when texture editing or format repackaging is needed.

### STL repair

- If the STL shows wrong faces, holes, non-manifold geometry, or slicing defects, use Formware Online STL Repair:
  - https://www.formware.co/onlinestlrepair
- Upload the STL, download the repaired STL, then re-check dimensions before importing to Bambu Studio.
- Formware repair is for geometry. STL has no texture; use OBJ/GLB for texture-driven multicolor workflows.

### Bambu Studio

- Bambu Studio is available as `bambu-studio` on this machine.
- Open a model directly:

```bash
bambu-studio /absolute/path/to/model_print_ready.obj
```

- Bambu Studio 2.7 supports Texture-to-Color Painting for textured models. Prefer OBJ+MTL+PNG or GLB for testing multicolor conversion.
- If using OBJ, keep `.obj`, `.mtl`, and texture `.png` in the same folder before launching Bambu Studio.
- After import, use Texture-to-Color Painting, map the resulting colors to AMS/filament slots, then inspect the sliced preview.

## Preconditions

- Meshy MCP server must be configured in `~/.codex/config.toml` as `mcp_servers.meshy`.
- `MESHY_API_KEY` must be a real Meshy key, not `msy_YOUR_KEY`.
- The preview script may create `~/.cache/codex-meshy-image-to-3d/venv` and install `rembg`, `pillow`, and `onnxruntime` on first use.

## Safety

- Never call Meshy before preview confirmation; Meshy image-to-3D costs credits.
- Do not manually base64 encode image files. Pass `file_path` to the MCP tool.
- If background removal fails, report the error and do not call Meshy.
- If GLB succeeds but OBJ download fails, report the GLB path and the OBJ failure separately.
