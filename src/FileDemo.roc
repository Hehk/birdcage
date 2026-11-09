import pf.Stdout
import pf.File

FileDemo := [].{
	run! = |path| {
		contents = Str.repeat("Async Roc → Rust → Roc 🦜\n", 16)
		File.write!(
			path,
			contents,
			Box.box(
				|written| {
					match written {
						Err(error) => crash error
						Ok({}) => File.read!(
							path,
							Box.box(
								|read| {
									match read {
										Err(error) => crash error
										Ok(actual) => {
											if actual != contents {
												crash "File round-trip mismatch"
											}
											Stdout.line!("File round-trip verified")
										}
									}
								},
							),
						)
					}
				},
			),
		)
		Stdout.line!("File I/O submitted")
	}
}
