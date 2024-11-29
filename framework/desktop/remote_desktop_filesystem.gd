class_name RemoteDesktopFilesystem
extends DesktopFilesystem

var _documents: Dictionary # { [document_uuid: StringName]: RemoteDocument }

static func create(server_desktop_metadata: DesktopMetadata) -> RemoteDesktopFilesystem:
	assert(UUID.is_valid(server_desktop_metadata.uuid))
	
	server_desktop_metadata = server_desktop_metadata.duplicate()
	server_desktop_metadata.uuid = "R-" + server_desktop_metadata.uuid
	
	print("Loading filesystem: ", server_desktop_metadata.uuid)
	
	var desktop_dir = Framework.get_desktop_dir(server_desktop_metadata.uuid)
	if not DirAccess.dir_exists_absolute(desktop_dir):
		_initialize_directory(server_desktop_metadata)
	
	var metadata_path = Framework.get_desktop_metadata_file(server_desktop_metadata.uuid)
	var err = JsonResource.save_json(server_desktop_metadata, metadata_path)
	if err != OK:
		push_error("Failed to save metadata %s: %s" % [metadata_path, error_string(err)])
		return null
	
	var filesystem = RemoteDesktopFilesystem.new()
	filesystem.name = "DesktopFilesystem"
	filesystem.metadata = server_desktop_metadata
	
	return filesystem

func _ready() -> void:
	_request_refresh_rpc.rpc_id(1)

func get_thumbnail_file_path() -> String:
	return Framework.get_desktop_thumbnail_file(metadata.uuid)

func list(tags: Array[StringName] = []) -> PackedStringArray:
	var results := PackedStringArray()
	
	if not tags:
		results = _documents.keys()
	else:
		for doc_uuid: StringName in _documents:
			var doc: RemoteDocument = _documents[doc_uuid]
			var accepted := true
			var doc_tags := doc.get_tags()
			for tag: StringName in tags:
				if tag not in doc_tags:
					accepted = false
					break
			if accepted:
				results.append(doc_uuid)
	
	return results

func create_empty(file_name: String) -> RemoteDocument:
	push_error("Not supported.")
	return null

func open(document_uuid: StringName) -> RemoteDocument:
	var doc: RemoteDocument = _documents.get(document_uuid)
	return doc

func import(_path: String) -> RemoteDocument:
	push_error("Not supported.")
	return null

func _update_head_rpc(document_uuid: StringName, metadata_pack: Dictionary, head_pack: Dictionary, version_pack: Dictionary) -> void:
	print("RemoteDesktopFilesystem._update_head_rpc(%s, %s, %s, %s)" % [document_uuid, metadata_pack, head_pack, version_pack])
	
	var doc: RemoteDocument
	var doc_metadata: DocumentMetadata = JsonResource.unpack(metadata_pack, DocumentMetadata)
	var doc_head: DocumentHead = JsonResource.unpack(head_pack, DocumentHead)
	var doc_version: DocumentVersion = JsonResource.unpack(version_pack, DocumentVersion)
	
	if document_uuid not in _documents:
		print("RemoteDesktopFilesystem._update_head_rpc: Creating new document ", document_uuid)
		doc = RemoteDocument.create(desktop_uuid, document_uuid, doc_metadata, doc_head, doc_version)
		_documents[doc.uuid] = doc
		document_added.emit(doc)
	else:
		doc = _documents[document_uuid]
		
		var err: Error
		
		var version_path = Framework.get_document_version_file(desktop_uuid, document_uuid, doc_head.version)
		err = JsonResource.save_json(doc_version, version_path)
		if err != OK:
			push_error("Error saving version %s: %s" % [version_path, error_string(err)])
			return
		
		var head_path = Framework.get_document_head_file(desktop_uuid, document_uuid)
		err = JsonResource.save_json(doc_head, head_path)
		if err != OK:
			push_error("Error saving head %s: %s" % [head_path, error_string(err)])
			return
		
		var metadata_path = Framework.get_document_metadata_file(desktop_uuid, document_uuid)
		err = JsonResource.save_json(doc_metadata, metadata_path)
		if err != OK:
			push_error("Error saving metadata %s: %s" % [metadata_path, error_string(err)])
			return
		
		doc.version = doc_version
		doc.head = doc_head
		doc.metadata = doc_metadata
		doc.is_outdated = true
		doc.version_changed.emit()
