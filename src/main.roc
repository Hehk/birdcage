app [main!] { pf: platform "../platform/main.roc" }

import pf.Env
import pf.Stderr
import pf.Stdout
import OpenAI
import Uuid

handle_message! = |args| {
	message = match args {
		[msg] => msg
		_ => {
			Stderr.line!("Invalid message")
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

handle_help! = || {
	Stdout.line!("TODO: implement help")
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
