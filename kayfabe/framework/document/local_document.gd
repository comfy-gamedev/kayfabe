class_name LocalDocument
extends Document

static func create(p_desktop_uuid: String, file_name: String) -> LocalDocument:
	assert(not p_desktop_uuid.begins_with("R-"))
	
	var new_uuid = UUID.v7()
	
	var document_dir = Framework.get_document_dir(p_desktop_uuid, new_uuid)
	
	if DirAccess.dir_exists_absolute(document_dir):
		push_error("Document already exists: ", document_dir)
		return null
	
	var err = DirAccess.make_dir_absolute(document_dir)
	if err != OK:
		push_error("Failed to create document directory %s: %s" % [document_dir, error_string(err)])
		return null
	
	for d in [Framework.DOCUMENT_VERSIONS_DIR, Framework.DOCUMENT_WORKING_DIR]:
		var subdir = document_dir.path_join(d)
		err = DirAccess.make_dir_absolute(subdir)
		if err != OK:
			push_error("Failed to create document subdirectory %s: %s" % [subdir, error_string(err)])
			return null
	
	var new_metadata = DocumentMetadata.new()
	new_metadata.file_name = file_name
	new_metadata.owner = UUID.ZERO
	new_metadata.created_timestamp = int(Time.get_unix_time_from_system())
	var metadata_path = Framework.get_document_metadata_file(p_desktop_uuid, new_uuid)
	err = JsonResource.save_json(new_metadata, metadata_path)
	if err != OK:
		push_error("Failed to save document metadata %s: %s" % [metadata_path, error_string(err)])
		return null
	
	var new_head = DocumentHead.new()
	new_head.version = 0
	var head_path = Framework.get_document_head_file(p_desktop_uuid, new_uuid)
	err = JsonResource.save_json(new_head, head_path)
	if err != OK:
		push_error("Failed to save document head %s: %s" % [head_path, error_string(err)])
		return null
	
	var new_version = DocumentVersion.new()
	new_version.sha256 = ""
	new_version.timestamp = int(Time.get_unix_time_from_system())
	new_version.permissions = {}
	new_version.name = file_name
	new_version.comment = "INITIAL"
	var version_path = Framework.get_document_version_file(p_desktop_uuid, new_uuid, 0)
	err = JsonResource.save_json(new_version, version_path)
	if err != OK:
		push_error("Failed to save version file %s: %s" % [version_path, error_string(err)])
		return err
	
	var working_file_path = Framework.get_document_working_dir(p_desktop_uuid, new_uuid).path_join(file_name)
	assert(not FileAccess.file_exists(working_file_path))
	var file = FileAccess.open(working_file_path, FileAccess.WRITE)
	if not file:
		err = FileAccess.get_open_error()
		push_error("Failed to create working file %s: %s" % [working_file_path, error_string(err)])
		return null
	file.close()
	
	var document = LocalDocument.new()
	document.desktop_uuid = p_desktop_uuid
	document.uuid = new_uuid
	document.metadata = new_metadata
	document.head = new_head
	document.version = new_version
	
	return document

static func open(p_desktop_uuid: String, p_uuid: String) -> Document:
	assert(not p_desktop_uuid.begins_with("R-"))
	
	var document_dir = Framework.get_document_dir(p_desktop_uuid, p_uuid)
	
	if not DirAccess.dir_exists_absolute(document_dir):
		push_error("Document does not exist: ", document_dir)
		return null
	
	var metadata_path = Framework.get_document_metadata_file(p_desktop_uuid, p_uuid)
	var existing_metadata: DocumentMetadata = JsonResource.load_json(metadata_path, DocumentMetadata)
	if not existing_metadata:
		push_error("Invalid or missing metadata: ", metadata_path)
		return null
	
	var head_path = Framework.get_document_head_file(p_desktop_uuid, p_uuid)
	var existing_head: DocumentHead = JsonResource.load_json(head_path, DocumentHead)
	if not existing_head:
		push_error("Invalid or missing head: ", head_path)
		return null
	
	var version_path = Framework.get_document_version_file(
		p_desktop_uuid, p_uuid, existing_head.version)
	var existing_version: DocumentVersion = JsonResource.load_json(version_path, DocumentVersion)
	if not existing_version:
		push_error("Invalid or missing head: ", version_path)
		return null
	
	var document = LocalDocument.new()
	document.desktop_uuid = p_desktop_uuid
	document.uuid = p_uuid
	document.metadata = existing_metadata
	document.head = existing_head
	document.version = existing_version
	
	return document

