use super::*;
use std::io::Write;
use std::path::PathBuf;
use std::sync::atomic::AtomicU64;

static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(0);

struct Fixture(PathBuf);

impl Fixture {
    fn new(count: usize) -> Self {
        let path = std::env::temp_dir().join(format!(
            "mrmhub-selection-test-{}-{}",
            std::process::id(),
            NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        fs::write(path.join("trans_R.csv"), "id,name\nT0000,Compound\n").unwrap();
        fs::write(path.join("mzML_list.txt"), "sample.mzML\n").unwrap();
        let mut traces = Vec::new();
        let mut peaks = vec![0];
        for index in 0..count {
            traces.extend_from_slice(&[0; 7]);
            peaks.extend_from_slice(&(index as f32).to_le_bytes());
        }
        fs::write(path.join("te_0000"), traces).unwrap();
        fs::write(path.join("tp_0000"), peaks).unwrap();
        Self(path)
    }

    fn state(&self) -> AppState {
        AppState::new(self.0.clone())
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn transition() -> Selection {
    Selection::new("transition", "0000").unwrap()
}

#[test]
fn batches_preserve_order_and_deliver_final_partial_before_completion() {
    let fixture = Fixture::new(35);
    let catalog = get_catalog_blocking(&fixture.0).unwrap();
    let mut events = Vec::new();
    load_selection_blocking(
        &fixture.state(),
        &transition(),
        "request-a",
        Some(&catalog.version),
        &AtomicBool::new(false),
        |event| {
            events.push(event);
            Ok(())
        },
    )
    .unwrap();
    assert!(
        matches!(&events[0], SelectionEvent::Qc { request_id, groups } if request_id == "request-a" && groups.is_empty())
    );
    for (event, expected_start, expected_len) in [
        (&events[1], 0, 16),
        (&events[2], 16, 16),
        (&events[3], 32, 3),
    ] {
        let SelectionEvent::Traces {
            request_id,
            start,
            traces,
        } = event
        else {
            panic!("Expected ordered trace batch");
        };
        assert_eq!(request_id, "request-a");
        assert_eq!(*start, expected_start);
        assert_eq!(traces.len(), expected_len);
        for (offset, record) in traces.iter().enumerate() {
            assert_eq!(record.sh, (expected_start + offset) as f32);
        }
    }
    let SelectionEvent::Complete {
        request_id,
        count,
        version,
    } = &events[4]
    else {
        panic!("Expected explicit completion after the partial batch");
    };
    assert_eq!(request_id, "request-a");
    assert_eq!(*count, 35);
    assert_eq!(
        *version,
        selection_snapshot(&fixture.0, &transition())
            .unwrap()
            .version()
            .unwrap()
    );
    assert_eq!(events.len(), 5);
    let catalog_json = serde_json::to_value(catalog).unwrap();
    assert!(catalog_json.get("transCsv").is_some());
    assert!(catalog_json.get("mzmlTsv").is_some());
    assert_eq!(
        serde_json::to_value(&events[1]).unwrap()["requestId"],
        "request-a"
    );
}

#[test]
fn cancellation_before_registration_and_during_load_cannot_cancel_a_new_request() {
    let fixture = Fixture::new(40);
    let state = fixture.state();
    state.cancel("queued").unwrap();
    assert!(state.register("queued").is_err());
    let old = state.register("old").unwrap();
    let current = state.register("current").unwrap();
    assert!(state.register("old").is_err());
    let mut batches = 0;
    let result = load_selection_blocking(&state, &transition(), "old", None, &old.flag, |event| {
        if matches!(event, SelectionEvent::Traces { .. }) {
            batches += 1;
            state.cancel("old")?;
        }
        assert!(!matches!(event, SelectionEvent::Complete { .. }));
        Ok(())
    });
    assert!(result.unwrap_err().to_string().contains("cancelled"));
    assert_eq!(batches, 1);
    assert!(check_cancel(&current.flag).is_ok());
    drop(old);
    assert!(!state.requests.lock().unwrap().active.contains_key("old"));
    drop(current);
    assert!(state.requests.lock().unwrap().active.is_empty());
    for index in 0..CANCEL_HISTORY + 5 {
        state.cancel(&format!("cancel-{index}")).unwrap();
    }
    let requests = state.requests.lock().unwrap();
    assert_eq!(requests.cancelled.len(), CANCEL_HISTORY);
    assert_eq!(requests.cancel_order.len(), CANCEL_HISTORY);
    assert!(requests
        .cancelled
        .contains(&format!("cancel-{}", CANCEL_HISTORY + 4)));
}

#[test]
fn cancel_after_qc_stops_before_any_trace_is_sent() {
    let fixture = Fixture::new(20);
    let flag = AtomicBool::new(false);
    let mut events = 0;
    let result = load_selection_blocking(
        &fixture.state(),
        &transition(),
        "stop",
        None,
        &flag,
        |event| {
            assert!(matches!(event, SelectionEvent::Qc { .. }));
            events += 1;
            flag.store(true, Ordering::Release);
            Ok(())
        },
    );
    assert_eq!(result.unwrap_err().kind(), io::ErrorKind::Interrupted);
    assert_eq!(events, 1);
}

#[test]
fn changed_catalog_and_changed_stream_never_publish_completion() {
    let fixture = Fixture::new(17);
    let state = fixture.state();
    let old_catalog = get_catalog_blocking(&fixture.0).unwrap();
    fs::write(fixture.0.join("mzML_list.txt"), "replacement-label.mzML\n").unwrap();
    let result = load_selection_blocking(
        &state,
        &transition(),
        "catalog",
        Some(&old_catalog.version),
        &AtomicBool::new(false),
        |_| {
            panic!("A stale catalog must fail before sending data");
        },
    );
    assert!(result.unwrap_err().to_string().contains("Catalog changed"));
    let mut batches = 0;
    let result = load_selection_blocking(
        &state,
        &transition(),
        "changed",
        None,
        &AtomicBool::new(false),
        |event| {
            if let SelectionEvent::Traces { start: 16, .. } = event {
                File::options()
                    .append(true)
                    .open(fixture.0.join("trans_R.csv"))?
                    .write_all(b"T0001,New\n")?;
            }
            if matches!(event, SelectionEvent::Traces { .. }) {
                batches += 1;
            }
            assert!(!matches!(event, SelectionEvent::Complete { .. }));
            Ok(())
        },
    );
    assert_eq!(batches, 2);
    assert!(result
        .unwrap_err()
        .to_string()
        .contains("changed while loading"));
}

#[test]
fn truncated_stream_never_publishes_completion() {
    let fixture = Fixture::new(20);
    File::options()
        .write(true)
        .open(fixture.0.join("tp_0000"))
        .unwrap()
        .set_len(1 + 19 * 4 + 1)
        .unwrap();
    let mut batches = 0;
    let result = load_selection_blocking(
        &fixture.state(),
        &transition(),
        "partial",
        None,
        &AtomicBool::new(false),
        |event| {
            if matches!(event, SelectionEvent::Traces { .. }) {
                batches += 1;
            }
            assert!(!matches!(event, SelectionEvent::Complete { .. }));
            Ok(())
        },
    );
    assert!(result.is_err());
    assert_eq!(batches, 1);
}

#[test]
fn selection_versions_detect_optional_file_appearance_and_catalog_changes() {
    let fixture = Fixture::new(1);
    let selection = transition();
    let initial = selection_snapshot(&fixture.0, &selection).unwrap();
    assert_eq!(initial, selection_snapshot(&fixture.0, &selection).unwrap());
    fs::write(fixture.0.join("long.bin"), [0, 0]).unwrap();
    let with_qc = selection_snapshot(&fixture.0, &selection).unwrap();
    assert_ne!(initial, with_qc);
    fs::write(fixture.0.join("mzML_list.txt"), "new sample names\n").unwrap();
    assert_ne!(with_qc, selection_snapshot(&fixture.0, &selection).unwrap());
    assert!(Selection::new("transition", "../0000").is_err());
    assert!(Selection::new("reference", "tp_0000").is_err());
}

#[test]
#[cfg(unix)]
fn version_detects_same_size_same_modified_time_atomic_replacement() {
    let fixture = Fixture::new(1);
    let path = fixture.0.join("tp_0000");
    let original = FileStamp::read(&path).unwrap();
    let replacement = fixture.0.join("replacement");
    fs::write(&replacement, fs::read(&path).unwrap()).unwrap();
    File::options()
        .write(true)
        .open(&replacement)
        .unwrap()
        .set_modified(original.modified)
        .unwrap();
    fs::rename(&replacement, &path).unwrap();
    let updated = FileStamp::read(&path).unwrap();
    assert_eq!(original.len, updated.len);
    assert_eq!(original.modified, updated.modified);
    assert_ne!(original, updated);
}

#[test]
#[ignore = "Requires the external regression dataset in MRMHUB_TEST_DATA_DIR"]
fn external_batched_pipeline_preserves_trace_and_qc_counts() {
    let root =
        PathBuf::from(std::env::var_os("MRMHUB_TEST_DATA_DIR").expect("Set MRMHUB_TEST_DATA_DIR"));
    let state = AppState::new(root.clone());
    let catalog = get_catalog_blocking(&root).unwrap();
    for key in ["0000", "0005", "0245"] {
        let mut count = 0;
        let mut batches = 0;
        let mut complete = false;
        load_selection_blocking(
            &state,
            &Selection::new("transition", key).unwrap(),
            key,
            Some(&catalog.version),
            &AtomicBool::new(false),
            |event| {
                match event {
                    SelectionEvent::Qc { groups, .. } => {
                        assert!(groups.iter().all(|(_, values)| values.len() == 4558));
                        if key == "0245" {
                            assert_eq!(groups[0].0, groups[1].0);
                            assert_eq!(groups[0].1[0].area, groups[1].1[0].area);
                        }
                    }
                    SelectionEvent::Traces { start, traces, .. } => {
                        assert_eq!(start, count);
                        assert!((1..=BATCH_SIZE).contains(&traces.len()));
                        count += traces.len();
                        batches += 1;
                    }
                    SelectionEvent::Complete {
                        count: final_count, ..
                    } => {
                        assert_eq!(count, final_count);
                        complete = true;
                    }
                }
                Ok(())
            },
        )
        .unwrap();
        assert_eq!(count, 4558);
        assert_eq!(batches, 285);
        assert!(complete);
    }
    for name in catalog.references {
        let mut count = 0;
        load_selection_blocking(
            &state,
            &Selection::new("reference", &name).unwrap(),
            &name,
            Some(&catalog.version),
            &AtomicBool::new(false),
            |event| {
                if let SelectionEvent::Traces { start, traces, .. } = event {
                    assert_eq!(start, count);
                    count += traces.len();
                }
                Ok(())
            },
        )
        .unwrap();
        assert_eq!(count, 696);
    }
}
