import Cli
import Report
import Tool

Model := [].{
	Request : { review : Cli.Review, history : List(Message) }
	Message : [Assistant(Response), ToolResult(Tool.Result)]
	Response : [Final(List(Report.Finding)), ToolCalls(List(Tool.RawCall))]
	Send : Request, Box(Try(Response, Str) => {}) => {}
}