func _ensure_latest_working_copy_async() -> void:
	# Local documents are always considered up-to-date.
	pass

func put_content_async(content: PackedByteArray, comment: String) -> Error:
	if _cached_content_updating:
		await cache_updated
	assert(_cached_content_updating == false)
	
	var working_file_path = _get_working_file_path()
	
	var backup_index = 1
	var backup_file_path = "%s.%s.backup" % [working_file_path, backup_index]
	while FileAccess.file_exists(backup_file_path):
		backup_index += 1
		backup_file_path = "%s.%s.backup" % [working_file_path, backup_index]
	
	var err = DirAccess.rename_absolute(working_file_path, backup_file_path)
	if err != OK:
		return err
	
	var file = FileAccess.open(working_file_path, FileAccess.WRITE)
	if not file:
		err = FileAccess.get_open_error()
		push_error("Failed to open file for writing: %s (%s)" % [working_file_path, error_string(err)])
		DirAccess.rename_absolute(backup_file_path, working_file_path)
		return err
	file.store_buffer(content)
	file.close()
	err = file.get_error()
	if err != OK:
		push_error("Failed to write file: %s (%s)" % [working_file_path, error_string(err)])
		DirAccess.rename_absolute(backup_file_path, working_file_path)
		return err
	file = null
	
	err = _commit_version(comment)
	if err != OK:
		DirAccess.rename_absolute(backup_file_path, working_file_path)
		return err
	
	DirAccess.remove_absolute(backup_file_path)
	
	_clear_cache()
	
	_cached_content_tick_msec = Time.get_ticks_msec()
	_cached_content = content.duplicate()
	cache_updated.emit()
	
	return OK

func _commit_version(comment: String) -> Error:
	var content = FileAccess.get_file_as_bytes(_get_working_file_path())
	var err = FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to read working file %s: %s", [_get_working_file_path(), error_string(err)])
		return err
	
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	if content.size() > 0:
		ctx.update(content)
	var sha256 = ctx.finish().hex_encode()
	
	if not Desktop.current.filesystem.archive_file_exists(sha256):
		# TODO: dynamically select compression mode
		var compression = DesktopFilesystem.CompressionMode.NONE
		err = Desktop.current.filesystem.write_archive_file(sha256, content, compression)
		if err != OK:
			push_error("Failed to write archive file %s: %s" % [sha256, error_string(err)])
			return err
	
	var next_head = head.duplicate()
	next_head.version += 1
	
	var next_version = version.duplicate()
	next_version.sha256 = sha256
	next_version.timestamp = int(Time.get_unix_time_from_system())
	next_version.comment = comment
	
	var version_path = Framework.get_document_versions_dir(desktop_uuid, uuid).path_join("%s.json" % [next_head.version])
	err = JsonResource.save_json(next_version, version_path)
	if err != OK:
		push_error("Failed to save version file %s: %s" % [version_path, error_string(err)])
		return err
	
	var head_path = Framework.get_document_head_file(desktop_uuid, uuid)
	err = JsonResource.save_json(next_head, head_path)
	if err != OK:
		push_error("Failed to save document head %s: %s" % [head_path, error_string(err)])
		return err
	
	head = next_head
	version = next_version
	version_changed.emit()
	
	return OK
