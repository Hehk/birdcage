Tool := [].{
	Operation : [ReadFile(Str), ListFiles(Str), Search(Str), GitDiff]
	Call : { id : Str, operation : Operation }
	Result : { id : Str, outcome : Try(Str, Str) }
	Run : Call, Box(Result => {}) => {}

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
