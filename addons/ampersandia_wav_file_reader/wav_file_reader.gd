extends EditorPlugin

class_name WAVFileReader

const SUCCESS := 0

const ERROR := 1
const CHUNK_NOT_FOUND := -1
const PROVIDED_NOT_RIFF := -2
const LACKS_FMT := -3
const LACKS_AUDIO := -4
const NOT_RIFF := -5
const NOT_WAV := -5
const ERR_BAD_MUSIC := -7 # this is a joke.

const CHUNK := 2

##################################################
## WAVFileLoader class by Katie Ampersand
## https://ampersandia.net/
##
## I made this class because Godot has no built-in functionality to load WAV files.
## It only works properly with signed PCM data. If your PCM data is unsigned (I read somewhere that this is most 
## 		commonly the case for 8-bit WAV files)
## 		then it might fail (this is untested though).
##
## Just re-export your file with Audacity and you should be good to go
##
## I would like to be able to fix this in the future, though (assuming that the godot devs don't do it first)
###################################################


## loads wav file from Path and returns its data wrapped in a Result dictionary
## The dictionary contains a result field, which will be null if the parsing errored
## If it succeeds, the result field will contain an AudioStreamSample, and there will be a parse_tree field containing the parse tree
## If it errors, it will contain a code field for the error code, and a message field for an error message
## Negative error codes are WAV parse errors, positive ones are file system errors
## Type will be ERROR for any kind of error
## It will be SUCCESS otherwise
static func load(path: String) -> Dictionary:
	var output := {
		"type" : -1,
		"result" : null,
	}
	var audio_stream = AudioStreamSample.new()
	var file := File.new()
	var err := file.open(path, File.READ)

	if err != OK:
		output.type = ERROR
		output["code"] = err
		output["message"] = null
		match err:
			ERR_FILE_ALREADY_IN_USE:
				output.message = "File at %s is already in use."
			ERR_FILE_BAD_DRIVE:
				output.message = "File at %s might be in a corrupted directory."
			ERR_FILE_BAD_PATH:
				output.message = "Path %s is invalid."
			ERR_FILE_CANT_OPEN:
				output.message = "File at %s couldn't be opened."
			ERR_FILE_CANT_READ:
				output.message = "File at %s couldn't be read."
			ERR_FILE_CORRUPT:
				output.message = "File at %s is corrupted."
			ERR_FILE_NO_PERMISSION:
				output.message = "Program lacks permissions to open file at %s."
			ERR_FILE_NOT_FOUND:
				output.message = "File at path %s doesn't exist."
			_: 
				output.message = "Opening file at %s failed."
		output.message = output.message % path
		push_error(output.message)
		return output

	# It's not safe to naively assume that the audio data will start at bit 44
	# 		as there might be an unnecessary fact chunk, or metadata
	# 		so we parse the file instead (this has very little overhead)
	var parse_tree := get_chunk_parse_tree(file)

	if parse_tree.type == ERROR:
		match parse_tree.code:
			NOT_RIFF:
				output.type = ERROR
				output["code"] = NOT_RIFF
				output["message"] = parse_tree.message
				push_error(output.message)
				return output
			NOT_WAV:
				output.type = ERROR
				output["code"] = NOT_WAV
				output["message"] = parse_tree.message
				push_error(output.message)
				return output

	var fmt_chunk :Dictionary = get_chunk_by_id(parse_tree, "fmt")
	if fmt_chunk.type == ERROR:
		output["code"] = fmt_chunk.code
		output.code = LACKS_FMT
		output["message"] = "File at %s is broken, lacking an fmt chunk." % path
		push_error(output.message)
		return output

	var data_chunk :Dictionary = get_chunk_by_id(parse_tree, "data")
	if data_chunk.type == ERROR:
		output["code"] = data_chunk.code
		output.code = LACKS_AUDIO
		output["message"] = "File at %s is broken, lacking an audio chunk." % path
		push_error(output.message)
		return output


	match fmt_chunk.bits_per_sample:
		8:
			audio_stream.format = audio_stream.FORMAT_8_BITS
		16:
			audio_stream.format = audio_stream.FORMAT_16_BITS
		_:
			# I actually have no fucking clue if this is how it should be. I could not find shit.
			push_warning("UNCERTAIN BEHAVIOR: File at %s had a format of %s, which this addon interprets as IMA_ADPCM, however this might not be the case. If you know more, please contact katie-and@ampersandia.net" % [path, fmt_chunk.bits_per_sample])
			audio_stream.format = audio_stream.FORMAT_IMA_ADPCM
		
	audio_stream.stereo = fmt_chunk.channels == 2
	audio_stream.mix_rate = fmt_chunk.sample_ratio
	audio_stream.data = data_chunk.sampled_data
	file.close()

	output.type = SUCCESS
	output["code"] = OK
	output["message"] = "File loaded successfully!"
	output.result = audio_stream
	output["parse_tree"] = parse_tree
	return output


