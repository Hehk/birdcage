Tool := [].{
	Call : { id : Str, path : Str }
	Result : { id : Str, outcome : Try(Str, Str) }
	Run : Call, Box(Result => {}) => {}
}
