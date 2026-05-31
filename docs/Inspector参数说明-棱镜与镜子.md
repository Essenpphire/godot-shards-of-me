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

- 玩家在镜子 `x` 范围内移动时，镜内图像按规则偏移
- 玩家到达对齐区间后，镜内图像锁定
- 镜外右侧那块固定图像和镜内图像拼成完整内容

### Player Tracking

- `tracked_player_path`
  - 手动指定玩家节点。
  - 如果不填，脚本会尝试从 `Player` 组自动找。
- `lock_player_world_x`
  - 玩家走到哪个世界坐标 `x` 时，判定为“拼合完成”。
  - 这是世界坐标，不是镜子局部坐标。
- `lock_window_width`
  - 锁定区间宽度。
  - 玩家 `x` 落在这个窗口内，就会锁定镜面。
  - 想要更严格的解谜体验，就调小。
- `reflection_move_range_px`
  - 镜内图像总共允许移动多远。
  - 只在手动模式下有明显作用；若启用同尺寸自动对齐，脚本会优先使用自动推导值。
- `find_player_in_group`
  - 是否自动从 `Player` 组找玩家。

### Mirror Layout

- `mirror_view_size`
  - 镜内显示区域宽高。
- `outside_view_size`
  - 镜外右侧那块“真墙面”显示区域宽高。
  - 这会直接影响自动对齐计算。
- `mirror_outside_gap`
  - 镜内与镜外之间的间隔宽度。
- `mirror_frame_thickness`
  - 镜框厚度。

### Content

- `mirror_texture`
  - 镜内图使用的源图。
- `outside_texture`
  - 镜外右侧固定图使用的源图。
- `fallback_texture_size`
  - 当没有手动指定图片、回退到内部 `Viewport` 演示图时使用的尺寸。
- `source_region_y`
  - 从源图的哪个 `y` 开始裁切。
  - 源图上下没对齐时，优先调这个。
- `aligned_mirror_source_x`
  - 手动模式下，镜内图在“完全拼合”时的源图起点 `x`。
- `outside_source_origin_x`
  - 手动模式下，镜外右侧图相对公共原点的源图 `x` 偏移。
- `auto_align_same_origin_images`
  - 如果打开，并且镜内/镜外两张图宽度相同：
  - 脚本会默认把两张图当作“同尺寸、同原点”的完整图。
  - 自动推导镜内终点和镜外偏移。
  - 优先用于“给两张同样大的图，只想让它自动拼起来”的场景。
- `fallback_text`
  - 仅用于内部演示图，不影响正式贴图。

### State

- `starts_already_locked`
  - 初始是否已经解开并锁定。
  - 适合用在剧情后续场景，避免玩家重复解谜。

### 推荐用法 A：两张同样大的完整图

适用于：

- 镜内图和镜外图尺寸完全相同
- 两张图内容共用同一个绘制原点

建议设置：

1. 把图分别填到 `mirror_texture` 和 `outside_texture`
2. 打开 `auto_align_same_origin_images`
3. 先只调 `outside_view_size`
4. 再调场景里镜外切片的位置和 `mirror_outside_gap`
5. 最后用 `lock_player_world_x`、`lock_window_width` 控制解谜触发位置

这时一般不需要手动调 `aligned_mirror_source_x` 和 `outside_source_origin_x`。

### 推荐用法 B：手动对齐

适用于：

- 两张图不是同尺寸
- 两张图不是同一个源图原点
- 想精确控制镜内终点和镜外取样位置

建议设置：

1. 关闭 `auto_align_same_origin_images`
2. 手动设置 `aligned_mirror_source_x`
3. 手动设置 `outside_source_origin_x`
4. 视需要调 `reflection_move_range_px`

### 常见问题

#### 镜子不跟玩家动

优先检查：

- `tracked_player_path` 是否填对
- 玩家是否在 `Player` 组
- 玩家是否真的进入了镜子 `x` 范围

#### 镜内外始终拼不上

优先检查：

1. `outside_view_size.x` 是否等于右侧真墙显示宽度
2. 两张图是否真的是同尺寸、同原点
3. 若不是，关闭 `auto_align_same_origin_images` 后手动调 `aligned_mirror_source_x` 和 `outside_source_origin_x`

#### 玩家刚靠近就直接锁定

优先检查：

- `lock_player_world_x` 是否落在镜子有效范围内
- `lock_window_width` 是否太大
