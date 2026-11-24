app [main!] { pf: platform "../platform/main.roc" }

import pf.Env
import pf.Stderr
import pf.Stdout
import OpenAI
import Session

handle_message! = |args| {
	message = match args {
		[msg] => msg
		_ => {
			Stderr.line!("Invalid message")
			return 1
		}
	}

	session_id = match Session.create!(message) {
		Ok(id) => id
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

	match OpenAI.send!(open_ai_key, "gpt-6.2-sol", message) {
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
	Stdout.line!("Usage: birdcage message <text>")
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
