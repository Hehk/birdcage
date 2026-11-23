app [main!] { pf: platform "../platform/main.roc" }

import pf.Env
import pf.Stderr
import pf.Stdout

handle_message! = |args| {
	message = match args {
		[msg] => msg
		_ => {
			Stderr.line!("Invalid message")
			return 1
		}
	}

	_open_ai_key = match Env.var!("OPENAI_API_KEY") {
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

	Stdout.line!("Message ${message}")
	0
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
