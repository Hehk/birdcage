import pf.Host
import pf.Stdout
import Model
import Report
import Tool

Scripted := [].{
	select : Str -> Try(List(Tool.Call), Str)
	select = |name| match name {
		"diff-first" => Ok([diff_call, list_call, search_call, read_call])
		"search-first" => Ok([search_call, read_call, diff_call])
		"single-read" => Ok([read_call])
		"final" => Ok([])
		_ => Err("Unknown script: ${name}")
	}

	send! : List(Tool.Call), Model.Request, Box(Try(Model.Response, Str) => {}) => {}
	send! = |script, request, done| {
		Stdout.line!("Model request: ${request.review.source} into ${request.review.target}")
		Stdout.line!("History: ${Str.inspect(request.history)}")
		Host.defer!(Box.box(|| done.unbox()(respond(script, request))))
	}

	respond : List(Tool.Call), Model.Request -> Try(Model.Response, Str)
	respond = |script, request| reply(script, request.history, finding.evidence)

	run_tool! : Tool.Run
	run_tool! = |call, done| {
		Stdout.line!("Tool request: ${Tool.label(call)}")
		Host.defer!(
			Box.box(
				|| {
					result = execute(call)
					Stdout.line!("Tool result: ${Str.inspect(result)}")
					done.unbox()(result)
				},
			),
		)
	}

	execute : Tool.Call -> Tool.Result
	execute = |call| {
		outcome = match call.operation {
			ReadFile("src/auth.roc") => Ok("authorize = |_user| True")
			ReadFile("src/main.roc") => Ok("main = || authorize(Guest)")
			ReadFile(path) => Err("Fixture file not found: ${path}")
			ListFiles("src") => Ok("src/auth.roc\nsrc/main.roc")
			ListFiles(path) => Err("Fixture directory not found: ${path}")
			Search(query) => if "authorize = |_user| True".contains(query) {
				Ok("src/auth.roc:1: authorize = |_user| True")
			} else {
				Ok("")
			}
			GitDiff => Ok("src/auth.roc\n-authorize = |user| user.is_admin\n+authorize = |_user| True")
		}
		{ id: call.id, outcome }
	}

	read_call : Tool.Call
	read_call = { id: "read-auth", operation: ReadFile("src/auth.roc") }
	list_call : Tool.Call
	list_call = { id: "list-src", operation: ListFiles("src") }
	search_call : Tool.Call
	search_call = { id: "search-auth", operation: Search("authorize") }
	diff_call : Tool.Call
	diff_call = { id: "diff", operation: GitDiff }

	finding : Report.Finding
	finding = {
		severity: High,
		location: At({ path: "src/auth.roc", line: 1 }),
		explanation: "The fixture authorizes every caller.",
		evidence: "authorize = |_user| True",
	}
}

reply : List(Tool.Call), List(Model.Message), Str -> Try(Model.Response, Str)
reply = |script, history, evidence| match (script, history) {
	([], []) => Ok(Final([{ ..Scripted.finding, evidence }]))
	([call, ..], []) => Ok(ToolCall(call))
	([expected, .. as remaining], [Assistant(ToolCall(actual)), ToolResult(result), .. as messages]) => {
		if actual != expected or result.id != actual.id {
			Err("Unexpected scripted tool correlation")
		} else {
			match result.outcome {
				Err(error) => Err("Fixture tool failed: ${error}")
				Ok(contents) => {
					next_evidence = match actual.operation {
						ReadFile(_) => contents
						_ => evidence
					}
					reply(remaining, messages, next_evidence)
				}
			}
		}
	}
	_ => Err("Unexpected scripted conversation")
}

request = { review: { source: "feature", target: "main" }, history: [] }
expect Scripted.respond([Scripted.read_call], request) == Ok(ToolCall(Scripted.read_call))
expect Scripted.execute(Scripted.read_call) == { id: "read-auth", outcome: Ok("authorize = |_user| True") }
expect Scripted.execute({ id: "missing", operation: ReadFile("missing.roc") }) == { id: "missing", outcome: Err("Fixture file not found: missing.roc") }
expect {
	result = { id: "read-auth", outcome: Ok("observed fixture contents") }
	next = { ..request, history: [Assistant(ToolCall(Scripted.read_call)), ToolResult(result)] }
	Scripted.respond([Scripted.read_call], next) == Ok(Final([{ ..Scripted.finding, evidence: "observed fixture contents" }]))
}
expect {
	result = { id: "wrong-id", outcome: Ok("contents") }
	next = { ..request, history: [Assistant(ToolCall(Scripted.read_call)), ToolResult(result)] }
	Scripted.respond([Scripted.read_call], next) == Err("Unexpected scripted tool correlation")
}
expect Scripted.execute(Scripted.list_call).outcome == Ok("src/auth.roc\nsrc/main.roc")
expect Scripted.execute({ id: "search", operation: Search("not present") }).outcome == Ok("")
expect Scripted.execute(Scripted.search_call).outcome == Ok("src/auth.roc:1: authorize = |_user| True")
expect Scripted.execute(Scripted.diff_call).outcome == Ok("src/auth.roc\n-authorize = |user| user.is_admin\n+authorize = |_user| True")
