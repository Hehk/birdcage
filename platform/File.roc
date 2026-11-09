File := [].{
	read! : Str, Box(Try(Str, Str) => {}) => {}
	write! : Str, Str, Box(Try({}, Str) => {}) => {}
}
