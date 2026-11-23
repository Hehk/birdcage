Http := [].{
	Header : { name : Str, value : Str }
	Request : { method : Str, url : Str, headers : List(Header), body : List(U8), timeout_ms : U64 }
	Response : { status : U16, headers : List(Header), body : List(U8) }

	send! : Request => Try(Response, Str)
}
