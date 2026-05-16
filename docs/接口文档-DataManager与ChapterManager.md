# DataManager / ChapterManager 接口文档（使用指南）

本文档只描述两件事：

1. **如何让数据被 `DataManager` 管理（持久化加载/保存）**
2. **chapter（章节）如何定义与在游戏中使用（`ChapterManager` + `resources/chapters.json`）**

不逐个函数写 API 说明；以“接入流程 + 约定 + 示例”为主。

---

## 0. 相关入口（单例 / Autoload）

本项目已在 `project.godot` 的 `[autoload]` 中注册：

- `Data` → `res://scripts/DataManager.gd`
- `Chapter` → `res://scripts/ChapterManager.gd`
- `GameManager` → `res://scripts/GameManager.gd`

因此脚本里可以直接使用：

- `Data.load_persistent_data(...)` / `Data.save_persistent_data()`
- `Chapter.load_chapter_data(...)` / `Chapter.new_game()` / `Chapter.advance_to_next_chapter()`

启动时加载顺序在 `GameManager._ready()` 中已经固定：

1. `Data.load_persistent_data("user:/", "persistent_data.json")`
2. `Chapter.load_chapter_data("res://resources/chapters.json")`

> 注意：这里传入的是 `"user:/"`（少一个 `/`），因为 `DataManager` 内部会再拼一个 `/`，最终文件路径会变成 `user://persistent_data.json`。

---

## 1. DataManager：如何纳入持久化管理

### 1.1 核心协议（Persist 分组 + save/load）

`DataManager` 的设计是：**把“需要持久化的节点”加入 Godot 的分组 `Persist`，并实现统一的数据协议**。

要被持久化的节点需要满足：

- 加入分组：`add_to_group("Persist")`
- 提供方法：
  - `func save_data() -> Dictionary`
  - `func load_data(data: Dictionary) -> void`

`DataManager` 保存时会：

- 遍历所有 `Persist` 分组的节点
- 调用每个节点的 `save_data()`
- 以 **节点的 `node.name`** 作为 key 写入一个大 JSON：

```json
{
  "Chapter": { "current_chapter": "prologue", "active_chapter_data": {}, "san": 100 },
  "SomeOtherSystem": { "...": "..." }
}
```

`DataManager` 加载时会：

- 读取 JSON
- 遍历 `Persist` 分组节点
- 用 `node.name` 去 JSON 里找对应数据，并调用 `load_data(对应字典)`

### 1.2 重要约定与坑位

1. **key 是 `node.name`，不是脚本类名**
   - Autoload 的名字就是节点名。例如 `Chapter="*res://scripts/ChapterManager.gd"`，因此 key 是 `"Chapter"`。
   - 如果你在 `project.godot` 里改了 Autoload 名称，历史存档里对应 key 会变，旧数据就不会被加载（当前实现会报错）。

2. **`save_data()` 返回值必须可 JSON 序列化**
   - 建议只使用：`bool/int/float/String/Array/Dictionary`（以及它们的嵌套）。
   - 不要直接塞 `Node`、`Resource`、`Callable` 之类对象。

### 1.3 最小接入示例

假设你有一个新的系统单例 `PlayerState` 也想持久化：

```gdscript
extends Node

var hp := 100
var coins := 0

func _ready() -> void:
	add_to_group("Persist")

func save_data() -> Dictionary:
	return {
		"hp": hp,
		"coins": coins,
	}

func load_data(data: Dictionary) -> void:
	hp = data.get("hp", 100)
	coins = data.get("coins", 0)
```

然后在需要保存的时机调用：

- `Data.save_persistent_data()`

项目里已有一个保存点例子：在暂停菜单回到主菜单时会调用保存（见 `scenes/gameplay/pause-layer/pause-layer.gd`）。

---

## 2. ChapterManager：章节如何定义与使用

### 2.1 chapters.json 的结构

章节定义在 `res://resources/chapters.json`。

顶层是一个 Dictionary：

- key：`chapter_id`（字符串，如 `"prologue"`、`"chapter_1"`、`"ending_1"`）
- value：该章节的定义对象

每个章节对象支持字段：

- `name`：显示名称（字符串）
- `data`：进入该章节时的**初始运行时数据**（Dictionary，可选）
- `next`：下一章节规则（Dictionary，可选；没有 `next` 视为结局/终点）

`next` 的结构：

- `expression`：一个会被 `Expression` 执行的表达式字符串，**返回值必须是下一章节的 chapter_id**
- `args`：表达式需要的变量名列表（数组），这些变量会从 `Chapter.active_chapter_data` 里取值后按顺序传入

示例（项目现有写法）：

```json
"chapter_1": {
  "name": "第一章",
  "next": {
    "expression": "next(chapter1_passed, 'chapter_2', 'ending_1')",
    "args": ["chapter1_passed"]
  },
  "data": {
    "chapter1_passed": true,
    "flag": true
  }
}
```

### 2.2 运行时状态：current / active

`ChapterManager` 有两类数据：

