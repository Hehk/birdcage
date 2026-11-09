import Cli
import Model
import Report
import Tool

Review := [].{
	run! : Cli.Review, Model.Send, Tool.Run, Box(Try(List(Report.Finding), Str) => {}) => {}
	run! = |review, model!, tool!, done| {
		request = { review, history: [] }
		model!(
			request,
			Box.box(
				|response| {
					match response {
						Ok(ToolCall(call)) => tool!(
							call,
							Box.box(
								|result| {
									if result.id != call.id {
										done.unbox()(Err("Tool result has the wrong call ID"))
									} else {
										next = { ..request, history: [Assistant(ToolCall(call)), ToolResult(result)] }
										model!(next, Box.box(|last| finish!(last, done)))
									}
								},
							),
						)
						_ => finish!(response, done)
					}
				},
			),
		)
	}
}

finish! : Try(Model.Response, Str), Box(Try(List(Report.Finding), Str) => {}) => {}
finish! = |response, done| {
	result = match response {
		Err(error) => Err(error)
		Ok(Final(findings)) => Report.validate(findings)
		Ok(ToolCall(_)) => Err("Expected a final report after one tool call")
	}
	done.unbox()(result)
}
