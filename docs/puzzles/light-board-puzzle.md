# Light Board Puzzle System

This document describes the 5x5 light-board puzzle implementation and the art assets planned for image generation.

## Runtime Structure

Files:

- `scripts/puzzles/light_board/LightPuzzleConstants.gd`
- `scripts/puzzles/light_board/LightPieceData.gd`
- `scripts/puzzles/light_board/LightPiecePlacement.gd`
- `scripts/puzzles/light_board/LightPortData.gd`
- `scripts/puzzles/light_board/LightPuzzleData.gd`
- `scripts/puzzles/light_board/LightBeamSolver.gd`
- `scenes/gameplay/puzzles/light_board/light_puzzle_board.tscn`
- `scenes/gameplay/puzzles/light_board/light_puzzle_board.gd`
- `scenes/gameplay/puzzles/light_board/light_board_surface.gd`
- `scenes/gameplay/puzzles/light_board/light_piece_view.gd`
- `scenes/gameplay/puzzles/light_board/light_puzzle_prop.tscn`
- `scenes/gameplay/puzzles/light_board/light_puzzle_prop.gd`

The puzzle is opened from a scene prop. `LightPuzzleProp` extends the existing `Prop` interaction flow. Assign a `LightPuzzleData` resource to the prop, then press the existing interact action in-game.

Completion emits:

- `LightPuzzleBoard.puzzle_solved(puzzle_id)`
- `EventBus.puzzle_light_solved(puzzle_id)`

## Board Rules

The board uses a fixed 5x5 grid by default. Coordinates are zero-based:

```text
x: 0 1 2 3 4
y
0  . . . . .
1  . . . . .
2  . . . . .
3  . . . . .
4  . . . . .
```

Light uses exact 45-degree directions:

```text
E, SE, S, SW, W, NW, N, NE
```

Refraction is discrete and deterministic:

```text
+45: E->SE, SE->S, S->SW, SW->W, W->NW, NW->N, N->NE, NE->E
-45: E->NE, NE->N, N->NW, NW->W, W->SW, SW->S, S->SE, SE->E
```

Dragging works like a sliding-block puzzle:

- A piece moves one axis at a time.
- It snaps to grid cells.
- It cannot pass through occupied cells.
- Transparent glass blocks occupy cells and restrict movement, but light passes through them.
- `allowed_cells` can further constrain an individual piece.
- `move_axis` can restrict a piece to horizontal, vertical, both, or locked.

## Current Piece Types

