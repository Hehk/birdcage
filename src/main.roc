app [main!] { pf: platform "../platform/main.roc" }

import pf.Stdout

greeting = |language| "Hello from ${language}, hosted by Rust!"

main! = || {
	Stdout.line!(greeting("Roc"))
	0
}

expect greeting("Roc") == "Hello from Roc, hosted by Rust!"
expect greeting("🦜") == "Hello from 🦜, hosted by Rust!"
