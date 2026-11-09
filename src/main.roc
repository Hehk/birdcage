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
	Ok(Review(review)) => {
		Stdout.line!("Scripted fixture mode; no repository inspection.")
		Review.run!(
			review,
			Scripted.send!,
			Scripted.run_tool!,
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
		FileDemo.run!(path)
		0
	}
}
