class_name SpriteFactory
extends RefCounted
## 程序化美术工厂：零外部素材也能跑 3D 版。
##
## 两条路径共用同一套渲染方式（Sprite3D billboard）：
##   1. `sprite_path` 为空 / 加载失败 -> 用 Image 逐像素生成占位贴图
##   2. `sprite_path` 指向真实 PNG    -> 直接加载
## 所以后续接入真美术时不需要改任何渲染代码。
##
## 方向约定（重要）：所有"朝向型"网格（弧光、指示条）的本地前方都是 **+X**，
## 因此对齐朝向只需 `rotation.y = -facing.angle()`（facing 是玩法平面的 Vector2）。

static var _cache: Dictionary = {}


# ------------------------------------------------------------------ 贴图

## 圆形角色贴图。已按 cache key 去重，重复调用不会重复生成。
static func actor_texture(sprite_path: String, pixels: int, body: Color, outline: Color) -> Texture2D:
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var res: Resource = load(sprite_path)
		if res is Texture2D:
			return res
	var key := "disc|%d|%s|%s" % [pixels, body.to_html(), outline.to_html()]
	if not _cache.has(key):
		_cache[key] = _make_disc(pixels, body, outline)
	return _cache[key]


## 菱形宝石（掉落物占位）。
static func gem_texture(pixels: int, body: Color) -> Texture2D:
	var key := "gem|%d|%s" % [pixels, body.to_html()]
	if not _cache.has(key):
		_cache[key] = _make_gem(pixels, body)
	return _cache[key]


## 地面网格贴图（一个格子，上边与左边画线，平铺后形成网格）。
static func grid_texture(cell: int, ground: Color, line: Color, line_w: int = 2) -> Texture2D:
	var key := "grid|%d|%s|%s|%d" % [cell, ground.to_html(), line.to_html(), line_w]
	if not _cache.has(key):
		var img := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
		img.fill(ground)
		for i in range(cell):
			for w in range(line_w):
				img.set_pixel(i, w, line)
				img.set_pixel(w, i, line)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## 1x1 纯白贴图：血条等需要自由缩放/染色的元素用。
static func white_texture() -> Texture2D:
	if not _cache.has("white"):
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_cache["white"] = ImageTexture.create_from_image(img)
	return _cache["white"]


static func _make_disc(pixels: int, body: Color, outline: Color) -> Texture2D:
	var img := Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(pixels) * 0.5
	var outer := c - 1.0
	var ring := maxf(2.0, float(pixels) * 0.07)
	for y in range(pixels):
		for x in range(pixels):
			var dx := float(x) + 0.5 - c
			var dy := float(y) + 0.5 - c
			var d := sqrt(dx * dx + dy * dy)
			if d <= outer - ring:
				img.set_pixel(x, y, body)
			elif d <= outer:
				img.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(img)


static func _make_gem(pixels: int, body: Color) -> Texture2D:
	var img := Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(pixels) * 0.5
	var r := c - 2.0
	var edge := Color(1, 1, 1, 0.9)
	for y in range(pixels):
		for x in range(pixels):
			# L1 距离 -> 菱形
			var d := absf(float(x) + 0.5 - c) + absf(float(y) + 0.5 - c)
			if d <= r - 2.0:
				img.set_pixel(x, y, body)
			elif d <= r:
				img.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(img)


static func _disc_mask() -> Texture2D:
	if not _cache.has("disc_mask"):
		var pixels := 64
		var img := Image.create(pixels, pixels, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		var c := float(pixels) * 0.5
		var r := c - 1.0
		for y in range(pixels):
			for x in range(pixels):
				var dx := float(x) + 0.5 - c
				var dy := float(y) + 0.5 - c
				if sqrt(dx * dx + dy * dy) <= r:
					img.set_pixel(x, y, Color(1, 1, 1, 1))
		_cache["disc_mask"] = ImageTexture.create_from_image(img)
	return _cache["disc_mask"]


# ------------------------------------------------------------------ 网格 / 节点

## billboard 精灵：始终正面朝向相机。固定俯角相机下看起来就是"直立"的 2D 贴图。
## 返回的精灵底部贴地（position.y = world_height * 0.5）。
static func billboard_sprite(tex: Texture2D, world_height: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tex_h := maxf(1.0, float(tex.get_height()))
	s.pixel_size = world_height / tex_h
	s.position.y = world_height * 0.5
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


## 脚下影斑（billboard 精灵不投射真实阴影，用扁圆盘代替）。
static func blob_shadow(radius: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _disc_mask()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.38)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position.y = 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "BlobShadow"
	return mi


## 朝向指示条：本地 +X 方向的长条，用 rotation.y = -facing.angle() 对齐。
static func box_marker(size: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.7
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "FacingMarker"
	return mi


## 平躺的扇形弧光（挥砍特效）。在 XZ 平面上，本地 +X 为弧心方向。
static func arc_fx(inner_r: float, outer_r: float, half_angle: float, segments: int, color: Color) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var seg := maxi(2, segments)
	for i in range(seg):
		var a0 := lerpf(-half_angle, half_angle, float(i) / float(seg))
		var a1 := lerpf(-half_angle, half_angle, float(i + 1) / float(seg))
		var base := verts.size()
		verts.append(Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r))
		verts.append(Vector3(cos(a0) * outer_r, 0.0, sin(a0) * outer_r))
		verts.append(Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r))
		verts.append(Vector3(cos(a1) * inner_r, 0.0, sin(a1) * inner_r))
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "ArcFx"
	return mi


## 平躺半透明圆盘（冲刺残影、拾取光晕）。
static func flat_disc(radius: float, color: Color, height: float = 0.06) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.position.y = height
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 水平条（血条）。返回 {"bg": Sprite3D, "fill": Sprite3D}；
## 更新比例请用 update_bar(fill, width, ratio)，不要直接改 scale.x。
static func hp_bar(width: float, height: float, fill_color: Color) -> Dictionary:
	var bar_w := maxf(1.0, width)
	var bar_h := maxf(1.0, height)
	return {
		"bg": _bar_sprite(bar_w, bar_h, Color(0.10, 0.10, 0.12, 0.9)),
		"fill": _bar_sprite(bar_w, bar_h, fill_color),
	}


static func _bar_sprite(width: float, height: float, color: Color) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = white_texture()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.pixel_size = width
	# 1x1 贴图：宽度 = pixel_size，高度用 scale.y 调整
	s.scale = Vector3(1.0, height / width, 1.0)
	s.modulate = color
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s


## 左对齐地更新血条比例（避免从中心收缩）。
static func update_bar(fill: Sprite3D, width: float, ratio: float) -> void:
	if fill == null:
		return
	var r := clampf(ratio, 0.0, 1.0)
	fill.scale.x = r
	fill.position.x = width * (r - 1.0) * 0.5
