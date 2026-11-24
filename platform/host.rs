#[rustfmt::skip]
#[allow(clippy::all)]
#[path = "../build/roc_platform_abi.rs"]
mod abi;
mod env;
mod files;
mod http;
mod random;

use std::cell::{Cell, RefCell};
use std::ffi::c_void;
use std::future::Future;
use std::io::{self, Write};
use std::ptr::{null_mut, NonNull};

use abi::{DefaultAllocators, DefaultHandlers, RocErasedCallable, RocStr};
thread_local! {
    static PENDING: RefCell<Vec<tokio::task::JoinHandle<()>>> = const { RefCell::new(Vec::new()) };
    static EXIT_CODE: Cell<Option<i32>> = const { Cell::new(None) };
}

fn main() -> std::process::ExitCode {
    let args: Result<Vec<_>, _> = std::env::args_os()
        .skip(1)
        .map(|arg| arg.into_string())
        .collect();
    let Ok(args) = args else {
        eprintln!("Arguments must be valid UTF-8");
        return std::process::ExitCode::from(2);
    };
    EXIT_CODE.set(None);
    let runtime = tokio::runtime::Builder::new_current_thread()
        .build()
        .unwrap();
    let status = tokio::task::LocalSet::new().block_on(&runtime, async {
        let status = unsafe { abi::roc_main(roc_strings(&args)) };
        loop {
            let next = PENDING.with(|pending| pending.borrow_mut().pop());
            let Some(next) = next else { break };
            next.await.expect("callback task failed");
        }
        EXIT_CODE.take().unwrap_or(status)
    });
    std::process::ExitCode::from(status as u8)
}

fn roc_strings(args: &[String]) -> abi::RocList<RocStr> {
    let host = abi::make_roc_host(null_mut());
    let list = unsafe { abi::RocList::<RocStr>::allocate(args.len(), &host) };
    for (index, arg) in args.iter().enumerate() {
        unsafe { list.elements.add(index).write(RocStr::from_str(arg, &host)) };
    }
    list
}

fn spawn(future: impl Future<Output = ()> + 'static) {
    let task = tokio::task::spawn_local(future);
    PENDING.with(|pending| pending.borrow_mut().push(task));
}

#[unsafe(no_mangle)]
extern "C" fn roc_defer(callback: RocErasedCallable) {
    spawn(async move {
        tokio::task::yield_now().await;
        unsafe { abi::roc_deferred(callback) };
    });
}

#[unsafe(no_mangle)]
extern "C" fn roc_exit_code(code: i32) {
    EXIT_CODE.set(Some(code));
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
    fn argument_lists_own_their_strings() {
        let host = abi::make_roc_host(null_mut());
        for args in [vec![], vec![String::new(), "short".into(), "🦜".repeat(64)]] {
            let list = roc_strings(&args);
            let actual: Vec<_> = list.as_slice().iter().map(|arg| arg.as_str()).collect();
            assert_eq!(actual, args);
            unsafe { abi::decref_list_of_str(list, &host) };
        }
    }

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
