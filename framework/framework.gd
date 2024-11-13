class_name Framework
extends RefCounted

const DESKTOPS_PATH = "user://desktops"

const DESKTOP_ARCHIVE_DIR = "archive"
const DESKTOP_DOCUMENTS_DIR = "documents"
const DESKTOP_METADATA_FILE = "desktop_metadata.json"
const DESKTOP_THUMBNAIL_FILE = "thumbnail.png"

const DOCUMENT_VERSIONS_DIR = "versions"
const DOCUMENT_WORKING_DIR = "working"
const DOCUMENT_METADATA_FILE = "metadata.json"
const DOCUMENT_HEAD_FILE = "head.json"

enum Permission {
	NONE,
	READ_ONLY,
	READ_WRITE,
	OWNER,
}

enum CompressionMode {
	UNCOMPRESSED,
	GZIP,
}


static func get_desktop_dir(desktop_uuid: StringName) -> String:
	return DESKTOPS_PATH.path_join(desktop_uuid)

static func get_desktop_archive_dir(desktop_uuid: StringName) -> String:
	return get_desktop_dir(desktop_uuid).path_join(DESKTOP_ARCHIVE_DIR)

static func get_desktop_documents_dir(desktop_uuid: StringName) -> String:
	return get_desktop_dir(desktop_uuid).path_join(DESKTOP_DOCUMENTS_DIR)

static func get_desktop_metadata_file(desktop_uuid: StringName) -> String:
	return get_desktop_dir(desktop_uuid).path_join(DESKTOP_METADATA_FILE)

static func get_desktop_thumbnail_file(desktop_uuid: StringName) -> String:
	return get_desktop_dir(desktop_uuid).path_join(DESKTOP_THUMBNAIL_FILE)


static func get_document_dir(desktop_uuid: StringName, document_uuid: StringName) -> String:
	return get_desktop_documents_dir(desktop_uuid).path_join(document_uuid)

static func get_document_versions_dir(desktop_uuid: StringName, document_uuid: StringName) -> String:
	return get_document_dir(desktop_uuid, document_uuid).path_join(DOCUMENT_VERSIONS_DIR)

static func get_document_working_dir(desktop_uuid: StringName, document_uuid: StringName) -> String:
	return get_document_dir(desktop_uuid, document_uuid).path_join(DOCUMENT_WORKING_DIR)

static func get_document_metadata_file(desktop_uuid: StringName, document_uuid: StringName) -> String:
	return get_document_dir(desktop_uuid, document_uuid).path_join(DOCUMENT_METADATA_FILE)

static func get_document_head_file(desktop_uuid: StringName, document_uuid: StringName) -> String:
	return get_document_dir(desktop_uuid, document_uuid).path_join(DOCUMENT_HEAD_FILE)
