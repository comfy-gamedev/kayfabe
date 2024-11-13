class_name Document
extends RefCounted

var desktop_uuid: String
var uuid: String
var metadata: DocumentMetadata
var permissions: Dictionary
var name: String: get = get_name, set = set_name
var tags: PackedStringArray
var head: DocumentHead

var _cached: bool = false
var _cached_tick_msec: int
var _cached_modified_time: int
var _cached_content: PackedByteArray
var _cached_sha256: String = ""

static func create(desktop_uuid: String, file_name: String, archive_compression: Framework.CompressionMode = Framework.CompressionMode.GZIP) -> Document:
	var uuid = UUID.v7()
	
	var document_dir = Framework.get_document_dir(desktop_uuid, uuid)
	
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
	
	var metadata = DocumentMetadata.new()
	metadata.file_name = file_name
	metadata.owner = UUID.ZERO
	metadata.archive_compression = archive_compression
	metadata.created_timestamp = int(Time.get_unix_time_from_system())
	var metadata_path = Framework.get_document_metadata_file(desktop_uuid, uuid)
	err = JsonResource.save_json(metadata, metadata_path)
	if err != OK:
		push_error("Failed to save document metadata %s: %s" % [metadata_path, error_string(err)])
		return null
	
	var head = DocumentHead.new()
	head.version = 0
	var head_path = Framework.get_document_head_file(desktop_uuid, uuid)
	err = JsonResource.save_json(head, head_path)
	if err != OK:
		push_error("Failed to save document head %s: %s" % [head_path, error_string(err)])
		return null
	
	var working_file_path = Framework.get_document_working_dir(desktop_uuid, uuid).path_join(file_name)
	assert(not FileAccess.file_exists(working_file_path))
	var file = FileAccess.open(working_file_path, FileAccess.WRITE)
	if not file:
		err = FileAccess.get_open_error()
		push_error("Failed to create working file %s: %s" % [working_file_path, error_string(err)])
		return null
	file.close()
	
	var document = Document.new()
	document.desktop_uuid = desktop_uuid
	document.uuid = uuid
	document.metadata = metadata
	document.head = head
	
	document.commit_version("INITIAL")
	
	return document

static func open(desktop_uuid: String, uuid: String) -> Document:
	var document_dir = Framework.get_document_dir(desktop_uuid, uuid)
	
	if not DirAccess.dir_exists_absolute(document_dir):
		push_error("Document does not exist: ", document_dir)
		return null
	
	var metadata_path = Framework.get_document_metadata_file(desktop_uuid, uuid)
	var metadata: DocumentMetadata = JsonResource.load_json(metadata_path, DocumentMetadata)
	if not metadata:
		push_error("Invalid or missing metadata: ", metadata_path)
		return null
	
	var head_path = Framework.get_document_head_file(desktop_uuid, uuid)
	var head: DocumentHead = JsonResource.load_json(head_path, DocumentHead)
	if not head:
		push_error("Invalid or missing head: ", head_path)
		return null
	
	var document = Document.new()
	document.desktop_uuid = desktop_uuid
	document.uuid = uuid
	document.metadata = metadata
	document.head = head
	
	if head.version != 0:
		var version_path = Framework.get_document_versions_dir(desktop_uuid, uuid).path_join("%s.json" % [head.version])
		var version: DocumentVersion = JsonResource.load_json(version_path, DocumentVersion)
		if not version:
			push_error("Invalid or missing version: ", version_path)
			return null
		document.permissions = version.permissions
		document.name = version.name
	
	return document

func get_name() -> String:
	return name if name else metadata.file_name 

func set_name(v: String) -> void:
	if name == v: return
	name = v
	commit_version("NAME_CHANGED")

func get_working_file_path() -> String:
	return Framework.get_document_working_dir(desktop_uuid, uuid).path_join(metadata.file_name)

func get_file_bytes() -> Variant:
	var err = _update_cache()
	
	if err != OK:
		return null
	
	return _cached_content

func get_sha256() -> String:
	var bytes = get_file_bytes()
	
	if bytes == null:
		return ""
	
	if not _cached_sha256:
		var hash = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		_cached_sha256 = hash.finish().hex_encode()
	
	return _cached_sha256

func open_file(flags: FileAccess.ModeFlags) -> FileAccess:
	if flags & FileAccess.ModeFlags.WRITE:
		_clear_cache()
	return FileAccess.open(get_working_file_path(), flags)

func commit_version(comment: String) -> Error:
	var sha256 = get_sha256()
	
	if sha256 == "":
		push_error("Failed to get hash.")
		return ERR_INVALID_DATA
	
	var archive_dir = Framework.get_desktop_archive_dir(desktop_uuid)
	if not DirAccess.dir_exists_absolute(archive_dir):
		push_warning("Archive dir not found, repairing: ", archive_dir)
		var err = DirAccess.make_dir_recursive_absolute(archive_dir)
		if err != OK:
			push_error("Failed to repair archive_dir %s: %s" % [archive_dir, error_string(err)])
			return err
		
	var archive_file_path = archive_dir.path_join(sha256)
	
	if not FileAccess.file_exists(archive_file_path):
		var bytes = get_file_bytes()
		if bytes == null:
			push_error("Failed to read file.")
			return ERR_INVALID_DATA
		
		match metadata.archive_compression:
			Framework.CompressionMode.UNCOMPRESSED:
				pass
			Framework.CompressionMode.GZIP:
				bytes = bytes.compress(FileAccess.CompressionMode.COMPRESSION_GZIP)
			_:
				push_error("Invalid archive_compression: %s" % [metadata.archive_compression])
				return ERR_INVALID_DATA
		
		var archive_file = FileAccess.open(archive_file_path, FileAccess.WRITE)
		archive_file.store_buffer(bytes)
		archive_file.close()
		var err = archive_file.get_error()
		if err != OK:
			push_error("Failed to write archive file %s: %s" % [archive_file_path, error_string(err)])
			return err
	
	head.version += 1
	
	var version = DocumentVersion.new()
	version.sha256 = sha256
	version.timestamp = int(Time.get_unix_time_from_system())
	version.permissions = permissions
	version.name = name
	version.comment = comment
	
	var version_path = Framework.get_document_versions_dir(desktop_uuid, uuid).path_join("%s.json" % [head.version])
	var err = JsonResource.save_json(version, version_path)
	if err != OK:
		push_error("Failed to save version file %s: %s" % [version_path, error_string(err)])
		return err
	
	var head_path = Framework.get_document_head_file(desktop_uuid, uuid)
	err = JsonResource.save_json(head, head_path)
	if err != OK:
		push_error("Failed to save document head %s: %s" % [head_path, error_string(err)])
		return err
	
	return OK

func _clear_cache() -> void:
	_cached = false
	_cached_tick_msec = 0
	_cached_content.clear()
	_cached_sha256 = ""

func _update_cache() -> Error:
	var file_path = get_working_file_path()
	
	var modified = FileAccess.get_modified_time(file_path)
	
	if _cached and modified <= _cached_modified_time:
		_cached_tick_msec = Time.get_ticks_msec()
		return OK
	
	_clear_cache()
	
	var fresh_load = FileAccess.get_file_as_bytes(file_path)
	var err = FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to open document file %s: %s" % [file_path, error_string(err)])
		return err
	
	_cached_content = fresh_load
	_cached_modified_time = modified
	_cached_tick_msec = Time.get_ticks_msec()
	_cached = true
	
	return OK
