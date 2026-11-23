import pf.Stdout
import pf.File

FileDemo := [].{
	run! = |path| {
		contents = Str.repeat("Async Roc → Rust → Roc 🦜\n", 16)
		File.write!(path, contents)?
		actual = File.read!(path)?
		if actual != contents {
			return Err("File round-trip mismatch")
		}
		Stdout.line!("File round-trip verified")
		Ok({})
	}
}
