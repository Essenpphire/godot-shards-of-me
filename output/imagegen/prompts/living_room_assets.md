# Living Room Image2 Generation Plan

Reference image folder: `C:\Users\bulbel\Downloads\第一章\image`

Primary style anchors:
- `background_classroom_1.png`
- `background_classroom_1_inside.png`
- `background_classroom_pillar.png`
- `wall_classroom_1.png`

Shared style DNA:
- 2D side-scrolling game asset.
- Pixel-art inspired hand-painted illustration.
- Simple composition, muted low-saturation colors.
- Thin dark gray outlines, slightly pixel-stepped edges.
- Soft ambient lighting, no dramatic shadows.
- Aged but clean school/interior wall texture.
- No text, no watermark, no people, no photorealism, no 3D render.

## 1. Living Room Wall Background

Output path:

`output/imagegen/living-room/living_room_wall_background.png`

Mode:

`edit`, using the classroom wall reference image.

Prompt:

```text
Transform the reference classroom wall into a simple living room front wall background layer for a 2D side-scrolling Godot game.

Keep the same visual language as the reference: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient light, subtle aged wall texture.

Create a flat front-facing living room wall only. The wall is warm ivory / milk-white. Include one or two simple windows with curtains, using the classroom window and curtain style as the main reference. The curtains should be simple, muted gray or pale green-gray, with the same slightly pixelated folds and dark outline style.

Composition must be orthographic and front-facing, like a reusable 2D background wall layer. Leave clean empty wall space for placing furniture in front.

Important constraints: no floor, no side walls, no furniture, no characters, no text, no watermark, no strong perspective, no realistic photo look, no 3D render, no dramatic lighting.
```

Command:

```powershell
python 'C:\Users\bulbel\.codex\skills\.system\imagegen\scripts\image_gen.py' edit --image 'C:\Users\bulbel\Downloads\第一章\image\background_classroom_1.png' --prompt-file 'output\imagegen\prompts\living_room_wall_background.txt' --size 1536x864 --quality high --output-format png --out 'output\imagegen\living-room\living_room_wall_background.png'
```

## 2. Potted Plant

Output path:

`output/imagegen/living-room/living_room_potted_plant_key.png`

Prompt:

```text
Create a transparent-ready 2D living room potted plant asset for a side-scrolling Godot game.

Subject: one simple indoor potted green plant in a muted terracotta or warm ivory pot. It should fit naturally in front of the living room wall background.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, simple readable silhouette. Match the visual language of the provided chapter 1 school interior references.

Place the plant on a perfectly flat solid #ff00ff chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated from the background with crisp edges and generous padding. Do not use #ff00ff anywhere in the subject.

Constraints: no photorealism, no 3D render, no text, no watermark, no floor, no room background, no extra objects.
```

## 3. Sofa, Facing Left

Output path:

`output/imagegen/living-room/living_room_sofa_left_key.png`

Prompt:

```text
Create a transparent-ready 2D sofa asset for a side-scrolling Godot living room scene.

Subject: a simple fabric sofa in a three-quarter oblique side view, facing left. Low, cozy, clean shape, muted beige or pale gray-green fabric, simple cushions, no patterns or text.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, simple readable silhouette. Match the visual language of the provided chapter 1 school interior references.

Place the sofa on a perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated from the background with crisp edges and generous padding. Do not use #00ff00 anywhere in the subject.

Constraints: no photorealism, no 3D render, no text, no watermark, no floor, no wall background, no people, no extra objects.
```

## 4. Sofa, Facing Right

Output path:

`output/imagegen/living-room/living_room_sofa_right_key.png`

Prompt:

```text
Create a transparent-ready 2D sofa asset for a side-scrolling Godot living room scene.

Subject: a simple fabric sofa in a three-quarter oblique side view, facing right. Low, cozy, clean shape, muted beige or pale gray-green fabric, simple cushions, no patterns or text.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, simple readable silhouette. Match the visual language of the provided chapter 1 school interior references.

Place the sofa on a perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated from the background with crisp edges and generous padding. Do not use #00ff00 anywhere in the subject.

Constraints: no photorealism, no 3D render, no text, no watermark, no floor, no wall background, no people, no extra objects.
```

