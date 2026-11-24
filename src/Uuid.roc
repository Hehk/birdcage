import pf.Random

Uuid := [].{
	v4! : () => Try(Str, [RandomFailure(Str)])
	v4! = || {
		bytes = Random.bytes!(16)?
		Ok(format_v4(bytes))
	}
}

format_v4 : List(U8) -> Str
format_v4 = |bytes| {
	var $text = []
	var $index = 0
	for byte in bytes {
		if $index == 4 or $index == 6 or $index == 8 or $index == 10 {
			$text = $text.append(45)
		}
		value = match $index {
			6 => byte.bitwise_and(0x0f).bitwise_or(0x40)
			8 => byte.bitwise_and(0x3f).bitwise_or(0x80)
			_ => byte
		}
		$text = $text.append(hex_digit(value / 16)).append(hex_digit(value % 16))
		$index = $index + 1
	}
	Str.from_utf8_lossy($text)
}

hex_digit : U8 -> U8
hex_digit = |nibble| if nibble < 10 {
	48 + nibble
} else {
	87 + nibble
}

expect format_v4([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]) == "00000000-0000-4000-8000-000000000000"

expect format_v4([0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0xff, 0xab, 0xff, 0xcd, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]) == "91929394-9596-4fab-bfcd-aabbccddeeff"
