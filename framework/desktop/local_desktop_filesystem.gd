class_name LocalDesktopFilesystem
extends DesktopFilesystem

var _documents: Dictionary # { [document_uuid: StringName]: LocalDocument }

static func create(p_desktop_uuid: StringName) -> LocalDesktopFilesystem:
	assert(UUID.is_valid(p_desktop_uuid))
	
	var existing_metadata = JsonResource.load_json(
		Framework.get_desktop_metadata_file(p_desktop_uuid), DesktopMetadata)
	if not existing_metadata:
		push_error("Failed to load metadata.")
		return null
	
	var filesystem = LocalDesktopFilesystem.new()
	filesystem.name = "DesktopFilesystem"
	filesystem.metadata = existing_metadata
	
	return filesystem

func _ready() -> void:
	_refresh_documents()

func get_thumbnail_file_path() -> String:
	return Framework.get_desktop_thumbnail_file(metadata.uuid)

func list(tags: Array[StringName] = []) -> PackedStringArray:
	var results := PackedStringArray()
	
	if not tags:
		results = _documents.keys()
	else:
		for doc_uuid: StringName in _documents:
			var doc: LocalDocument = _documents[doc_uuid]
			var accepted := true
			var doc_tags := doc.get_tags()
			for tag: StringName in tags:
				if tag not in doc_tags:
					accepted = false
					break
			if accepted:
				results.append(doc_uuid)
	
	return results

func create_empty(file_name: String) -> LocalDocument:
	var doc = LocalDocument.create(desktop_uuid, file_name)
	if not doc:
		return null
	doc.version_changed.connect(_on_version_changed.bind(doc.uuid))
	_documents[doc.uuid] = doc
	document_added.emit(doc)
	_broadcast_head(doc)
	return doc

func _broadcast_head(doc: LocalDocument) -> void:
	_update_head_rpc.rpc(
		doc.uuid,
		JsonResource.pack(doc.metadata),
		JsonResource.pack(doc.head),
		JsonResource.pack(doc.version))

func _on_version_changed(document_uuid: StringName) -> void:
	var document := _documents.get(document_uuid) as LocalDocument
	_broadcast_head(document)

func open(document_uuid: StringName) -> LocalDocument:
	var doc: LocalDocument = _documents.get(document_uuid)
	if not doc:
		_refresh_documents()
		doc = _documents.get(document_uuid)
	return doc

func import(path: String) -> LocalDocument:
	var src = FileAccess.get_file_as_bytes(path)
	var err = FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to import %s: %s" % [path, error_string(err)])
		return null
	var doc = LocalDocument.create(desktop_uuid, path.get_file())
	await doc.put_content_async(src, "IMPORT")
	doc.version_changed.connect(_on_version_changed.bind(doc.uuid))
	_documents[doc.uuid] = doc
	document_added.emit(doc)
	_broadcast_head(doc)
	return doc

func _refresh_documents() -> void:
	for dir: String in DirAccess.get_directories_at(Framework.get_desktop_documents_dir(desktop_uuid)):
		var doc_uuid: StringName = dir
		if doc_uuid in _documents:
			continue
		if not UUID.is_valid(doc_uuid):
			push_error("Invalid document directory: ", doc_uuid)
			continue
		var doc = LocalDocument.open(metadata.uuid, doc_uuid)
		if not doc:
			push_error("Invalid document: ", doc_uuid)
			continue
		doc.version_changed.connect(_on_version_changed.bind(doc.uuid))
		_documents[doc_uuid] = doc
		document_added.emit(doc)

func _request_refresh_rpc() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	for doc_uuid: StringName in _documents:
		var document := _documents.get(doc_uuid) as LocalDocument
		_update_head_rpc.rpc_id(peer_id,
			doc_uuid,
			JsonResource.pack(document.metadata),
			JsonResource.pack(document.head),
			JsonResource.pack(document.version))

func _commit_rpc(document_uuid: StringName, new_sha256: String, comment: String) -> void:
	var document:  = _documents.get(document_uuid) as LocalDocument
	if not document:
		return
	document.put_content_async(read_archive_file(new_sha256), comment)
