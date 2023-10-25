# Katie &'s WAVFileReader
A simple reader for .wav files that allows you to load most .wav files from the user's file system. It includes simple error handling features for both file system errors as well as WAV parse errors.

This plugin uses a simple parser to know where the audio data starts, instead of naively assuming that this data will be found at byte 44 (which is not guaranteed).

The example track in this repository was made by me.

## Features
* Load most .wav files into godot from outside the res:// directory
* Simple error handling for those who want their .wav file loading to never fail
* The ability to obtain the file's abstract syntax tree

## Known problems
* If your data is in PCM8 unsigned format, the audio will not load properly as this parser currently does not convert it into signed data.
* I have no idea how compressed WAV files work, so I am not certain that they are properly implemented

## How To Use
### Loading A File
To load a file, simply call `WAVFileReader.load("your/file/path")`. This will return a Dictionary. If the loading process didn't error, your file will be in the `result` field as an `AudioStreamSample`, otherwise this field will be null.

This means you can simply do something like this, and it'll work.

```gdscript
$MyAudioStream.stream = WAVFileReader.load("user://my/file/path.wav").result
```

However, this will not error if the file is corrupted or not present. Instead, it will make the AudioStream be silent.

### Error Handling
The most basic form of error detection this plugin provides comes in the form of merely detecting whether everything went fine or not. Simply check if the result is null.

```gdscript
var MyStream :AudioStreamSample = WAVFileReader.load("user://my/file/path.wav").result
if MyStream.result:
	$MyAudioStream.stream = MyStream.result
else:
	push_error("no music? *megamind meme*")
```

The output dictionary also contains error message data, which can be used, for example, to show the user what kind of error happened.

```gdscript
var MyStream :AudioStreamSample = WAVFileReader.load("user://my/file/path.wav").result
if MyStream.result:
	$MyAudioStream.stream = MyStream.result
else:
	$MyNotificationBox.text = MyStream.message
```

You can also separate between file system errors and WAV parse errors, as all WAV parse error codes are negative numbers, while all file system error codes are positive number. WAV parse errors occur when the file you tried to open is missing vital data, such as the audio part of it, or how many audio channels there are. File system errors occur when the file is missing, corrupted, or in some other way inaccessible at the moment.

```gdscript
var MyStream :AudioStreamSample = WAVFileReader.load("user://my/file/path.wav").result
if MyStream.result:
	$MyAudioStream.stream = MyStream.result
elif MyStream.code > 0:
	push_error("no file? *megamind meme*")
elseMyStream.code > 0:
	push_error("broken file? *megamind meme*")
```

#### WAV Parsing Error Codes
This table contains the custom error codes and a simple explanation of them

| Code | Name | Meaning |
| --- | --- | --- |
| -1 | CHUNK_NOT_FOUND | `WAVFileReader.get_chunk_by_id()` couldn't find the specified chunk in the provided parse tree |
| -2 | PROVIDED_NOT_RIFF | `WAVFileReader.get_chunk_by_id()` was provided a non RIFF chunk |
| -3 | LACKS_FMT | The file couldn't be parsed because it lacks an `fmt` subchunk |
| -4 | LACKS_AUDIO | The file couldn't be parsed because it lacks any audio data |
| -5 | NOT_RIFF | The file couldn't be parsed because its root is not a RIFF chunk, meaning it isn't a WAV file |
| -6 | NOT_WAV | The file couldn't be parsed because its first subchunk is not a WAVE chunk |
| -7 | BAD_MUSIC | `WAVFileReader` refused to parse the file to protect the end user from indulging in a terrible music taste |
