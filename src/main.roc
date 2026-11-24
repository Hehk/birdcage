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

handle_message! = |args| {
	parsed = match parse_message_args(args) {
		Ok(value) => value
		Err(InvalidMessageArgs) => {
			Stderr.line!("Invalid message")
			return 1
		}
	}

	conversation = match parsed.session {
		New => match Session.create!(parsed.message) {
			Ok(id) => { id, messages: [{ role: "user", content: parsed.message }] }
			Err(error) => {
				detail = match error {
					RandomFailure(reason) => "Could not generate session ID: ${reason}"
					StateDirectoryFailed(reason) => state_directory_message(reason)
					CreateDirectoryFailed(io) => "Could not create sessions directory: ${io.detail}"
					CreateSessionFailed(io) => "Could not create session file: ${io.detail}"
				}
				Stderr.line!(detail)
				return 1
			}
		}
		Existing(id) => match Session.continue!(id, parsed.message) {
			Ok(messages) => { id, messages }
			Err(error) => {
				detail = match error {
					InvalidSessionId => "Invalid session ID"
					StateDirectoryFailed(reason) => state_directory_message(reason)
					ReadSessionFailed(io) => if io.kind == NotFound {
						"Session not found: ${id}"
					} else {
						"Could not read session ${id}: ${io.detail}"
					}
					InvalidHistory(line) => "Invalid history for session ${id} at line ${Str.inspect(line)}"
					AppendMessageFailed(io) => "Could not save message for session ${id}: ${io.detail}"
				}
				Stderr.line!(detail)
				return 1
			}
		}
	}
	session_id = conversation.id

	open_ai_key = match Env.var!("OPENAI_API_KEY") {
		Ok(value) => value
		Err(NotFound) => {
			Stderr.line!("OPENAI_API_KEY not found")
			return 1
		}
		Err(InvalidUnicode) => {
			Stderr.line!("OPENAI_API_KEY contains invalid unicode")
			return 1
		}
	}

	match OpenAI.send!(open_ai_key, "gpt-6.2-sol", conversation.messages) {
		Ok(response) => {
			match Session.append_reply!(session_id, response) {
				Ok({}) => {}
				Err(error) => {
					detail = match error {
						InvalidSessionId => "Invalid session ID"
						StateDirectoryFailed(reason) => state_directory_message(reason)
						AppendReplyFailed(io) => io.detail
					}
					Stderr.line!("Could not save reply for session ${session_id}: ${detail}")
					return 1
				}
			}
			Stdout.line!(response)
			Stdout.line!("session_id: ${session_id}")
			0
		}
		Err(error) => {
			error_message = match error {
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
			Stderr.line!(error_message)
			1
		}
	}
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
		["message", .. as rest] => handle_message!(rest)
		["help"] => handle_help!()
		_ => {
			Stderr.line!("Invalid usage, run `birdcage help` for help")
			1
		}
	}
}
