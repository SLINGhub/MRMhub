use std::io::Write;
use std::sync::Mutex;
use std::sync::atomic::{AtomicUsize, Ordering};

// Keep native-to-WebView traffic bounded while still showing meaningful
// movement throughout longer workflow steps.
const MAX_UPDATES: usize = 25;

pub struct Reporter {
    total: usize,
    interval: usize,
    completed: AtomicUsize,
    reported: Mutex<usize>,
}

impl Reporter {
    pub fn new(total: usize) -> Self {
        Self {
            total,
            interval: interval(total),
            completed: AtomicUsize::new(0),
            reported: Mutex::new(0),
        }
    }

    // Parallel jobs may finish out of order, so serialize reports and only
    // expose the monotonic number of completed jobs.
    pub fn advance(&self, message: &str) -> usize {
        let current = self.completed.fetch_add(1, Ordering::Relaxed) + 1;
        self.set(current, message);
        current
    }

    // Sequential batches can report their absolute completed item count.
    pub fn set(&self, current: usize, message: &str) {
        let current = current.min(self.total);
        let mut previous = self.reported.lock().unwrap();
        if current <= *previous
            || (current != self.total && current.saturating_sub(*previous) < self.interval)
        {
            return;
        }
        emit(current, self.total, message);
        *previous = current;
    }
}

pub fn emit(current: usize, total: usize, message: &str) {
    let mut output = std::io::stdout().lock();
    let _ = writeln!(output, "Progress: {current}/{total} - {message}");
    let _ = output.flush();
}

fn interval(total: usize) -> usize {
    (total.saturating_add(MAX_UPDATES - 1) / MAX_UPDATES).max(1)
}

#[cfg(test)]
mod tests {
    use super::interval;

    #[test]
    fn progress_is_bounded_to_about_twenty_five_updates() {
        assert_eq!(interval(0), 1);
        assert_eq!(interval(10), 1);
        assert_eq!(interval(100), 4);
        assert_eq!(interval(1_000), 40);
    }
}
