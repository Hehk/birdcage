use std::cell::RefCell;
use std::future::Future;
use std::mem::ManuallyDrop;
use std::ptr::null_mut;

use crate::abi::{self, RocErasedCallable, RocStr};

thread_local! {
    static PENDING: RefCell<Vec<tokio::task::JoinHandle<()>>> = const { RefCell::new(Vec::new()) };
}

pub fn run() -> i32 {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .build()
        .unwrap();
    tokio::task::LocalSet::new().block_on(&runtime, async {
        let status = unsafe { abi::roc_main() };
        loop {
            let next = PENDING.with(|pending| pending.borrow_mut().pop());
            let Some(next) = next else { break };
            next.await.expect("file callback task failed");
        }
        status
    })
}

fn spawn(future: impl Future<Output = ()> + 'static) {
    let task = tokio::task::spawn_local(future);
    PENDING.with(|pending| pending.borrow_mut().push(task));
}

fn take_string(value: RocStr) -> String {
    let text = value.as_str().to_owned();
    unsafe { value.decref(&abi::make_roc_host(null_mut())) };
    text
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_read(path: RocStr, callback: RocErasedCallable) {
    let path = take_string(path);
    spawn(async move {
        let host = abi::make_roc_host(null_mut());
        let result = match tokio::fs::read_to_string(path).await {
            Ok(text) => abi::ReadCompletedArg1Result {
                tag: abi::ReadCompletedArg1ResultTag::Ok,
                payload: abi::ReadCompletedArg1ResultPayload {
                    ok: ManuallyDrop::new(RocStr::from_str(&text, &host)),
                },
            },
            Err(error) => abi::ReadCompletedArg1Result {
                tag: abi::ReadCompletedArg1ResultTag::Err,
                payload: abi::ReadCompletedArg1ResultPayload {
                    err: ManuallyDrop::new(RocStr::from_str(&error.to_string(), &host)),
                },
            },
        };
        // Ownership of both the callback and result transfers back to Roc.
        unsafe { abi::roc_read_completed(callback, result) };
    });
}

#[unsafe(no_mangle)]
extern "C" fn roc_file_write(path: RocStr, contents: RocStr, callback: RocErasedCallable) {
    let path = take_string(path);
    let contents = take_string(contents);
    spawn(async move {
        let result = match tokio::fs::write(path, contents).await {
            Ok(()) => abi::WriteCompletedArg1Result {
                tag: abi::WriteCompletedArg1ResultTag::Ok,
                payload: abi::WriteCompletedArg1ResultPayload { ok: [] },
            },
            Err(error) => abi::WriteCompletedArg1Result {
                tag: abi::WriteCompletedArg1ResultTag::Err,
                payload: abi::WriteCompletedArg1ResultPayload {
                    err: ManuallyDrop::new(RocStr::from_str(
                        &error.to_string(),
                        &abi::make_roc_host(null_mut()),
                    )),
                },
            },
        };
        unsafe { abi::roc_write_completed(callback, result) };
    });
}
