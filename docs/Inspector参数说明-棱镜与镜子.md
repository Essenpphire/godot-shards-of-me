# Inspector 参数说明 - 棱镜与镜子

本文说明两个可独立导入的子场景在 Godot Inspector 中的主要参数用途：

- `res://scenes/gameplay/puzzles/prism/prism_reveal.tscn`
- `res://scenes/gameplay/puzzles/mirror_word/mirror_word_lock.tscn`

只写常用参数和调参顺序，不展开脚本实现细节。

## 1. 棱镜 `prism_reveal.tscn`

### Chapter

- `san_loss_per_turn`
  - 每次开始拖动或点击旋转时减少的 SAN 值。

### Rotation

- `target_rotation_deg`
  - 棱镜目标角度，单位是度。
  - 运行时拖拽、点击步进、键盘输入都会改这个目标值。
- `enable_keyboard_rotation`
  - 是否允许用键盘调试旋转棱镜。
- `turn_speed_deg_per_sec`
  - 画面上的棱镜追向目标角度的速度，单位 `deg/s`。
  - 值越大越接近瞬间旋转，值越小越慢。
- `keyboard_rotation_speed_deg_per_sec`
  - 键盘输入改变目标角度的速度，单位 `deg/s`。
- `drag_rotation_sensitivity_deg_per_px`
  - 鼠标拖拽改变目标角度的灵敏度，单位 `deg/px`。
  - 太快就调小，常见可用范围是 `0.05` 到 `0.15`。
- `interaction_mode`
  - `Drag`：按住棱镜左右拖动。
  - `Click Step`：每次点击棱镜旋转固定角度。
- `click_step_deg`
  - `Click Step` 模式下每次点击增加的目标角度。

### Reveal

- `revealed_texture`
  - 棱镜中被映照/显现出来的 2D 图。
  - 不填时会继续使用场景里的临时演示图。
- `revealed_clue_id`
  - 显现文字对应的线索 ID。
- `collect_revealed_clue_with_interact`
  - 是否在玩家进入范围、文字足够清晰时显示 E 提示。
  - 按 E 后会把 `revealed_clue_id` 收入线索书。
- `auto_collect_revealed_clue`
  - 是否在文字足够清晰时自动加入线索书。
  - 默认关闭；需要无按键收集时再打开。
- `clue_collect_alpha_threshold`
  - 允许按 E 收集/自动收集所需的显现透明度阈值。
  - 值越高，必须越接近最佳角度才会收入线索书。
- `best_reveal_angle_deg`
  - 棱镜转到哪个角度时，隐藏物最清晰。
- `reveal_tolerance_deg`
  - 允许显现的角度窗口。
  - 值越小，必须转得越准才会出现。
  - 值越大，显现区域越宽。
- `min_reveal_alpha`
  - 未对准时的最低透明度。
- `max_reveal_alpha`
  - 完全对准时的最高透明度。

### Presentation

- `render_viewport_size`
  - 内部 `SubViewport` 分辨率。
  - 想让棱镜边缘更细腻，可以适当调大。
- `prism_mesh_size`
  - 3D 棱镜尺寸。
- `prism_body_color`
  - 棱镜主体颜色。
- `prism_outline_color`
  - 棱镜外壳/高光颜色。
- `render_camera_distance`
  - 相机远近。
  - 数值越大，透视变化越弱，物体看起来越平。
- `render_topdown_ratio`
  - 相机俯视强度。
  - 越大越俯视。
  - 若想更贴近 2.5D 顶斜视，可在 `0.16` 到 `0.30` 之间试。

### 推荐调参顺序

1. 先调 `render_topdown_ratio` 和 `render_camera_distance`
2. 再调 `prism_mesh_size`
3. 再调 `best_reveal_angle_deg`
4. 最后调 `reveal_tolerance_deg`、`drag_rotation_sensitivity_deg_per_px` 和 `turn_speed_deg_per_sec`

---

## 2. 镜子 `mirror_word_lock.tscn`

这个场景的核心逻辑是：

- 只有镜内图像，没有镜外切片
- 镜内图像透明度由玩家到某个世界坐标定点的距离决定
- 透明度达到阈值后显示 E，按 E 收入线索书

### Player Tracking

- `tracked_player_path`
  - 手动指定玩家节点。
  - 如果不填，脚本会尝试从 `Player` 组自动找。
- `find_player_in_group`
  - 是否自动从 `Player` 组找玩家。
- `reveal_world_point`
  - 显现定点的世界坐标。
  - 玩家越靠近这个点，镜内内容越清晰。
- `full_alpha_distance`
  - 玩家距离定点小于等于这个值时，透明度达到最高。
- `fade_distance`
  - 玩家距离定点大于等于这个值时，透明度降到最低。

### Mirror Layout

- `mirror_view_size`
  - 镜内显示区域宽高。
- `mirror_frame_thickness`
  - 镜框厚度。

### Content

- `mirror_texture`
  - 镜内图使用的源图。
- `fallback_texture_size`
  - 当没有手动指定图片、回退到内部 `Viewport` 演示图时使用的尺寸。
- `source_region_position`
  - 镜内图从源图哪个坐标开始裁切。
  - 留空(0,0)时，如果源图比 `mirror_view_size` 大，会自动取源图中心区域。
- `fallback_text`
  - 仅用于内部演示图，不影响正式贴图。

### Reveal

- `hidden_alpha`
  - 玩家远离定点时的最低透明度。
- `shown_alpha`
  - 玩家靠近定点时的最高透明度。
- `clue_collect_alpha_threshold`
  - 允许按 E 收集所需的透明度阈值。
  - 默认 `0.9`，也就是 90%。
- `revealed_clue_id`
  - 透明度达标后按 E 收入线索书的线索 ID。

### State

- `starts_already_collected`
  - 初始是否已经收集。
  - 适合用在剧情后续场景，避免玩家重复解谜。

### 推荐调参顺序

1. 先放好镜子场景位置
2. 设置 `mirror_texture` 和 `mirror_view_size`
3. 设置 `reveal_world_point`
4. 调 `full_alpha_distance` 和 `fade_distance`
5. 设置 `revealed_clue_id`

### 常见问题

#### 镜子没有显现

- `tracked_player_path` 是否填对
- 玩家是否在 `Player` 组
- `reveal_world_point` 是否填在玩家可到达的位置附近
- `fade_distance` 是否太小

#### 已经能看见但不能按 E

- `clue_collect_alpha_threshold` 是否高于当前透明度
- `revealed_clue_id` 是否为空
