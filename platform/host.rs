#[rustfmt::skip]
#[allow(clippy::all)]
#[path = "../build/roc_platform_abi.rs"]
mod abi;
mod files;
mod runtime;

use std::ffi::c_void;
use std::io::{self, Write};
use std::ptr::{null_mut, NonNull};

use abi::{DefaultAllocators, DefaultHandlers, RocStr};

fn main() -> std::process::ExitCode {
    let args: Result<Vec<_>, _> = std::env::args_os()
        .skip(1)
        .map(|arg| arg.into_string())
        .collect();
    let Ok(args) = args else {
        eprintln!("Arguments must be valid UTF-8");
        return std::process::ExitCode::from(2);
    };
    std::process::ExitCode::from(runtime::run(&args) as u8)
}

#[unsafe(no_mangle)]
extern "C" fn roc_stdout_line(message: RocStr) {
    let result = writeln!(io::stdout().lock(), "{}", message.as_str());
    unsafe { message.decref(&abi::make_roc_host(null_mut())) };
    if let Err(error) = result {
        eprintln!("stdout: {error}");
        std::process::exit(1);
    }
}

#[unsafe(no_mangle)]
extern "C" fn roc_stderr_line(message: RocStr) {
    let result = writeln!(io::stderr().lock(), "{}", message.as_str());
    unsafe { message.decref(&abi::make_roc_host(null_mut())) };
    if result.is_err() {
        std::process::exit(1);
    }
}

#[unsafe(no_mangle)]
extern "C" fn roc_alloc(length: usize, alignment: usize) -> NonNull<c_void> {
    DefaultAllocators::roc_alloc(null_mut(), length, alignment)
}

#[unsafe(no_mangle)]
extern "C" fn roc_dealloc(ptr: *mut c_void, alignment: usize) {
    DefaultAllocators::roc_dealloc(null_mut(), ptr, alignment);
}

#[unsafe(no_mangle)]
extern "C" fn roc_realloc(
    ptr: *mut c_void,
    new_length: usize,
    alignment: usize,
) -> NonNull<c_void> {
    DefaultAllocators::roc_realloc(null_mut(), ptr, new_length, alignment)
}

#[unsafe(no_mangle)]
extern "C" fn roc_dbg(bytes: *const u8, len: usize) {
    DefaultHandlers::roc_dbg(null_mut(), bytes, len);
}

#[unsafe(no_mangle)]
extern "C" fn roc_expect_failed(bytes: *const u8, len: usize) {
    DefaultHandlers::roc_expect_failed(null_mut(), bytes, len);
}

#[unsafe(no_mangle)]
extern "C" fn roc_crashed(bytes: *const u8, len: usize) {
    DefaultHandlers::roc_crashed(null_mut(), bytes, len);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roc_strings_round_trip() {
        let host = abi::make_roc_host(null_mut());
        for text in ["".to_owned(), "hello".to_owned(), "🦜".repeat(32)] {
            let value = RocStr::from_str(&text, &host);
            assert_eq!(value.as_str(), text);
            unsafe { value.decref(&host) };
        }
    }
}
