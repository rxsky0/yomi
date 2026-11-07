//! Counts the characters you read by watching the clipboard.
//!
//! Text hookers (Textractor with its "Copy to Clipboard" extension, LunaTranslator,
//! Agent…) copy every new line of the VN to the clipboard. While the VN is the
//! active window, each new line is counted and added to the VN's `chars_read`
//! total and its `chars_daily` history.

use std::sync::Arc;
use std::time::{Duration, Instant};

use windows::Win32::Foundation::HGLOBAL;
use windows::Win32::System::DataExchange::{
    CloseClipboard, GetClipboardData, GetClipboardSequenceNumber, OpenClipboard,
};
use windows::Win32::System::Memory::{GlobalLock, GlobalUnlock};

use crate::state::Shared;
use crate::winapi;

const CF_UNICODETEXT: u32 = 13;
const POLL: Duration = Duration::from_millis(400);
const FLUSH_EVERY: Duration = Duration::from_secs(15);
/// A VN line is short. Anything longer is almost always something you copied yourself.
const MAX_LINE_CHARS: usize = 600;
/// Never read more than this from the clipboard, whatever is on it.
const MAX_READ_UNITS: usize = 16 * 1024;

/// Characters that count as "read": letters, digits, kana and kanji.
/// Spaces and punctuation are left out, like most reading trackers do.
pub fn count_chars(line: &str) -> i64 {
    line.chars().filter(|c| c.is_alphanumeric()).count() as i64
}

/// What a newly copied text adds to the count. Repeats of the previous line and
/// texts too long to be a VN line add nothing.
pub fn new_chars(text: &str, previous: &str) -> i64 {
    let line = text.trim();
    if line.is_empty() || line == previous.trim() || line.chars().count() > MAX_LINE_CHARS {
        return 0;
    }
    count_chars(line)
}

pub fn run(shared: Arc<Shared>) {
    let mut last_seq = unsafe { GetClipboardSequenceNumber() };
    let mut last_line = String::new();
    let mut pending: i64 = 0;
    let mut pending_key = String::new();
    let mut last_flush = Instant::now();

    loop {
        std::thread::sleep(POLL);

        let seq = unsafe { GetClipboardSequenceNumber() };
        if seq != last_seq {
            last_seq = seq;
            if enabled(&shared) {
                let snap = shared.snapshot();
                let vn_in_front = {
                    let front = winapi::foreground_window();
                    front != 0
                        && (front == snap.hwnd
                            || (snap.pid != 0 && winapi::window_pid(front) == snap.pid))
                };
                if snap.detected && !snap.idle && !snap.key.is_empty() && vn_in_front {
                    if snap.key != pending_key {
                        flush(&shared, &pending_key, &mut pending);
                        pending_key = snap.key.clone();
                    }
                    if let Some(text) = read_clipboard_text() {
                        let added = new_chars(&text, &last_line);
                        if added > 0 {
                            pending += added;
                            last_line = text.trim().to_string();
                        }
                    }
                }
            }
        }

        if pending > 0 && last_flush.elapsed() >= FLUSH_EVERY {
            flush(&shared, &pending_key, &mut pending);
            last_flush = Instant::now();
        }
    }
}

fn enabled(shared: &Shared) -> bool {
    shared
        .config
        .lock()
        .map(|cfg| cfg.bool("chars_tracking"))
        .unwrap_or(false)
}

fn flush(shared: &Shared, key: &str, pending: &mut i64) {
    if *pending > 0 && !key.is_empty() {
        if let Ok(mut cfg) = shared.config.lock() {
            cfg.add_chars(key, *pending);
        }
        shared.emit("library-changed", serde_json::json!({ "key": key }));
    }
    *pending = 0;
}

fn read_clipboard_text() -> Option<String> {
    unsafe {
        OpenClipboard(None).ok()?;
        let text = read_open_clipboard();
        let _ = CloseClipboard();
        text
    }
}

unsafe fn read_open_clipboard() -> Option<String> {
    let handle = GetClipboardData(CF_UNICODETEXT).ok()?;
    let global = HGLOBAL(handle.0);
    let ptr = GlobalLock(global) as *const u16;
    if ptr.is_null() {
        return None;
    }
    let mut len = 0;
    while len < MAX_READ_UNITS && *ptr.add(len) != 0 {
        len += 1;
    }
    let text = String::from_utf16_lossy(std::slice::from_raw_parts(ptr, len));
    let _ = GlobalUnlock(global);
    Some(text)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counts_letters_and_japanese_but_not_punctuation() {
        assert_eq!(count_chars("「おはよう、先輩！」"), 6);
        assert_eq!(count_chars("Good morning, senpai!"), 17);
        assert_eq!(count_chars("…　……"), 0);
    }

    #[test]
    fn skips_repeats_and_long_copies() {
        assert_eq!(new_chars("「おはよう」", ""), 4);
        assert_eq!(new_chars("「おはよう」\r\n", "「おはよう」"), 0);
        assert_eq!(new_chars("   ", ""), 0);
        assert_eq!(new_chars(&"あ".repeat(MAX_LINE_CHARS + 1), ""), 0);
        assert_eq!(
            new_chars(&"あ".repeat(MAX_LINE_CHARS), ""),
            MAX_LINE_CHARS as i64
        );
    }
}
