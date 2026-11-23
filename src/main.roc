app [main!] { pf: platform "../platform/main.roc" }

import pf.Env
import pf.Stderr
import pf.Stdout

main! = |_args| match Env.var!("HELLO_WORLD") {
	Ok(value) => {
		Stdout.line!(value)
		0
	}
	Err(NotFound) => {
		Stderr.line!("HELLO_WORLD is not set")
		1
	}
	Err(InvalidUnicode) => {
		Stderr.line!("HELLO_WORLD must be valid UTF-8")
		1
	}
}