## 5. Sofa, Front Slight Oblique

Output path:

`output/imagegen/living-room/living_room_sofa_front_oblique_key.png`

Prompt:

```text
Create a transparent-ready 2D sofa asset for a side-scrolling Godot living room scene.

Subject: a simple fabric sofa in a mostly front-facing view with a slight oblique angle. Low, cozy, clean shape, muted beige or pale gray-green fabric, simple cushions, no patterns or text.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, simple readable silhouette. Match the visual language of the provided chapter 1 school interior references.

Place the sofa on a perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated from the background with crisp edges and generous padding. Do not use #00ff00 anywhere in the subject.

Constraints: no photorealism, no 3D render, no text, no watermark, no floor, no wall background, no people, no extra objects.
```

## 6. TV And TV Cabinet

Output path:

`output/imagegen/living-room/living_room_tv_cabinet_key.png`

Prompt:

```text
Create a transparent-ready 2D TV and TV cabinet asset for a side-scrolling Godot living room scene.

Subject: a simple flat-screen television sitting on a low TV cabinet, shown in a three-quarter oblique side view. The TV screen is dark gray/black and blank. The cabinet is muted warm wood or warm ivory, simple rectangular design, no logos, no visible text.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, simple readable silhouette. Match the visual language of the provided chapter 1 school interior references.

Place the TV and cabinet on a perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated from the background with crisp edges and generous padding. Do not use #00ff00 anywhere in the subject.

Constraints: no photorealism, no 3D render, no text, no watermark, no floor, no wall background, no people, no extra objects, no image on the TV screen.
```

## 7. Wooden Coffee Table

Output path:

`output/imagegen/living-room/living_room_wood_coffee_table_key.png`

Prompt:

```text
Create a transparent-ready 2D wooden coffee table asset for a side-scrolling Godot living room scene.

Subject: a simple low rectangular wooden coffee table in a three-quarter oblique side view. Muted warm wood color, clean shape, modest thickness, no tablecloth, no clutter.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, simple readable silhouette. Match the visual language of the provided chapter 1 school interior references.

Place the coffee table on a perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated from the background with crisp edges and generous padding. Do not use #00ff00 anywhere in the subject.

Constraints: no photorealism, no 3D render, no text, no watermark, no floor, no wall background, no people, no extra objects.
```

## 8. Wall Clock

Output path:

`output/imagegen/living-room/living_room_wall_clock_key.png`

Prompt:

```text
Create a transparent-ready 2D wall clock asset for a side-scrolling Godot living room scene.

Subject: a small simple round wall clock, front-facing, designed to be placed on the living room wall. Muted ivory or gray frame, simple hands. Avoid readable numbers; use minimal marks only.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, simple readable silhouette. Match the visual language of the provided chapter 1 school interior references.

Place the wall clock on a perfectly flat solid #00ff00 chroma-key background for background removal. The background must be one uniform color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the subject fully separated from the background with crisp edges and generous padding. Do not use #00ff00 anywhere in the subject.

Constraints: no photorealism, no 3D render, no text, no watermark, no wall background, no extra objects, no brand marks.
```

## 9. Left Oblique Stretch Wall

Output path:

`output/imagegen/living-room/living_room_left_oblique_wall_key.png`

Mode:

`edit`, using the wall module reference image.

Prompt:

```text
Transform the reference wall module into a left-side oblique stretch wall module that matches the new living room wall background.

The asset should look like a milk-white / warm ivory living room wall extending diagonally toward the left side, suitable as a side wall boundary module in a 2D Godot scene. It should preserve the transparent-background module logic of the reference wall image.

Style: pixel-art inspired hand-painted 2D illustration, low-saturation colors, thin dark gray outlines, slightly pixel-stepped edges, soft ambient lighting, subtle aged wall texture. Match the living room wall background and the chapter 1 school interior references.

Constraints: transparent outside the wall module, no floor, no furniture, no window, no right-side wall, no text, no watermark, no photorealism, no 3D render.
```