static func get_chunk_parse_tree(file: File) -> Dictionary:
	var chunk_tree := {}
	
	# Every chunk name has 4 characters. fmt is not stored as "fmt" but as "fmt ". This annoyed me greatly.
	# 		fuckers could've done "fmt_" or some shit.
	# 		why in fuck are they using ASCII anyways
	chunk_tree["type"] = CHUNK
	chunk_tree["chunk_id"] = file.get_buffer(4).get_string_from_ascii().replace(" ", "")
	if file.get_position() == 4:
		if chunk_tree.chunk_id != "RIFF":
			push_error("The file at %s is not in RIFF format, so it is not a WAV." % file.get_path_absolute())
			return {
					"type": ERROR,
					"code": NOT_RIFF,
					"message": "The file at %s is not in RIFF format, so it is not a WAV." % file.get_path_absolute()
				}
	chunk_tree["chunk_size"] = get_buffer_as_int(file.get_buffer(4))

	match chunk_tree["chunk_id"]:
		"RIFF":
			chunk_tree["format"] = file.get_buffer(4).get_string_from_ascii()
			if chunk_tree.format != "WAVE":
				push_error("The file at %s is not a WAV." % file.get_path_absolute())
				return {
					"type": ERROR,
					"code": NOT_WAV,
					"message": "The file at %s is not a WAV." % file.get_path_absolute()
				}
			chunk_tree["subchunks"] = []

			# Subchunks are a list just in case they're not in the order that they were in the spec I read
			# 		nor any file I tested this on
			while file.get_position() < file.get_len():
				chunk_tree["subchunks"].append(get_chunk_parse_tree(file))
		"fmt":
			chunk_tree["audio_format"] = get_buffer_as_int(file.get_buffer(2))
			chunk_tree["channels"] = get_buffer_as_int(file.get_buffer(2)) # I cannot BELIEVE this shit takes two entire bytes
			chunk_tree["sample_ratio"] = get_buffer_as_int(file.get_buffer(4))
			chunk_tree["byte_rate"] = get_buffer_as_int(file.get_buffer(4))
			chunk_tree["block_align"] = get_buffer_as_int(file.get_buffer(2))
			chunk_tree["bits_per_sample"] = get_buffer_as_int(file.get_buffer(2))
		"fact":
			chunk_tree["sample_length"] = get_buffer_as_int(file.get_buffer(4))
		"data":
			chunk_tree["sampled_data"] = file.get_buffer(chunk_tree.chunk_size)
		_:
			chunk_tree["unparsed_data"] = file.get_buffer(chunk_tree.chunk_size) # Author metadata and other shit will probably fall here
	
	return chunk_tree


## Godot also doesn't have a way to parse bytes as integers
## This only parses unsigned little endian
static func get_buffer_as_int(buf: PoolByteArray) -> int:
	var total := 0
	for idx in buf.size():
		var byte := buf[buf.size() - idx - 1]
		total = (total << 8) + (byte & 0xFF)
	return total


## Due to how I structured the parse tree, it's not possible to find a chunk by ID without iterating
static func get_chunk_by_id(parse_tree: Dictionary, id: String) -> Dictionary:
	match id:
		"RIFF":
			push_warning("Used get_chunk_by_id to find the RIFF chunk, this is identical to the parse tree dictionary.")
			if not parse_tree.chunk_id == "RIFF":
				push_error("Used get_chunk_by_id on non-RIFF chunk")
				return {
					"type" : ERROR,
					"code" : PROVIDED_NOT_RIFF,
					"message": "Provided a non-RIFF chunk to get_chunk_by_id().",
				}
			else:
				return parse_tree # Why would you do this

		_:
			for idx in parse_tree.subchunks.size():
				var current_chunk : Dictionary = parse_tree.subchunks[idx]
				if current_chunk.chunk_id == id:
					return current_chunk
	
	push_error("Chunk %s was not found." % id)
	return {
		"type" : ERROR,
		"code" : CHUNK_NOT_FOUND,
		"message": "Chunk %s was not found." % id,
	}
	