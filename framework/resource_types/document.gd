class_name Document
extends RefCounted

var desktop_uuid: String
var uuid: String
var metadata: DocumentMetadata
var permissions: Dictionary
var name: String: get = get_name, set = set_name
var head: DocumentHead

var _cached: bool = false
var _cached_wall_time_ms: int
var _cached_modified_time: int
var _cached_content: PackedByteArray

static func create(app_id: StringName, desktop_uuid: String, file_name: String, archive_compression: Framework.CompressionMode = Framework.CompressionMode.GZIP) -> Document:
	var uuid = UUID.v7()
	
	var document_dir = Framework.get_desktop_root(desktop_uuid).path_join(Framework.DOCUMENTS_DIR).path_join(uuid)
	
	if DirAccess.dir_exists_absolute(document_dir):
		push_error("Document already exists: ", document_dir)
		return null
	
	var err = DirAccess.make_dir_absolute(document_dir)
	if err != OK:
		push_error("Failed to create document directory %s: %s" % [document_dir, error_string(err)])
		return null
	
	for d in [Framework.DOCUMENT_ARCHIVE_DIR, Framework.DOCUMENT_VERSIONS_DIR, Framework.DOCUMENT_WORKING_DIR]:
		var subdir = document_dir.path_join(d)
		err = DirAccess.make_dir_absolute(subdir)
		if err != OK:
			push_error("Failed to create document subdirectory %s: %s" % [subdir, error_string(err)])
			return null
	
	var metadata = DocumentMetadata.new()
	metadata.app_id = app_id
	metadata.extension = file_name.get_extension()
	metadata.owner = UUID.ZERO
	metadata.archive_compression = archive_compression
	var metadata_path = document_dir.path_join(Framework.DOCUMENT_METADATA_FILE)
	err = ObjectJSON.stringify_to_file(metadata, metadata_path)
	if err != OK:
		push_error("Failed to save document metadata %s: %s" % [metadata_path, error_string(err)])
		return null
	
	var head = DocumentHead.new()
	head.version_counter = 0
	var head_path = document_dir.path_join(Framework.DOCUMENT_HEAD_FILE)
	err = ObjectJSON.stringify_to_file(head, head_path)
	if err != OK:
		push_error("Failed to save document head %s: %s" % [head_path, error_string(err)])
		return null
	
	var document = Document.new()
	document.desktop_uuid = desktop_uuid
	document.uuid = uuid
	document.metadata = metadata
	
	return document

static func open(desktop_uuid: String, uuid: String) -> Document:
	var document_dir = Framework.get_desktop_root(desktop_uuid).path_join(Framework.DOCUMENTS_DIR).path_join(uuid)
	
	if not DirAccess.dir_exists_absolute(document_dir):
		push_error("Document does not exist: ", document_dir)
		return null
	
	var metadata_path = document_dir.path_join(Framework.DOCUMENT_METADATA_FILE)
	var metadata: DocumentMetadata = ObjectJSON.parse_from_file(metadata_path, DocumentMetadata)
	if not metadata:
		push_error("Invalid or missing metadata: ", metadata_path)
		return null
	
	var head_path = document_dir.path_join(Framework.DOCUMENT_HEAD_FILE)
	var head: DocumentHead = ObjectJSON.parse_from_file(head_path, DocumentHead)
	if not head:
		push_error("Invalid or missing head: ", head_path)
		return null
	
	var document = Document.new()
	document.desktop_uuid = desktop_uuid
	document.uuid = uuid
	document.metadata = metadata
	document.head = head
	
	if head.version != 0:
		var version_path = document_dir.path_join(Framework.DOCUMENT_VERSIONS_DIR).path_join("%s.json" % [head.version])
		var version: DocumentVersion = ObjectJSON.parse_from_file(version_path, DocumentVersion)
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

func get_dir() -> String:
	return Framework.get_desktop_root(desktop_uuid).path_join(Framework.DOCUMENTS_DIR).path_join(uuid)

func get_archive_dir() -> String:
	return get_dir().path_join(Framework.DOCUMENT_ARCHIVE_DIR)

func get_versions_dir() -> String:
	return get_dir().path_join(Framework.DOCUMENT_VERSIONS_DIR)

func get_working_file_path() -> String:
	return get_dir().path_join(Framework.DOCUMENT_WORKING_DIR).path_join(metadata.file_name)

func get_metadata_file_path() -> String:
	return get_dir().path_join(Framework.DOCUMENT_METADATA_FILE)

func get_head_file_path() -> String:
	return get_dir().path_join(Framework.DOCUMENT_HEAD_FILE)

func get_file_bytes() -> PackedByteArray:
	var file_path = get_working_file_path()
	
	var modified = FileAccess.get_modified_time(file_path)
	
	if _cached and modified <= _cached_modified_time:
		_cached_wall_time_ms = Time.get_ticks_msec()
		return _cached_content
	
	_cached = false
	_cached_content.clear()
	
	var fresh_load = FileAccess.get_file_as_bytes(file_path)
	
	if FileAccess.get_open_error() != OK:
		push_error("Failed to open document file %s: %s" % [file_path, error_string(FileAccess.get_open_error())])
		return PackedByteArray()
	
	_cached_content = fresh_load
	_cached_modified_time = modified
	_cached_wall_time_ms = Time.get_ticks_msec()
	_cached = true
	
	return fresh_load

func open_file(flags: FileAccess.ModeFlags) -> FileAccess:
	return FileAccess.open(get_working_file_path(), flags)

func commit_version(comment: String) -> void:
	var file_path = get_working_file_path()
	var bytes = FileAccess.get_file_as_bytes(file_path)
	var err = FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to read file %s: %s" % [file_path, error_string(err)])
		return
	
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	var sha256 = hash.finish().hex_encode()
	
	match metadata.archive_compression:
		Framework.CompressionMode.UNCOMPRESSED:
			pass
		Framework.CompressionMode.GZIP:
			bytes = bytes.compress(FileAccess.CompressionMode.COMPRESSION_GZIP)
		_:
			push_error("Unknown compression mode.")
	
	var archive_file_path = get_archive_dir().path_join(sha256)
	var i = 0
	while FileAccess.file_exists(archive_file_path):
		i += 1
		archive_file_path = get_archive_dir().path_join("%s-%s" % [sha256, i])
	var archive_file = FileAccess.open(archive_file_path, FileAccess.WRITE)
	archive_file.store_buffer(bytes)
	
	head.version += 1
	
	var version = DocumentVersion.new()
	version.sha256 = sha256 if i == 0 else "%s-%s" % [sha256, i]
	version.timestamp = int(Time.get_unix_time_from_system())
	version.permissions = permissions
	version.name = name
	version.comment = comment
	
	var version_path = get_versions_dir().path_join("%s.json" % [head.version])
	err = ObjectJSON.stringify_to_file(version, version_path)
	if err != OK:
		push_error("Failed to save version file %s: %s" % [version_path, error_string(err)])
	
	var head_path = get_head_file_path()
	err = ObjectJSON.stringify_to_file(head, head_path)
	if err != OK:
		push_error("Failed to save document head %s: %s" % [head_path, error_string(err)])
	
