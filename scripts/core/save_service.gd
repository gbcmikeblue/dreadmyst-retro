class_name SaveService
extends Node
## 存档服务：3 个槽位的读写 / 删除 / 摘要 + 防抖自动保存。
##
## 职责边界（重要）：
##   - 本节点只做**文件 IO + 结构序列化**，**不认识 Player / Game**：
##     真正「谁该把状态交出来」由 `main.gd` 负责（它是唯一同时知道 Game 与 Player 的地方），
##     通过 `state_provider` 这个 Callable 注入。
##   - 自动保存的「何时该存」由本节点判断（它监听 `Events` 里那几个会改状态的事件），
##     2 秒防抖后调 `state_provider` 收状态再落盘。
##
## 关键健壮性：
##   - **原子写**：先写 `<file>.tmp` → 旧档改名 `.bak` → tmp 改名正式档 → 删 `.bak`。
##     任何一步挂掉都不会留下半截正式档。
##   - **读取回退链**：正式档 → `.bak` → `.tmp`，从回退档读出来后立刻写回正式档。
##   - **坏档不静默删**：解析失败 / 空文件 / 版本不支持 → 改名 `<file>.corrupt-<时间戳>` 保留。
##   - `path_pattern` 可注入：自测用独立文件，不污染正式存档。

const SLOT_COUNT := 3
const DEFAULT_PATH_PATTERN := "user://save_%d.json"
## 状态变化后多久落盘（秒）。用防抖而不是每次事件都写：连捡 5 件只写一次。
const AUTOSAVE_DELAY := 2.0

## 路径模板，`%d` = 槽位号（1..SLOT_COUNT）。自测会换成 test 专用模板。
var path_pattern: String = DEFAULT_PATH_PATTERN
## 当前槽位。-1 = 还没在标题界面选槽，此时**不记账也不落盘**。
var current_slot: int = -1
## 收状态的钩子，由 main.gd 注入：调用后应返回一份填好的 SaveData。
var state_provider: Callable = Callable()

var _dirty_left: float = -1.0


func _ready() -> void:
	name = "SaveService"
	# 这几个事件都会改变「值得存下来」的状态（升级 / 金币 / 换装 / 分解买卖拾取 / 属性点 / 进出地城）
	Events.player_level_changed.connect(_on_level_changed)
	Events.gold_changed.connect(_on_gold_changed)
	Events.equipment_changed.connect(_on_equipment_changed)
	Events.backpack_changed.connect(_on_backpack_changed)
	Events.attributes_changed.connect(_on_attributes_changed)
	Events.dungeon_entered.connect(_on_dungeon_entered)
	Events.dungeon_exited.connect(_on_dungeon_exited)


## 有状态变化时开始/续上防抖计时。没选槽（current_slot < 0）时不记，免得标题界面期间白写盘。
func _process(delta: float) -> void:
	if _dirty_left < 0.0:
		return
	_dirty_left -= delta
	if _dirty_left > 0.0:
		return
	_dirty_left = -1.0
	flush_current()


func _on_level_changed(_level: int, _xp: int, _xp_next: int) -> void:
	mark_dirty()


func _on_gold_changed(_amount: int) -> void:
	mark_dirty()


func _on_equipment_changed(_equipment: Dictionary) -> void:
	mark_dirty()


func _on_backpack_changed(_items: Array, _capacity: int) -> void:
	mark_dirty()


func _on_attributes_changed(_attributes: Dictionary, _free: int, _spent: int) -> void:
	mark_dirty()


func _on_dungeon_entered(_display_name: String, _room_count: int) -> void:
	mark_dirty()


func _on_dungeon_exited() -> void:
	mark_dirty()


# ---------------------------------------------------------------- 自动保存

func mark_dirty() -> void:
	if current_slot < 0:
		return
	_dirty_left = AUTOSAVE_DELAY


func has_pending_write() -> bool:
	return _dirty_left >= 0.0


## 立刻把当前槽写盘（退出时调用，绕过防抖）。返回是否真的写了。
func flush_current() -> bool:
	if current_slot < 0:
		return false
	if not state_provider.is_valid():
		push_warning("SaveService: 未注入 state_provider，跳过写盘")
		return false
	_dirty_left = -1.0
	var data: Variant = state_provider.call()
	if data == null or not (data is SaveData):
		push_warning("SaveService: state_provider 没有返回 SaveData，跳过写盘")
		return false
	return write_slot(current_slot, data)


