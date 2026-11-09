app [main!] { pf: platform "../platform/main.roc" }

import pf.Stdout
import pf.Stderr
import Cli
import FileDemo

main! = |args| match Cli.parse(args) {
	Err(error) => {
		Stderr.line!(error)
		2
	}
	Ok(Review(review)) => {
		Stdout.line!("Scripted fixture mode; no repository inspection.")
		Stdout.line!("Review request: ${review.source} into ${review.target}")
		0
	}
	Ok(FileDemo(path)) => {
		FileDemo.run!(path)
		0
	}
}
