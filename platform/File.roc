File := [].{
	ErrorKind : [NotFound, PermissionDenied, ConnectionRefused, ConnectionReset, ConnectionAborted, NotConnected, AddrInUse, AddrNotAvailable, BrokenPipe, AlreadyExists, WouldBlock, InvalidInput, InvalidData, TimedOut, WriteZero, Interrupted, Unsupported, UnexpectedEof, OutOfMemory, Other]
	Error : { kind : ErrorKind, os_code : [OsCode(I32), NoOsCode], detail : Str }

	read! : Str => Try(Str, Error)
	write! : Str, Str => Try({}, Error)
	create_dir_all! : Str => Try({}, Error)
	append! : Str, Str => Try({}, Error)
	create_new! : Str, Str => Try({}, Error)
	list_files! : Str => Try(List(Str), Error)
}
