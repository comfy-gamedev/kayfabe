class_name NetworkTransfer
extends RefCounted

signal finished(success: bool)

const TRACE = true
const MAX_PACKET_SIZE = 1024 * 16
const MSG_READY = &"READY"
const MSG_COMPLETE = &"COMPLETE"

enum Status {
	PENDING,
	SEND,
	RECV,
	DONE,
	CANCELLED,
}

var status: Status = Status.PENDING
var document_uuid: StringName
var sha256: String
var pipe: NetworkPipe: set = set_pipe

var _file: FileAccess
var _remote_ready: bool

func begin_upload(p_pipe: NetworkPipe, p_document_uuid: StringName, p_sha256: String) -> void:
	if TRACE: print_verbose("NetworkTransfer.begin_upload(%s, %s, %s)" % [p_pipe, p_document_uuid, p_sha256])
	status = Status.SEND
	document_uuid = p_document_uuid
	sha256 = p_sha256
	pipe = p_pipe
	_file = Desktop.current.filesystem._open_archive_file(sha256, FileAccess.READ)

func begin_download(p_pipe: NetworkPipe, p_document_uuid: StringName, p_sha256: String) -> void:
	if TRACE: print_verbose("NetworkTransfer.begin_download(%s, %s, %s)" % [p_pipe, p_document_uuid, p_sha256])
	status = Status.RECV
	document_uuid = p_document_uuid
	sha256 = p_sha256
	pipe = p_pipe
	if Desktop.current.filesystem.archive_file_exists(sha256):
		if TRACE: print_verbose("\tNetworkTransfer.begin_download: SHA exists.")
		pipe.send(_msg_ready(false))
		_set_done()
	else:
		if TRACE: print_verbose("\tNetworkTransfer.begin_download: SHA not found, downloading.")
		_file = Desktop.current.filesystem._open_archive_file_tmp(sha256)
		if not _file:
			if TRACE: print_verbose("\tNetworkTransfer.begin_download: Failed to open tmp file for sha %s: %s" % [sha256, error_string(FileAccess.get_open_error())])
			_set_cancelled()
		else:
			if TRACE: print_verbose("\tNetworkTransfer.begin_download: Ready to download.")
			pipe.send(_msg_ready(true))

func is_done() -> bool:
	return status == Status.DONE or status == Status.CANCELLED

func set_pipe(v: NetworkPipe) -> void:
	if pipe == v: return
	if pipe:
		pipe.message_received.disconnect(_on_message_received)
		pipe.raw_received.disconnect(_on_raw_received)
	pipe = v
	if TRACE: print_verbose("NetworkTransfer (%s) pipe set %s." % [document_uuid, str(pipe.pipe_id) if pipe else "null"])
	if pipe:
		pipe.message_received.connect(_on_message_received)
		pipe.raw_received.connect(_on_raw_received)

func process() -> Error:
	if status == Status.PENDING or status == Status.DONE:
		return ERR_BUG
	if not pipe.is_open():
		if TRACE: print_verbose("NetworkTransfer (%s) cancelled (pipe closed)." % document_uuid)
		_set_cancelled()
		return ERR_CONNECTION_ERROR
	
	match status:
		Status.SEND:
			if not _file:
				return ERR_BUG
			
			if not _remote_ready:
				return OK
			
			var available = _file.get_length() - _file.get_position()
			var packet_size = mini(available, MAX_PACKET_SIZE)
			var data = _file.get_buffer(packet_size)
			assert(_file.get_error() == OK)
			
			if TRACE: print_verbose("NetworkTransfer (%s) sending %s bytes." % [document_uuid, data.size()])
			var err = pipe.send_raw(data)
			if err != OK:
				if TRACE: print_verbose("NetworkTransfer (%s) sending failed (%)." % [document_uuid, error_string(err)])
				return err
			
			#pipe.stats.transfer_up += data.size()
			
			if _file.eof_reached() or _file.get_position() == _file.get_length():
				if TRACE: print_verbose("NetworkTransfer (%s) upload finished." % [document_uuid])
				var md5 = FileAccess.get_md5(_file.get_path())
				pipe.send(_msg_complete(md5))
				_set_done()
			
			return OK
		Status.RECV:
			return OK
	
	return ERR_BUG

func _set_done() -> void:
	if status == Status.DONE or status == Status.CANCELLED:
		return
	if TRACE: print_verbose("NetworkTransfer._set_done()")
	status = Status.DONE
	_file = null
	pipe.close()
	finished.emit(true)

func _set_cancelled() -> void:
	if status == Status.DONE or status == Status.CANCELLED:
		return
	if TRACE: print_verbose("NetworkTransfer._set_cancelled()")
	status = Status.CANCELLED
	_file = null
	pipe.close()
	finished.emit(false)

func _msg_ready(need: bool) -> TaggedMessage:
	var msg = TaggedMessage.new()
	msg.tag = MSG_READY
	msg.data = { need = need }
	return msg

func _msg_complete(md5: String) -> TaggedMessage:
	var msg = TaggedMessage.new()
	msg.tag = MSG_COMPLETE
	msg.data = { md5 = md5 }
	return msg

func _on_message_received(message: TaggedMessage) -> void:
	if TRACE: print_verbose("NetworkTransfer._on_message_received(%s)" % [message])
	match message.tag:
		MSG_READY:
			if status != Status.SEND:
				_set_cancelled()
				return
			if not message.data.need:
				_set_done()
			else:
				_remote_ready = true
		MSG_COMPLETE:
			if status != Status.RECV:
				_set_cancelled()
				return
			_file.close()
			var md5 = FileAccess.get_md5(_file.get_path())
			if md5 != message.data.md5:
				push_error("MD5 checksum mismatch.")
				DirAccess.remove_absolute(_file.get_path())
				_set_cancelled()
			else:
				if not Desktop.current.filesystem.archive_file_exists(sha256):
					var path = Desktop.current.filesystem.get_archive_file_path(sha256)
					DirAccess.rename_absolute(_file.get_path(), path)
				else:
					DirAccess.remove_absolute(_file.get_path())
				_set_done()

func _on_raw_received(message: PackedByteArray) -> void:
	if status != Status.RECV:
		if TRACE: print_verbose("NetworkTransfer (%s) cancelled (data received while not downloading)." % document_uuid)
		_set_cancelled()
		return
	
	if TRACE: print_verbose("NetworkTransfer (%s) data received: %s bytes." % [document_uuid, message.size()])
	
	#pipe.stats.transfer_down += message.size()
	_file.store_buffer(message)
