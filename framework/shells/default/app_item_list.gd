extends Container

signal app_clicked(app_key: StringName)

const AppItemListItem = preload("res://framework/shells/default/app_item_list_item.gd")

@export var icon_size: Vector2 = Vector2(32, 32)
@export var item_minimum_width: float = 48.0

var score_func: Callable

var focused_child_index: int:
	set(v):
		v = clampi(v, 0, _filtered_items.size() - 1)
		if focused_child_index == v: return
		focused_child_index = v
		queue_redraw()

var _columns: int
var _row_height: float

var _item_scores: Dictionary
var _is_filtering: bool
var _filtered_items: Array[AppItemListItem]

var _items_by_app_key: Dictionary

var _theme_h_separation: int
var _theme_focus_style: StyleBox

func _init() -> void:
	theme_type_variation = "AppItemList"

func _ready() -> void:
	_update_theme_cache()
	theme_changed.connect(func ():
		_update_theme_cache()
		_update_layout())
	for k in AppManager.get_app_keys():
		print("App shell fsdf ", k)
		var item = AppItemListItem.new()
		item.app_key = k
		item.icon_size = icon_size
		item.clicked.connect(app_clicked.emit.bind(k))
		add_child(item)
		_items_by_app_key[k] = item
	_update_layout()
	sort_children.connect(_sort_children)

func _update_layout() -> void:
	_is_filtering = false
	_filtered_items = []
	if not score_func:
		for i in get_child_count():
			var c = get_child(i) as AppItemListItem
			c.visible = true
		focused_child_index = -1
	else:
		for i in get_child_count():
			var c = get_child(i) as AppItemListItem
			var score = score_func.call(c.app_key)
			_item_scores[c.app_key] = score
			c.visible = score > 0
			if score != 0:
				_is_filtering = true
			if score > 0:
				_filtered_items.append(c)
		_filtered_items.sort_custom(func (a, b):
			return _item_scores[a.app_key] > _item_scores[b.app_key])
		focused_child_index = 0 if not _filtered_items.is_empty() else -1
	update_minimum_size()
	queue_sort()
	queue_redraw()

func _get_minimum_size() -> Vector2:
	var result := Vector2.ZERO
	if _is_filtering:
		var n = 0
		for i in get_child_count():
			var c = get_child(i)
			if c is Control:
				if c.visible:
					result = result.max(c.get_combined_minimum_size())
					n += 1
		_columns = 1
		_row_height = result.y
		result.y *= n
	else:
		result.x = item_minimum_width
		var n = 0
		for i in get_child_count():
			var c = get_child(i)
			if c is Control:
				if c.visible:
					result = result.max(c.get_combined_minimum_size())
					n += 1
		_columns = maxi(1, ceili((size.x + _theme_h_separation) / (result.x + _theme_h_separation)))
		_row_height = result.y
		result.x = 0
		result.y *= ceilf(float(n) / _columns)
	return result

func _sort_children() -> void:
	if score_func != Callable():
		for i in _filtered_items.size():
			var item = _filtered_items[i] as AppItemListItem
			item.layout = AppItemListItem.Layout.ROW
			item.position = Vector2(0, _row_height * i)
			item.size = Vector2(size.x, _row_height)
	else:
		var col_width = size.x / _columns
		for i in get_child_count():
			var item = get_child(i) as AppItemListItem
			item.layout = AppItemListItem.Layout.GRID
			@warning_ignore("integer_division")
			item.position = Vector2(
				(i % _columns) * col_width,
				(i / _columns) * _row_height)
			item.size = Vector2(col_width, _row_height)

func _draw() -> void:
	if _theme_focus_style and _is_filtering and focused_child_index < _filtered_items.size():
		var item = _filtered_items[focused_child_index] as AppItemListItem
		_theme_focus_style.draw(get_canvas_item(), item.get_rect())

func _update_theme_cache() -> void:
	_theme_h_separation = get_theme_constant("h_separation")
	_theme_focus_style = get_theme_stylebox("focus")
