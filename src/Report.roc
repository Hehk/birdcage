Report := [].{
	Finding : {
		severity : [High, Medium, Low],
		location : [NoLocation, At({ path : Str, line : U64 })],
		explanation : Str,
		evidence : Str,
	}

	validate : List(Finding) -> Try(List(Finding), Str)
	validate = |findings| {
		for finding in findings {
			if finding.explanation.trim().is_empty() or finding.evidence.trim().is_empty() {
				return Err("A finding needs an explanation and evidence")
			}
			match finding.location {
				NoLocation => {}
				At(location) => {
					if location.path.trim().is_empty() or location.line == 0 {
						return Err("A finding location needs a path and a positive line number")
					}
				}
			}
		}
		Ok(findings)
	}

	render : List(Finding) -> Str
	render = |findings| {
		var $text = "Scripted review report (${findings.len().to_str()} findings)"
		for finding in findings {
			severity = match finding.severity {
				High => "high"
				Medium => "medium"
				Low => "low"
			}
			location = match finding.location {
				NoLocation => ""
				At(at) => " ${at.path}:${at.line.to_str()}"
			}
			$text = "${$text}\n[${severity}]${location} ${finding.explanation}\nEvidence: ${finding.evidence}"
		}
		$text
	}
}

sample : Report.Finding
sample = { severity: High, location: At({ path: "src/auth.roc", line: 2 }), explanation: "Missing check", evidence: "authorize = |_| True" }

expect Report.validate([sample]) == Ok([sample])
expect Report.validate([]) == Ok([])
expect Report.validate([{ ..sample, evidence: " " }]) == Err("A finding needs an explanation and evidence")
expect Report.validate([{ ..sample, location: At({ path: "x", line: 0 }) }]) == Err("A finding location needs a path and a positive line number")
expect Report.validate([{ ..sample, location: NoLocation }]) == Ok([{ ..sample, location: NoLocation }])
expect Report.render([sample]) == "Scripted review report (1 findings)\n[high] src/auth.roc:2 Missing check\nEvidence: authorize = |_| True"
