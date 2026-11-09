import Cli
import Model
import Report
import Tool

Review := [].{
	run! : Cli.Review, Model.Send, Tool.Run, Box(Try(List(Report.Finding), Str) => {}) => {}
	run! = |review, model!, tool!, done| ask!({ review, history: [] }, model!, tool!, done)
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
					Ok(ToolCall(call)) => tool!(
						call,
						Box.box(
							|result| {
								if result.id != call.id {
									done.unbox()(Err("Tool result has the wrong call ID"))
								} else {
									next = { ..request, history: request.history.concat([Assistant(ToolCall(call)), ToolResult(result)]) }
									ask!(next, model!, tool!, done)
								}
							},
						),
					)
				}
			},
		),
	)
}
