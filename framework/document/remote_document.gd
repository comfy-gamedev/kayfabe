class_name RemoteDocument
extends Document

const TRACE = true

var is_outdated: bool = true

static func create(p_desktop_uuid: StringName, p_uuid: StringName, p_metadata: DocumentMetadata, p_head: DocumentHead, head_version: DocumentVersion) -> RemoteDocument:
	assert(UUID.is_valid(p_desktop_uuid))
	
	var document_dir = Framework.get_document_dir(p_desktop_uuid, p_uuid)
	
	var err = DirAccess.make_dir_recursive_absolute(document_dir)
	if err != OK:
		push_error("Failed to create document directory %s: %s" % [document_dir, error_string(err)])
		return null
	
	for d in [Framework.DOCUMENT_VERSIONS_DIR, Framework.DOCUMENT_WORKING_DIR]:
		var subdir = document_dir.path_join(d)
		err = DirAccess.make_dir_recursive_absolute(subdir)
		if err != OK:
			push_error("Failed to create document subdirectory %s: %s" % [subdir, error_string(err)])
			return null
	
	var metadata_path = Framework.get_document_metadata_file(p_desktop_uuid, p_uuid)
	err = JsonResource.save_json(p_metadata, metadata_path)
	if err != OK:
		push_error("Failed to save document metadata %s: %s" % [metadata_path, error_string(err)])
		return null
	
	var head_path = Framework.get_document_head_file(p_desktop_uuid, p_uuid)
	err = JsonResource.save_json(p_head, head_path)
	if err != OK:
		push_error("Failed to save document head %s: %s" % [head_path, error_string(err)])
		return null
	
	var version_path = Framework.get_document_version_file(p_desktop_uuid, p_uuid, p_head.version)
	err = JsonResource.save_json(head_version, version_path)
	if err != OK:
		push_error("Failed to save version file %s: %s" % [version_path, error_string(err)])
		return err
	
	var working_file_path = Framework.get_document_working_dir(p_desktop_uuid, p_uuid).path_join(p_metadata.file_name)
	var file = FileAccess.open(working_file_path, FileAccess.WRITE)
	if not file:
		err = FileAccess.get_open_error()
		push_error("Failed to create working file %s: %s" % [working_file_path, error_string(err)])
		return null
	file.close()
	
	var document = RemoteDocument.new()
	document.desktop_uuid = p_desktop_uuid
	document.uuid = p_uuid
	document.metadata = p_metadata
	document.head = p_head
	document.version = head_version
	
	return document

static func open(p_desktop_uuid: String, p_uuid: String) -> RemoteDocument:
	assert(p_desktop_uuid.begins_with("R-"))
	
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
	
	var version_path = Framework.get_document_version_file(p_desktop_uuid, p_uuid, existing_head.version)
	var existing_version: DocumentVersion = JsonResource.load_json(version_path, DocumentVersion)
	if not existing_version:
		push_error("Invalid or missing head: ", version_path)
		return null
	
	var document = Document.new()
	document.desktop_uuid = p_desktop_uuid
	document.uuid = p_uuid
	document.metadata = existing_metadata
	document.head = existing_head
	document.version = existing_version
	
	return document

func _ensure_latest_working_copy_async() -> void:
	if not is_outdated:
		return
	
	var file_path = _get_working_file_path()
	if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: Outdated: ", file_path)
	
	var fs := Desktop.current.filesystem
	
	# Sometimes documents are marked outdated for reasons other than content changes.
	if version.sha256 == FileAccess.get_sha256(file_path):
		is_outdated = false
		if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: Not actually outdated.")
		return
	
	if fs.archive_file_exists(version.sha256):
		if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: SHA already archived, unpacking ", version.sha256)
		fs.archive_file_unpack(version.sha256, file_path)
		return
	
	while is_outdated:
		if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: Requesting ", version.sha256)
		var xfer := await Desktop.current.network_transfer_handler.request_transfer_async(uuid)
		if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: Transfer started ", version.sha256)
		var success = await xfer.finished
		if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: Transfer finished ", version.sha256)
		
		# If there are multiple readers awaiting the latest version,
		# is_outdated could become true while we await the transfer.
		if not is_outdated:
			if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: File was updated already.")
			break
		
		# Check if we downloaded the wrong version.
		# This produces an error because the server should ensure all
		# current transfers are finished before sending out head updates.
		if version.sha256 != xfer.sha256:
			push_error("Wrong sha downloaded: %s (expected %s). Retrying." % [xfer.sha256, version.sha256])
			continue
		
		# If the transfer didn't succeed for whatever reason, try again.
		# Currently this shouldn't happen.
		if not success:
			push_warning("Transfer failed, retrying.")
			continue
		
		assert(fs.archive_file_exists(version.sha256))
		if TRACE: print_verbose("RemoteDocument._ensure_latest_working_copy_async: SHA archived, unpacking ", version.sha256)
		fs.archive_file_unpack(version.sha256, file_path)
		
		is_outdated = false
