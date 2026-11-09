import Cli
import Model
import Report
import Tool

Review := [].{
	run! : Cli.Review, Model.Send, Tool.Run, Box(Try(List(Report.Finding), Str) => {}) => {}
	run! = |review, model!, tool!, done| ask!({ review, history: [] }, model!, tool!, done)

	validate_calls : List(Tool.RawCall), List(Model.Message) -> Try({}, Str)
	validate_calls = |calls, history| {
		if calls.is_empty() {
			return Err("Model returned an empty tool-call batch")
		}
		var $seen = []
		for message in history {
			match message {
				Assistant(ToolCalls(previous)) => {
					$seen = $seen.concat(previous.map(|call| call.id))
				}
				_ => {}
			}
		}
		for call in calls {
			if call.id.trim().is_empty() {
				return Err("Model returned an empty tool-call ID")
			}
			if $seen.contains(call.id) {
				return Err("Model reused tool-call ID: ${call.id}")
			}
			$seen = $seen.append(call.id)
		}
		Ok({})
	}
}

ask! : Model.Request, Model.Send, Tool.Run, Box(Try(List(Report.Finding), Str) => {}) => {}
ask! = |request, model!, tool!, done| {
	model!(
		request,
		Box.box(
			|response| {
				match response {
					Err(error) => done.unbox()(Err(error))
					Ok(Final(findings)) => done.unbox()(Report.validate(findings))
					Ok(ToolCalls(calls)) => match Review.validate_calls(calls, request.history) {
						Err(error) => done.unbox()(Err(error))
						Ok({}) => {
							next = { ..request, history: request.history.append(Assistant(ToolCalls(calls))) }
							run_calls!(calls, next, model!, tool!, done)
						}
					}
				}
			},
		),
	)
}

run_calls! : List(Tool.RawCall), Model.Request, Model.Send, Tool.Run, Box(Try(List(Report.Finding), Str) => {}) => {}
run_calls! = |calls, request, model!, tool!, done| match calls {
	[] => ask!(request, model!, tool!, done)
	[raw, .. as remaining] => {
		returned! = |result| {
			if result.id != raw.id {
				done.unbox()(Err("Tool result has the wrong call ID"))
			} else {
				next = { ..request, history: request.history.append(ToolResult(result)) }
				run_calls!(remaining, next, model!, tool!, done)
			}
		}
		match Tool.validate(raw) {
			Err(error) => returned!({ id: raw.id, outcome: Err(error) })
			Ok(call) => tool!(call, Box.box(returned!))
		}
	}
}

call = { id: "a", name: "git_diff", arguments: [] }
expect Review.validate_calls([call], []) == Ok({})
expect Review.validate_calls([], []) == Err("Model returned an empty tool-call batch")
expect Review.validate_calls([{ ..call, id: " " }], []) == Err("Model returned an empty tool-call ID")
expect Review.validate_calls([call, call], []) == Err("Model reused tool-call ID: a")
expect Review.validate_calls([call], [Assistant(ToolCalls([call]))]) == Err("Model reused tool-call ID: a")
expect Review.validate_calls([{ ..call, id: "b" }], [Assistant(ToolCalls([call]))]) == Ok({})
