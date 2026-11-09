Tool := [].{
	RawCall : { id : Str, name : Str, arguments : List({ name : Str, value : Str }) }
	Operation : [ReadFile(Str), ListFiles(Str), Search(Str), GitDiff]
	Call : { id : Str, operation : Operation }
	Result : { id : Str, outcome : Try(Str, Str) }
	Run : Call, Box(Result => {}) => {}

	validate : RawCall -> Try(Call, Str)
	validate = |raw| {
		operation = match (raw.name, raw.arguments) {
			("read_file", [{ name: "path", value }]) => ReadFile(relative_path(value)?)
			("list_files", [{ name: "path", value }]) => ListFiles(relative_path(value)?)
			("search", [{ name: "query", value }]) => {
				if value.trim().is_empty() {
					return Err("search needs a nonempty query")
				}
				Search(value)
			}
			("git_diff", []) => GitDiff
			("read_file", _) => return Err("read_file expects exactly one path argument")
			("list_files", _) => return Err("list_files expects exactly one path argument")
			("search", _) => return Err("search expects exactly one query argument")
			("git_diff", _) => return Err("git_diff expects no arguments")
			_ => return Err("Unknown tool: ${raw.name}")
		}
		Ok({ id: raw.id, operation })
	}

	label : Call -> Str
	label = |call| {
		operation = match call.operation {
			ReadFile(path) => "read_file ${path}"
			ListFiles(path) => "list_files ${path}"
			Search(query) => "search ${query}"
			GitDiff => "git_diff"
		}
		"${call.id} ${operation}"
	}
}

relative_path : Str -> Try(Str, Str)
relative_path = |path| {
	if path.contains("\\") or path.contains("\u(0000)") {
		return Err("Expected a normalized relative path")
	}
	for component in path.split_on("/") {
		if component.is_empty() or component == "." or component == ".." {
			return Err("Expected a normalized relative path")
		}
	}
	Ok(path)
}

read = { id: "read", name: "read_file", arguments: [{ name: "path", value: "src/auth.roc" }] }
expect Tool.validate(read) == Ok({ id: "read", operation: ReadFile("src/auth.roc") })
expect Tool.validate({ ..read, name: "list_files" }) == Ok({ id: "read", operation: ListFiles("src/auth.roc") })
expect Tool.validate({ ..read, name: "shell" }) == Err("Unknown tool: shell")
expect Tool.validate({ ..read, arguments: [] }) == Err("read_file expects exactly one path argument")
expect Tool.validate({ ..read, arguments: read.arguments.concat(read.arguments) }) == Err("read_file expects exactly one path argument")
expect Tool.validate({ ..read, arguments: [{ name: "command", value: "anything" }] }) == Err("read_file expects exactly one path argument")
expect Tool.validate({ id: "diff", name: "git_diff", arguments: [] }) == Ok({ id: "diff", operation: GitDiff })
expect Tool.validate({ ..read, name: "git_diff" }) == Err("git_diff expects no arguments")
expect Tool.validate({ id: "search", name: "search", arguments: [{ name: "query", value: " " }] }) == Err("search needs a nonempty query")
expect {
	var $valid = True
	for path in ["", "/etc/passwd", "../secret", "src/../secret", "./src/auth.roc", "src//auth.roc", "src\\auth.roc", "src/\u(0000)auth.roc"] {
		$valid = $valid and relative_path(path) == Err("Expected a normalized relative path")
	}
	$valid
}
