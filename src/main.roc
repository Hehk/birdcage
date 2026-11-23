app [main!] { pf: platform "../platform/main.roc" }

import pf.Stdout
import pf.Stderr
import Cli
import FileDemo
import pf.Host
import Review
import Report
import Scripted

main! = |args| match Cli.parse(args) {
	Err(error) => {
		Stderr.line!(error)
		2
	}
	Ok(Review(review, name)) => {
		script = match Scripted.select(name) {
			Ok(selected) => selected
			Err(error) => {
				Stderr.line!(error)
				return 2
			}
		}
		Stdout.line!("Scripted fixture mode; no repository inspection.")
		Review.run!(
			review,
			|request, done| Scripted.send!(script, request, done),
			|call, done| Scripted.run_tool!(script, call, done),
			Box.box(
				|result| {
					match result {
						Ok(findings) => Stdout.line!(Report.render(findings))
						Err(error) => {
							Stderr.line!("Review failed: ${error}")
							Host.exit_code!(1)
						}
					}
				},
			),
		)
		0
	}
	Ok(FileDemo(path)) => {
		match FileDemo.run!(path) {
			Ok({}) => 0
			Err(error) => {
				Stderr.line!("File demo failed: ${error}")
				1
			}
		}
	}
}
