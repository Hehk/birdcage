app [main!] { pf: platform "../platform/main.roc" }

import pf.Env
import pf.Stderr
import pf.Stdout
import OpenAI
import Session

parse_message_args : List(Str) -> Try({ message : Str, session : [New, Existing(Str)] }, [InvalidMessageArgs])
parse_message_args = |args| match args {
	["--session", id, message] => Ok({ message, session: Existing(id) })
	[message, "--session", id] => Ok({ message, session: Existing(id) })
	["--session"] => Err(InvalidMessageArgs)
	[message] => Ok({ message, session: New })
	_ => Err(InvalidMessageArgs)
}

expect parse_message_args(["--session", "id", "hello"]) == Ok({ message: "hello", session: Existing("id") })
expect parse_message_args(["hello", "--session", "id"]) == Ok({ message: "hello", session: Existing("id") })
expect parse_message_args(["hello", "--session"]) == Err(InvalidMessageArgs)

handle_message! : List(Str) => Try({}, Str)
handle_message! = |args| {
	parsed = parse_message_args(args).map_err(|InvalidMessageArgs| "Invalid message")?
	key = Env.var!("OPENAI_API_KEY").map_err(
		|error| match error {
			NotFound => "OPENAI_API_KEY not found"
			InvalidUnicode => "OPENAI_API_KEY contains invalid unicode"
		},
	)?
	if key.is_empty() {
		return Err("OPENAI_API_KEY is empty")
	}
	conversation = match parsed.session {
		New => Session.create!(parsed.message).map_err(create_session_message)
		Existing(id) => Session.continue!(id, parsed.message).map_err(|error| continue_session_message(id, error))
	}?
	{ id, messages } = conversation
	response = OpenAI.send!(key, "gpt-6.2-sol", messages).map_err(|error| "${open_ai_message(error)}\nsession_id: ${id}")?
	Session.append_reply!(id, response).map_err(
		|error| {
			detail = match error {
				InvalidSessionId => "Invalid session ID"
				StateDirectoryFailed(reason) => state_directory_message(reason)
				AppendReplyFailed(io) => io.detail
			}
			"Could not save reply for session ${id}: ${detail}"
		},
	)?
	Stdout.line!(response)
	Stdout.line!("session_id: ${id}")
	Ok({})
}

create_session_message = |error| match error {
	RandomFailure(reason) => "Could not generate session ID: ${reason}"
	StateDirectoryFailed(reason) => state_directory_message(reason)
	CreateDirectoryFailed(io) => "Could not create sessions directory: ${io.detail}"
	CreateSessionFailed(io) => "Could not create session file: ${io.detail}"
}

continue_session_message = |id, error| match error {
	InvalidSessionId => "Invalid session ID"
	StateDirectoryFailed(reason) => state_directory_message(reason)
	ReadSessionFailed(io) => if io.kind == NotFound {
		"Session not found: ${id}"
	} else {
		"Could not read session ${id}: ${io.detail}"
	}
	BadLine(line) => "Invalid history for session ${id} at line ${Str.inspect(line)}"
	AppendMessageFailed(io) => "Could not save message for session ${id}: ${io.detail}"
}

open_ai_message : OpenAI.Error -> Str
open_ai_message = |error| match error {
	TransportError(detail) => "OpenAI request failed: ${detail}"
	HttpError(status, detail) => "OpenAI HTTP ${Str.inspect(status)}: ${detail}"
	InvalidUnicode => "OpenAI returned invalid UTF-8"
	InvalidResponse => "OpenAI returned an invalid response"
	ResponseNotCompleted(details) => {
		summary = "OpenAI response was not completed: ${details.status}"
		if details.reason.is_empty() {
			summary
		} else {
			"${summary} (${details.reason})"
		}
	}
	MissingContent => "OpenAI message has no content"
	MissingText => "OpenAI text output has no text"
	Refused => "OpenAI refused the request"
	NoText => "OpenAI returned no text"
}

state_directory_message : Session.DirectoryError -> Str
state_directory_message = |error| match error {
	NoStateDirectory => "No state directory: set XDG_STATE_HOME or HOME"
	InvalidHomePath => "HOME is not an absolute path"
}

handle_help! = || {
	Stdout.line!("Usage: birdcage message [--session <id>] <text>\n       birdcage message <text> --session <id>")
	0
}

main! = |args| {
	match args {
		["message", .. as rest] => match handle_message!(rest) {
			Ok({}) => 0
			Err(detail) => {
				Stderr.line!(detail)
				1
			}
		}
		["help"] => handle_help!()
		_ => {
			Stderr.line!("Invalid usage, run `birdcage help` for help")
			1
		}
	}
}
