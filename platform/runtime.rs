use std::cell::{Cell, RefCell};
use std::future::Future;
use std::ptr::null_mut;

use crate::abi::{self, RocErasedCallable, RocStr};

thread_local! {
    static PENDING: RefCell<Vec<tokio::task::JoinHandle<()>>> = const { RefCell::new(Vec::new()) };
    static EXIT_CODE: Cell<Option<i32>> = const { Cell::new(None) };
}

pub fn run(args: &[String]) -> i32 {
    EXIT_CODE.set(None);
    let runtime = tokio::runtime::Builder::new_current_thread()
        .build()
        .unwrap();
    tokio::task::LocalSet::new().block_on(&runtime, async {
        let status = unsafe { abi::roc_main(arguments(args)) };
        loop {
            let next = PENDING.with(|pending| pending.borrow_mut().pop());
            let Some(next) = next else { break };
            next.await.expect("callback task failed");
        }
        EXIT_CODE.take().unwrap_or(status)
    })
}

fn arguments(args: &[String]) -> abi::RocList<RocStr> {
    let host = abi::make_roc_host(null_mut());
    let list = unsafe { abi::RocList::<RocStr>::allocate(args.len(), &host) };
    for (index, arg) in args.iter().enumerate() {
        unsafe { list.elements.add(index).write(RocStr::from_str(arg, &host)) };
    }
    list
}

pub fn spawn(future: impl Future<Output = ()> + 'static) {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn argument_lists_own_their_strings() {
        let host = abi::make_roc_host(null_mut());
        for args in [vec![], vec![String::new(), "short".into(), "🦜".repeat(64)]] {
            let list = arguments(&args);
            let actual: Vec<_> = list.as_slice().iter().map(|arg| arg.as_str()).collect();
            assert_eq!(actual, args);
            unsafe { abi::decref_list_of_str(list, &host) };
        }
    }
}
