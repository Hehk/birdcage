import pf.Host
import pf.Stdout
import Model
import Report
import Tool

Scripted := [].{
	send! : Model.Send
	send! = |request, done| {
		Stdout.line!("Model request: ${request.review.source} into ${request.review.target}")
		Stdout.line!("History: ${Str.inspect(request.history)}")
		Host.defer!(Box.box(|| done.unbox()(respond(request))))
	}

	respond : Model.Request -> Try(Model.Response, Str)
	respond = |request| match request.history {
		[] => Ok(ToolCall(read_call))
		[Assistant(ToolCall(call)), ToolResult(result)] => {
			if call != read_call or result.id != call.id {
				Err("Unexpected scripted tool correlation")
			} else {
				match result.outcome {
					Ok(contents) => Ok(Final([{ ..finding, evidence: contents }]))
					Err(error) => Err("Fixture read failed: ${error}")
				}
			}
		}
		_ => Err("Unexpected scripted conversation")
	}

	run_tool! : Tool.Run
	run_tool! = |call, done| {
		Stdout.line!("Tool request: ${call.id} read_file ${call.path}")
		Host.defer!(
			Box.box(
				|| {
					result = read_file(call)
					Stdout.line!("Tool result: ${Str.inspect(result)}")
					done.unbox()(result)
				},
			),
		)
	}

	read_file : Tool.Call -> Tool.Result
	read_file = |call| {
		outcome = if call.path == "src/auth.roc" {
			Ok("authorize = |_user| True")
		} else {
			Err("Fixture file not found: ${call.path}")
		}
		{ id: call.id, outcome }
	}

	read_call : Tool.Call
	read_call = { id: "read-auth", path: "src/auth.roc" }

	finding : Report.Finding
	finding = {
		severity: High,
		location: At({ path: "src/auth.roc", line: 1 }),
		explanation: "The fixture authorizes every caller.",
		evidence: "authorize = |_user| True",
	}
}

request = { review: { source: "feature", target: "main" }, history: [] }
expect Scripted.respond(request) == Ok(ToolCall(Scripted.read_call))
expect Scripted.read_file(Scripted.read_call) == { id: "read-auth", outcome: Ok("authorize = |_user| True") }
expect Scripted.read_file({ id: "missing", path: "missing.roc" }) == { id: "missing", outcome: Err("Fixture file not found: missing.roc") }
expect {
	result = { id: "read-auth", outcome: Ok("observed fixture contents") }
	next = { ..request, history: [Assistant(ToolCall(Scripted.read_call)), ToolResult(result)] }
	Scripted.respond(next) == Ok(Final([{ ..Scripted.finding, evidence: "observed fixture contents" }]))
}
expect {
	result = { id: "wrong-id", outcome: Ok("contents") }
	next = { ..request, history: [Assistant(ToolCall(Scripted.read_call)), ToolResult(result)] }
	Scripted.respond(next) == Err("Unexpected scripted tool correlation")
}
