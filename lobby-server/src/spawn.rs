use std::future::Future;

use futures_util::future::{select, Either};
use tokio::{
    spawn,
    task::{JoinError, JoinHandle},
};

/// Spawns two new tasks and returns the result of the first to resolve.
///
/// When one of the tasks resolves, the other is aborted.
pub async fn spawn_paired<F1, F2>(
    future1: F1,
    future2: F2,
) -> Either<Result<F1::Output, JoinError>, Result<F2::Output, JoinError>>
where
    F1: Future + Send + 'static,
    F1::Output: Send + 'static,
    F2: Future + Send + 'static,
    F2::Output: Send + 'static,
{
    let task1: JoinHandle<F1::Output> = spawn(future1);
    let task2: JoinHandle<F2::Output> = spawn(future2);

    match select(task1, task2).await {
        Either::Left((result, right)) => {
            right.abort();
            Either::Left(result)
        }
        Either::Right((result, left)) => {
            left.abort();
            Either::Right(result)
        }
    }
}
