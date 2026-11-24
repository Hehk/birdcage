import pf.Env
import pf.File
import Uuid

Session := [].{
	DirectoryError : [NoStateDirectory, InvalidHomePath]

	create! : Str => Try(Str, [RandomFailure(Str), StateDirectoryFailed(DirectoryError), CreateDirectoryFailed(File.Error), CreateSessionFailed(File.Error)])
	create! = |message| {
		id = Uuid.v4!().map_err(|RandomFailure(detail)| RandomFailure(detail))?
		directory = directory!().map_err(|error| StateDirectoryFailed(error))?
		File.create_dir_all!(directory).map_err(|error| CreateDirectoryFailed(error))?
		File.create_new!(session_path(directory, id), message_line(id, "user", message)).map_err(|error| CreateSessionFailed(error))?
		Ok(id)
	}

	append_reply! : Str, Str => Try({}, [InvalidSessionId, StateDirectoryFailed(DirectoryError), AppendReplyFailed(File.Error)])
	append_reply! = |id, reply| {
		if !is_session_id(id) {
			return Err(InvalidSessionId)
		}
		directory = directory!().map_err(|error| StateDirectoryFailed(error))?
		File.append!(session_path(directory, id), message_line(id, "assistant", reply)).map_err(|error| AppendReplyFailed(error))
	}

	list! : () => Try(List(Str), [StateDirectoryFailed(DirectoryError), ListSessionsFailed(File.Error)])
	list! = || {
		directory = directory!().map_err(|error| StateDirectoryFailed(error))?
		match File.list_files!(directory) {
			Ok(names) => Ok(session_ids(names))
			Err(error) => if error.kind == NotFound {
				Ok([])
			} else {
				Err(ListSessionsFailed(error))
			}
		}
	}
}

directory! : () => Try(Str, Session.DirectoryError)
directory! = || {
	match Env.var!("XDG_STATE_HOME") {
		Ok(state) => if state.starts_with("/") {
			return Ok("${state}/birdcage/sessions")
		}
		Err(_) => {}
	}
	match Env.var!("HOME") {
		Ok(home) => if home.starts_with("/") {
			Ok("${home}/.local/state/birdcage/sessions")
		} else {
			Err(InvalidHomePath)
		}
		Err(_) => Err(NoStateDirectory)
	}
}

session_ids : List(Str) -> List(Str)
session_ids = |names| {
	var $ids = []
	for name in names {
		match name.split_on(".") {
			[id, "jsonl"] => if is_session_id(id) {
				$ids = $ids.append(id)
			}
			_ => {}
		}
	}
	$ids
}

is_session_id : Str -> Bool
is_session_id = |id| {
	bytes = id.to_utf8()
	if bytes.len() != 36 {
		return False
	}
	var $index = 0
	for byte in bytes {
		valid = match $index {
			8 | 13 | 18 | 23 => byte == 45
			_ => (byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)
		}
		if !valid {
			return False
		}
		$index = $index + 1
	}
	True
}

expect session_ids([
	"00000000-0000-4000-8000-000000000000.jsonl",
	"00000000-0000-4000-8000-000000000001.json",
	"00000000-0000-4000-8000-00000000000g.jsonl",
	"unrelated.jsonl",
]) == ["00000000-0000-4000-8000-000000000000"]

session_path : Str, Str -> Str
session_path = |directory, id| "${directory}/${id}.jsonl"

message_line : Str, Str, Str -> Str
message_line = |id, role, content| Json.to_str({ session_id: id, role, content }).concat("\n")

expect {
	message = "first line\n\"second line\""
	line = message_line("test-id", "user", message)
	parsed : Try({ session_id : Str, role : Str, content : Str }, _)
	parsed = Json.parse(line)
	parsed == Ok({ session_id: "test-id", role: "user", content: message }) and line.split_on("\n").len() == 2
}