| Piece | Meaning |
| --- | --- |
| `MirrorSlash` | `/` reflection |
| `MirrorBackslash` | `\` reflection |
| `PrismPlus45` | exact +45 degree refraction |
| `PrismMinus45` | exact -45 degree refraction |
| `FilterRed` | passes red only |
| `FilterGreen` | passes green only |
| `FilterBlue` | passes blue only |
| `FilterYellow` | passes red + green |
| `FilterCyan` | passes green + blue |
| `FilterMagenta` | passes red + blue |
| `GlassBlock` | transparent movement blocker |
| `OpaqueBlock` | absorbs light |

## Example Puzzles

Resources:

- `resources/puzzles/light_board/red_foldback.tres`
- `resources/puzzles/light_board/blue_prism_z.tres`
- `resources/puzzles/light_board/green_dual_filter_chain.tres`

### Red Foldback

White light enters from the left at `y=1` and must exit downward from the bottom edge at `x=4` as exact red.

Solution layout:

```text
. . . T .
. R \ T .
. . - . .
T . . - \
. T . . .
```

### Blue Prism Z

White light enters diagonally from the northwest corner and must exit through the top edge at `x=4` as exact blue.

Solution layout:

```text
- B \ . .
T T - . .
. . T - /
. T . . .
. . . T .
```

### Green Dual Filter Chain

White light is first narrowed by a yellow filter, then green is isolated late in the route. The exit is the southeast corner and requires exact green with exact `SE` direction.

Solution layout:

```text
Y + . T .
. T - \ .
. . T G .
T . . - .
. . T . .
```

## Planned Image Assets

Recommended folder:

```text
assets/images/puzzles/light_board/
```

All board-piece assets should be square PNGs, generated with generous padding. Prefer transparent final PNGs for pieces; if using the default image pipeline, generate on a flat chroma-key background and remove the key color locally.

### Required Core Assets

| File | Size | Purpose |
| --- | --- | --- |
| `board_panel.png` | 1024x1024 | The carved/etched puzzle board background |
| `cell_slot_empty.png` | 256x256 | One empty grid socket |
| `piece_mirror_slash.png` | 512x512 | `/` mirror tile |
| `piece_mirror_backslash.png` | 512x512 | `\` mirror tile |
| `piece_prism_plus_45.png` | 512x512 | +45 refraction tile |
| `piece_prism_minus_45.png` | 512x512 | -45 refraction tile |
| `piece_filter_red.png` | 512x512 | Red filter tile |
| `piece_filter_green.png` | 512x512 | Green filter tile |
| `piece_filter_blue.png` | 512x512 | Blue filter tile |
| `piece_filter_yellow.png` | 512x512 | Yellow filter tile |
| `piece_glass_block.png` | 512x512 | Transparent movement blocker |
| `piece_opaque_block.png` | 512x512 | Optional absorbing black tile |
| `light_source_white.png` | 512x512 | White source emitter |
| `exit_red.png` | 512x512 | Red exit marker |
| `exit_green.png` | 512x512 | Green exit marker |
| `exit_blue.png` | 512x512 | Blue exit marker |
| `beam_white.png` | 512x128 | White beam segment texture |
| `beam_red.png` | 512x128 | Red beam segment texture |
| `beam_green.png` | 512x128 | Green beam segment texture |
| `beam_blue.png` | 512x128 | Blue beam segment texture |
| `beam_yellow.png` | 512x128 | Yellow beam segment texture |
| `beam_cyan.png` | 512x128 | Cyan beam segment texture |
| `beam_magenta.png` | 512x128 | Magenta beam segment texture |
| `piece_hover_glow.png` | 512x512 | Hover/selected glow |
| `solved_flash.png` | 1024x1024 | Completion light burst overlay |

### Optional Narrative Props

| File | Size | Purpose |
| --- | --- | --- |
| `world_prop_light_board_idle.png` | 512x512 | In-room object before interaction |
| `world_prop_light_board_solved.png` | 512x512 | In-room object after solve |
| `puzzle_frame_corner.png` | 256x256 | Decorative UI frame corner |
| `puzzle_frame_edge.png` | 256x256 | Decorative UI frame edge |

## Shared Art Direction

Use this as the base style for image generation:

```text
Use case: stylized-concept
Asset type: 2D game puzzle asset
Primary request: a single optical puzzle tile for a top-down 2D Godot game
Style/medium: hand-painted stylized game art, clean readable silhouette, subtle painterly texture
Composition/framing: centered square tile, orthographic top-down, generous padding
Lighting/mood: dim classroom mystery mood, soft cool rim light, gentle internal glow
Color palette: deep charcoal board material, glass cyan highlights, restrained saturated optical colors
Materials/textures: worn dark metal, smoky glass, polished mirror, beveled edges
Constraints: no text, no watermark, no UI labels, no perspective tilt, readable at 64x64
Avoid: photorealism, heavy ornament, clutter, background scene, cast shadow beyond the tile
```

For transparent piece assets, add:

```text
Create the subject on a perfectly flat solid #00ff00 chroma-key background for background removal.
The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation.
Do not use #00ff00 anywhere in the subject.
```

## Individual Prompt Notes

- Mirror slash: diagonal reflective strip from bottom-left to top-right.
- Mirror backslash: diagonal reflective strip from top-left to bottom-right.
- Prism +45: triangular glass prism with a small clockwise angle cue built into the shape, no text.
- Prism -45: triangular glass prism with a small counter-clockwise angle cue built into the shape, no text.
- Filters: colored glass square with a subtle spectral rim; color must dominate but remain readable on a dark board.
- Glass block: nearly transparent blue-tinted slab with etched grid lines; should look like an obstacle, not a usable optical element.
- Opaque block: black obsidian-like absorber tile with no glow.
- Beam segments: horizontal luminous streaks on transparent/chroma-key background, soft center core and colored bloom.