- `Chapter.current_chapter_id`：当前章节 ID（会被持久化）
- `Chapter.current_chapter_definition`：当前章节在 chapters.json 中的“定义”（name/next/data）
- `Chapter.active_chapter_data`：当前章节的**运行时可变数据**（会被持久化）

关键行为：

- `Chapter.new_game()`：强制把 `current_chapter_id` 设为 `"prologue"`，并把 `active_chapter_data` 重置为该章节 `data` 的深拷贝
- `Chapter.advance_to_next_chapter()`：
  - 读取当前章节的 `next`
  - 从 `active_chapter_data` 里取出 `args` 指定的变量作为表达式入参
  - 执行 `expression` 得到 `next_chapter_id`
  - 切换到目标章节，并把 `active_chapter_data` 重置为“目标章节 `data` 的深拷贝”

> 结论：**切到新章节时，运行时数据会按目标章节的 `data` 重置，因此建议把跨章节共享的数据写到ChapterManager的全局变量或其它系统的全局变量之中**。

### 2.3 表达式规则（expression + args）

当前实现要求：

- `next.args` 列出来的每个变量名，都必须存在于 `Chapter.active_chapter_data` 中
  - 否则会 `push_error("参数缺失")`
- `next.expression` 里引用的变量名必须与 `args` 对应
- 表达式最终要返回一个存在于 `chapters.json` 顶层 key 的章节 ID

项目里提供了一个辅助函数：

- `ChapterManager.next(flag, true_chapter, false_chapter)`

因此表达式可以写成类似三元：

- `next(chapter1_passed, 'chapter_2', 'ending_1')`

### 2.4 游戏中如何使用章节系统（推荐流程）

#### 新游戏

在主菜单点击“开始”时，项目会：

- `Chapter.new_game()`
- 再切换到游戏场景（见 `scenes/menu/menu.gd`）

#### 继续游戏 / 读档

启动时 `GameManager._ready()` 会先执行：

- `Data.load_persistent_data(...)`（把存档分发给 `Persist` 节点，包括 `Chapter`）
- `Chapter.load_chapter_data(...)`（加载 `chapters.json` 并用 `current_chapter_id` 初始化当前定义）

因此“继续游戏”不应再调用 `Chapter.new_game()`，否则会覆盖读档的 `current_chapter_id` / `active_chapter_data`。

#### 在章节中推进条件并切章

典型用法是：在剧情/关卡里，当玩家达成条件时更新 `active_chapter_data`，然后调用切章：

```gdscript
# 例如：第一章通关
Chapter.active_chapter_data["chapter1_passed"] = true
Chapter.advance_to_next_chapter()

# 需要时立即存档
Data.save_persistent_data()
```

### 2.5 如何定义“结局章节”

只要章节定义里**没有 `next` 字段**，它就不会有下一章。

当前 `advance_to_next_chapter()` 在遇到没有 `next` 的章节时会报错提示“是否已达到结局”。

### 2.6 章节进入信号（EventBus.enter_chapter）

项目在 `EventBus` 中定义了章节进入信号：

`enter_chapter(chapter_id: String, chapter_name: String, data: Dictionary, is_ending: bool)`

参数约定：

- `chapter_id`：章节 ID（对应 `chapters.json` 的顶层 key）
- `chapter_name`：章节名（对应章节定义里的 `name`）
- `data`：该章节当前的运行时数据（`Chapter.active_chapter_data`）
- `is_ending`：是否结局章节（通常可按“章节定义是否缺少 `next` 字段”来判断）

典型用途：

- UI/流程层在进入新章节时刷新章节标题、目标、提示等
- 触发章节切场景、加载资源、开始对话等（具体行为由监听者决定）

监听示例（任意脚本）：

```gdscript
func _ready() -> void:
  EventBus.enter_chapter.connect(_on_enter_chapter)

func _on_enter_chapter(chapter_id: String, chapter_name: String, data: Dictionary, is_ending: bool) -> void:
  print("enter_chapter:", chapter_id, chapter_name, data, is_ending)
```

---

## 3. 与 DataManager 的结合点（章节数据如何被保存）

`ChapterManager` 在 `_ready()` 中会 `add_to_group("Persist")`，并实现：

- `save_data()`：保存 `current_chapter_id`、`active_chapter_data`、`san`
- `load_data()`：读回同名字段

因此章节系统的持久化原则是：

- “当前在哪一章”由 `current_chapter_id` 决定
- “这一章的运行时变量（通过 args 驱动 expression）”存放在 `active_chapter_data`

---

## 4. 快速自检清单

当你发现章节不跳转/读档不生效时，先按顺序检查：

- `chapters.json` 是否包含目标 `chapter_id`
- 当前章节是否有 `next.expression`
- `next.args` 里列出的变量，是否都存在于 `Chapter.active_chapter_data`
- 是否在“继续游戏”路径里误调用了 `Chapter.new_game()`
- 是否在合适的时机调用了 `Data.save_persistent_data()`（否则退出即丢）
