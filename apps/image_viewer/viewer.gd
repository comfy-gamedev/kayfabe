extends AppWindow

var document: Document: set = set_document

var _texture: ImageTexture

@onready var texture_rect: TextureRect = %TextureRect

func _ready() -> void:
	super()
	_reload()

func set_document(d: Document) -> void:
	if document == d: return
	if document:
		document.changed.disconnect(_on_document_changed)
	document = d
	if document:
		document.changed.connect(_on_document_changed)
	_reload()

func _reload() -> void:
	if not is_inside_tree(): return
	if not document:
		texture_rect.texture = null
	else:
		if not _texture:
			_texture = ImageTexture.new()
		_texture.set_image(Image.load_from_file(document.get_working_file_path()))
		texture_rect.texture = _texture

func _on_document_changed() -> void:
	_reload()
