import Cli
import Report

Model := [].{
	Request : { review : Cli.Review }
	Response : [Final(List(Report.Finding))]
	Send : Request, Box(Try(Response, Str) => {}) => {}
}
