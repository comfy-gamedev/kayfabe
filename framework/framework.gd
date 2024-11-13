class_name Framework
extends RefCounted

const DESKTOPS_PATH = "user://desktops"
const DESKTOP_METADATA_FILE = "desktop_metadata.json"

const DOCUMENTS_DIR = "documents"
const DOCUMENT_ARCHIVE_DIR = "archive"
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
