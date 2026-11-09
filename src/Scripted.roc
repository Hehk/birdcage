import pf.Host
import pf.Stdout
import Model
import Report
import Tool

Scripted := [].{
	Script : { rounds : List(List(Tool.RawCall)), final : Try(List(Report.Finding), Str), wrong_id : Bool }

	select : Str -> Try(Script, Str)
	select = |name| match name {
		"diff-first" => Ok(scenario([[diff_call], [list_call], [search_call], [read_call]]))
		"search-first" => Ok(scenario([[search_call], [read_call], [diff_call]]))
		"single-read" => Ok(scenario([[read_call]]))
		"final" => Ok(scenario([]))
		"batch" => Ok(scenario([[diff_call, list_call, search_call, read_call]]))
		"tool-errors" => Ok(
			scenario([
				[
					{ id: "shell", name: "shell", arguments: [{ name: "command", value: "touch unexpected-shell-write" }] },
					{ ..read_call, id: "bad-args", arguments: [] },
					{ ..read_call, id: "escape", arguments: [{ name: "path", value: "../../etc/passwd" }] },
					{ ..read_call, id: "missing", arguments: [{ name: "path", value: "missing.roc" }] },
				],
				[read_call],
			]),
		)
		"duplicate-ids" => Ok(scenario([[read_call, read_call]]))
		"reused-id" => Ok(scenario([[read_call], [read_call]]))
		"empty-id" => Ok(scenario([[{ ..read_call, id: "" }]]))
		"empty-calls" => Ok(scenario([[]]))
		"wrong-result-id" => Ok({ ..scenario([[read_call]]), wrong_id: True })
		"invalid-report" => Ok({ ..scenario([]), final: Ok([{ ..finding, explanation: "" }]) })
		"model-error" => Ok({ ..scenario([]), final: Err("Scripted model transport failure") })
		_ => Err("Unknown script: ${name}")
	}

	send! : Script, Model.Request, Box(Try(Model.Response, Str) => {}) => {}
	send! = |script, request, done| {
		Stdout.line!("Model request: ${request.review.source} into ${request.review.target}")
		Stdout.line!("History: ${Str.inspect(request.history)}")
		Host.defer!(Box.box(|| done.unbox()(respond(script, request))))
	}

	respond : Script, Model.Request -> Try(Model.Response, Str)
	respond = |script, request| reply(script.rounds, request.history, script.final)

	run_tool! : Script, Tool.Call, Box(Tool.Result => {}) => {}
	run_tool! = |script, call, done| {
		Stdout.line!("Tool request: ${Tool.label(call)}")
		Host.defer!(
			Box.box(
				|| {
					observed = execute(call)
					result = if script.wrong_id {
						{ ..observed, id: "wrong-id" }
					} else {
						observed
					}
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

	read_call : Tool.RawCall
	read_call = { id: "read-auth", name: "read_file", arguments: [{ name: "path", value: "src/auth.roc" }] }
	list_call : Tool.RawCall
	list_call = { id: "list-src", name: "list_files", arguments: [{ name: "path", value: "src" }] }
	search_call : Tool.RawCall
	search_call = { id: "search-auth", name: "search", arguments: [{ name: "query", value: "authorize" }] }
	diff_call : Tool.RawCall
	diff_call = { id: "diff", name: "git_diff", arguments: [] }

	finding : Report.Finding
	finding = {
		severity: High,
		location: At({ path: "src/auth.roc", line: 1 }),
		explanation: "The fixture authorizes every caller.",
		evidence: "authorize = |_user| True",
	}
}

scenario : List(List(Tool.RawCall)) -> Scripted.Script
scenario = |rounds| { rounds, final: Ok([Scripted.finding]), wrong_id: False }

reply : List(List(Tool.RawCall)), List(Model.Message), Try(List(Report.Finding), Str) -> Try(Model.Response, Str)
reply = |rounds, history, final| match (rounds, history) {
	([], []) => match final {
		Ok(findings) => Ok(Final(findings))
		Err(error) => Err(error)
	}
	([calls, ..], []) => Ok(ToolCalls(calls))
	([expected, .. as remaining], [Assistant(ToolCalls(actual)), .. as messages]) => {
		if actual != expected {
			return Err("Unexpected scripted tool calls")
		}
		observed = consume_results(expected, messages, final)?
		reply(remaining, observed.messages, observed.final)
	}
	_ => Err("Unexpected scripted conversation")
}

consume_results = |calls, history, final| match (calls, history) {
	([], _) => Ok({ messages: history, final })
	([call, .. as remaining], [ToolResult(result), .. as messages]) => {
		if result.id != call.id {
			return Err("Unexpected scripted tool correlation")
		}
		next = match (call.name, call.arguments, result.outcome, final) {
			("read_file", [{ name: "path", value: "src/auth.roc" }], Ok(contents), Ok(findings)) =>
				Ok(findings.map(|finding| { ..finding, evidence: contents }))
			_ => final
		}
		consume_results(remaining, messages, next)
	}
	_ => Err("Missing scripted tool result")
}

request = { review: { source: "feature", target: "main" }, history: [] }
expect Scripted.respond(scenario([[Scripted.read_call]]), request) == Ok(ToolCalls([Scripted.read_call]))
expect Scripted.execute({ id: "read-auth", operation: ReadFile("src/auth.roc") }) == { id: "read-auth", outcome: Ok("authorize = |_user| True") }
expect Scripted.execute({ id: "missing", operation: ReadFile("missing.roc") }) == { id: "missing", outcome: Err("Fixture file not found: missing.roc") }
expect {
	result = { id: "read-auth", outcome: Ok("observed fixture contents") }
	next = { ..request, history: [Assistant(ToolCalls([Scripted.read_call])), ToolResult(result)] }
	Scripted.respond(scenario([[Scripted.read_call]]), next) == Ok(Final([{ ..Scripted.finding, evidence: "observed fixture contents" }]))
}
expect {
	result = { id: "wrong-id", outcome: Ok("contents") }
	next = { ..request, history: [Assistant(ToolCalls([Scripted.read_call])), ToolResult(result)] }
	Scripted.respond(scenario([[Scripted.read_call]]), next) == Err("Unexpected scripted tool correlation")
}
expect {
	next = { ..request, history: [Assistant(ToolCalls([Scripted.diff_call, Scripted.read_call])), ToolResult({ id: "diff", outcome: Ok("diff") })] }
	Scripted.respond(scenario([[Scripted.diff_call, Scripted.read_call]]), next) == Err("Missing scripted tool result")
}
expect Scripted.execute({ id: "list", operation: ListFiles("src") }).outcome == Ok("src/auth.roc\nsrc/main.roc")
expect Scripted.execute({ id: "search", operation: Search("not present") }).outcome == Ok("")
expect Scripted.execute({ id: "search", operation: Search("authorize") }).outcome == Ok("src/auth.roc:1: authorize = |_user| True")
expect Scripted.execute({ id: "diff", operation: GitDiff }).outcome == Ok("src/auth.roc\n-authorize = |user| user.is_admin\n+authorize = |_user| True")
