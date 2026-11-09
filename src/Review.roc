import Cli
import Model
import Report

Review := [].{
	run! : Cli.Review, Model.Send, Box(Try(List(Report.Finding), Str) => {}) => {}
	run! = |review, model!, done| {
		model!(
			{ review: review },
			Box.box(
				|response| {
					result = match response {
						Err(error) => Err(error)
						Ok(Final(findings)) => Report.validate(findings)
					}
					done.unbox()(result)
				},
			),
		)
	}
}
