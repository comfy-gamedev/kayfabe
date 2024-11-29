class_name Document
extends RefCounted

@warning_ignore("unused_signal") # This signal is emitted elsewhere.
signal version_changed()

signal cache_updated(err: Error)

var desktop_uuid: String
var uuid: String
var metadata: DocumentMetadata
var head: DocumentHead
var version: DocumentVersion

var _cached_content_updating: bool = false
var _cached_content: Variant # null | PackedByteArray
var _cached_content_tick_msec: int

var _cached_thumbnail: Texture2D

func _ensure_latest_working_copy_async() -> void: # VIRTUAL
	push_error("Not implemented.")

func get_name() -> String:
	return version.name

func get_file_name() -> String:
	return metadata.file_name

func get_tags() -> PackedStringArray:
	return version.tags

func get_working_file_path_async() -> String:
	@warning_ignore("redundant_await")
	await _ensure_latest_working_copy_async()
	return _get_working_file_path()

func get_content_async() -> Variant:
	var err = await _update_cached_content_async()
	if err != OK:
		return null
	
	return _cached_content.duplicate()

func get_thumbnail_async() -> Texture2D:
	if not _cached_thumbnail:
		_cached_thumbnail = Framework.get_document_default_thumbnail()
	
	return _cached_thumbnail

func _clear_cache() -> void:
	_cached_content = null
	_cached_thumbnail = null

func _update_cached_content_async() -> Error:
	if _cached_content_updating:
		return await cache_updated
	
	assert(_cached_content_updating == false)
	_cached_content_updating = true
	
	@warning_ignore("redundant_await")
	var err = await _ensure_latest_working_copy_async()
	if err != OK:
		_cached_content_updating = false
		cache_updated.emit(err)
		return err
	
	err = __update_cached_content_unsafe()
	
	_cached_content_updating = false
	cache_updated.emit(err)
	return err

func __update_cached_content_unsafe() -> Error:
	if _cached_content != null:
		_cached_content_tick_msec = Time.get_ticks_msec()
		return OK
	
	var file_path = _get_working_file_path()
	var fresh_load = FileAccess.get_file_as_bytes(file_path)
	var err = FileAccess.get_open_error()
	if err != OK:
		push_error("Failed to open document file %s: %s" % [file_path, error_string(err)])
		return err
	
	_cached_content = fresh_load
	_cached_content_tick_msec = Time.get_ticks_msec()
	
	return OK


func _get_working_file_path() -> String:
	return Framework.get_document_working_dir(desktop_uuid, uuid).path_join(metadata.file_name)
