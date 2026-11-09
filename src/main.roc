app [main!] { pf: platform "../platform/main.roc" }

import pf.Stdout
import pf.File

greeting = |language| "Hello from ${language}, hosted by Rust!"

main! = || {
	path = "build/async-roundtrip.txt"
	contents = Str.repeat("Async Roc → Rust → Roc 🦜\n", 16)
	File.write!(
		path,
		contents,
		Box.box(
			|written| {
				match written {
					Err(error) => crash error
					Ok({}) => File.read!(
						path,
						Box.box(
							|read| {
								match read {
									Err(error) => crash error
									Ok(actual) => {
										if actual != contents {
											crash "File round-trip mismatch"
										}
										Stdout.line!(greeting("Roc"))
									}
								}
							},
						),
					)
				}
			},
		),
	)
	Stdout.line!("File I/O submitted")
	0
}

expect greeting("Roc") == "Hello from Roc, hosted by Rust!"
expect greeting("🦜") == "Hello from 🦜, hosted by Rust!"
