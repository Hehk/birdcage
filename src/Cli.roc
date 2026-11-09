Cli := [].{
	Review : { source : Str, target : Str }
	Command : [Review(Review), FileDemo(Str)]

	usage = "Usage: birdcage review <branch> --into <target>"

	parse : List(Str) -> Try(Command, Str)
	parse = |args| match args {
		["review", source, "--into", target] => {
			if source.is_empty() or target.is_empty() or source.starts_with("-") or target.starts_with("-") {
				Err("Expected nonempty branch and target names.\n${usage}")
			} else {
				Ok(Review({ source, target }))
			}
		}
		["file-demo", path] => Ok(FileDemo(path))
		_ => Err(usage)
	}
}

expect Cli.parse(["review", "feature/🦜", "--into", "main"]) == Ok(Review({ source: "feature/🦜", target: "main" }))
expect Cli.parse([]) == Err(Cli.usage)
expect Cli.parse(["scan"]) == Err(Cli.usage)
expect Cli.parse(["review", "feature", "--into"]) == Err(Cli.usage)
expect Cli.parse(["review", "feature", "--into", "main", "extra"]) == Err(Cli.usage)
