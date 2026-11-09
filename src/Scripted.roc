import pf.Host
import pf.Stdout
import Model
import Report

Scripted := [].{
	send! : Model.Send
	send! = |request, done| {
		Stdout.line!("Model request: ${request.review.source} into ${request.review.target}")
		Host.defer!(Box.box(|| done.unbox()(respond(request))))
	}

	respond : Model.Request -> Try(Model.Response, Str)
	respond = |_request| Ok(Final([finding]))

	finding : Report.Finding
	finding = {
		severity: High,
		location: At({ path: "src/auth.roc", line: 2 }),
		explanation: "The fixture authorizes every caller.",
		evidence: "authorize = |_user| True",
	}
}

expect Scripted.respond({ review: { source: "feature", target: "main" } }) == Ok(Final([Scripted.finding]))