# ---------------------------------------------------------------- 槽位

func slot_path(slot: int) -> String:
	return path_pattern % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## 全部槽位的摘要，给标题选档界面用。下标 0..SLOT_COUNT-1 对应槽位 1..SLOT_COUNT。
func slot_summaries() -> Array:
	var out: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		out.append(slot_summary(slot))
	return out


func slot_summary(slot: int) -> Dictionary:
	var path := _readable_path(slot)
	if path.is_empty():
		return SaveData.summary_from_dict({}, false)
	var parsed: Variant = _parse_json_dict(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return SaveData.summary_from_dict({}, false)
	var summary := SaveData.summary_from_dict(parsed, true)
	summary["slot"] = slot
	return summary


## 读一个槽位。返回 null = 没有存档或存档坏了（坏档已改名保留）。
func load_slot(slot: int) -> SaveData:
	if slot < 1 or slot > SLOT_COUNT:
		return null
	var path := _readable_path(slot)
	if path.is_empty():
		return null
	var parsed: Variant = _parse_json_dict(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup_corrupt(path)
		Events.toast.emit("存档 %d 已损坏，已备份为 .corrupt 并新建" % slot,
			Color(1.0, 0.72, 0.35))
		return null
	var data := SaveData.from_dict(parsed)
	if not data.is_supported_version():
		_backup_corrupt(path)
		Events.toast.emit("存档 %d 版本为 %d（当前 %d），已备份并新建" % [
			slot, data.version, SaveData.CURRENT_VERSION], Color(1.0, 0.72, 0.35))
		return null
	# 从 .bak / .tmp 里捞回来的，立刻写回正式档
	if path != slot_path(slot):
		write_slot(slot, data)
	return data


## 写一个槽位（原子写）。成功返回 true。
func write_slot(slot: int, data: SaveData) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	if data == null:
		return false
	data.version = SaveData.CURRENT_VERSION
	if data.saved_at.is_empty():
		data.saved_at = Time.get_datetime_string_from_system()
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: 打不开 %s（%s）" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data.to_dict(), "  "))
	file.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveService: 打不开 user:// 目录")
		return false
	# 旧档先退到 .bak：Godot 的 rename 不会覆盖已存在文件，这样就不必先删正式档
	if dir.file_exists(path.get_file()):
		if dir.file_exists(path.get_file() + ".bak"):
			dir.remove(path.get_file() + ".bak")
		var err_backup := dir.rename(path.get_file(), path.get_file() + ".bak")
		if err_backup != OK:
			push_error("SaveService: 备份旧档失败 %d" % err_backup)
	if dir.rename(tmp.get_file(), path.get_file()) != OK:
		push_error("SaveService: 替换存档失败（%s）" % path)
		return false
	dir.remove(path.get_file() + ".bak")
	return true


func delete_slot(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	var existed := has_save(slot)
	var dir := DirAccess.open("user://")
	if dir != null:
		for suffix in ["", ".bak", ".tmp"]:
			# 注意别把局部变量叫 name（会遮蔽 Node.name，触发 SHADOWED_VARIABLE_BASE_CLASS 警告）
			var file_name: String = (path_pattern % slot).get_file() + String(suffix)
			if dir.file_exists(file_name):
				dir.remove(file_name)
	return existed


# ---------------------------------------------------------------- 内部

## 解析 JSON 文本成 Dictionary。失败（空文本 / 语法错 / 类型不是对象）一律返回 null。
##
## ⚠️ 这里用 `JSON` **实例**而不是 `JSON.parse_string()`：后者解析失败时会往 stderr
## 打一条引擎级 `ERROR: Parse JSON failed`。存档损坏是**预期内**的情况（手改 / 半截文件），
## 不该在日志里刷红，更不该破坏「0 ERROR / 0 WARNING」的验收口径。
static func _parse_json_dict(text: String) -> Variant:
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## 读取回退链：正式档 → .bak → .tmp。都没有返回 ""。
func _readable_path(slot: int) -> String:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		return path
	if FileAccess.file_exists(path + ".bak"):
		return path + ".bak"
	if FileAccess.file_exists(path + ".tmp"):
		return path + ".tmp"
	return ""


## 坏档不静默删：改名成 <file>.corrupt-<时间戳> 留证据。
func _backup_corrupt(path: String) -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var file_name := path.get_file()
	var target := "%s.corrupt-%s" % [file_name, str(Time.get_unix_time_from_system())]
	dir.rename(file_name, target)
