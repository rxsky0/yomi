//! Exports your reading history as CSV (for spreadsheets) or JSON (for scripts).
//! Unlike the backup (`backup.rs`), this never includes settings or your VNDB token.

use std::collections::BTreeMap;

use serde::Serialize;
use serde_json::Value;

use crate::config::{Config, Entry};

#[derive(Debug, Clone, Serialize)]
pub struct Row {
    pub key: String,
    pub title: String,
    pub vndb_id: String,
    pub status: String,
    pub playtime_seconds: i64,
    pub sessions: i64,
    pub chars_read: i64,
    pub first_read: String,
    pub last_played: String,
    pub finished: String,
    pub daily_seconds: BTreeMap<String, i64>,
    pub daily_chars: BTreeMap<String, i64>,
    pub notes: Vec<Note>,
}

#[derive(Debug, Clone, Serialize)]
pub struct Note {
    pub date: String,
    pub text: String,
}

fn text(entry: &Entry, field: &str) -> String {
    entry
        .get(field)
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

fn num(entry: &Entry, field: &str) -> i64 {
    entry.get(field).and_then(Value::as_i64).unwrap_or(0)
}

fn counter(entry: &Entry, field: &str) -> BTreeMap<String, i64> {
    entry
        .get(field)
        .and_then(Value::as_object)
        .into_iter()
        .flatten()
        .filter_map(|(day, value)| value.as_i64().filter(|v| *v > 0).map(|v| (day.clone(), v)))
        .collect()
}

/// A Unix timestamp as a local `YYYY-MM-DD HH:MM`, or "" when unset.
fn local_time(timestamp: i64) -> String {
    use chrono::TimeZone;
    if timestamp <= 0 {
        return String::new();
    }
    chrono::Local
        .timestamp_opt(timestamp, 0)
        .single()
        .map(|t| t.format("%Y-%m-%d %H:%M").to_string())
        .unwrap_or_default()
}

pub fn row(key: &str, entry: &Entry) -> Row {
    let daily_seconds = counter(entry, "daily");
    let vndb_id = [text(entry, "vndb_id"), text(entry, "matched_vndb_id")]
        .into_iter()
        .find(|id| !id.is_empty())
        .unwrap_or_default();
    let notes = entry
        .get("notes")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .map(|note| Note {
            date: local_time(note.get("at").and_then(Value::as_i64).unwrap_or(0)),
            text: note
                .get("text")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string(),
        })
        .collect();
    let finished = if text(entry, "status") == "finished" {
        local_time(num(entry, "finished_at"))
    } else {
        String::new()
    };

    Row {
        key: key.to_string(),
        title: crate::screenshots::display_name(key, entry),
        vndb_id,
        status: text(entry, "status"),
        playtime_seconds: num(entry, "playtime_seconds"),
        sessions: num(entry, "sessions"),
        chars_read: num(entry, "chars_read"),
        first_read: daily_seconds.keys().next().cloned().unwrap_or_default(),
        last_played: local_time(num(entry, "last_played")),
        finished,
        daily_chars: counter(entry, "chars_daily"),
        daily_seconds,
        notes,
    }
}

pub fn rows(cfg: &Config) -> Vec<Row> {
    let mut rows: Vec<Row> = crate::commands::library::visible_games(cfg)
        .iter()
        .map(|(key, entry)| row(key, entry))
        .collect();
    rows.sort_by(|a, b| b.playtime_seconds.cmp(&a.playtime_seconds));
    rows
}

pub fn json(rows: &[Row]) -> Result<String, String> {
    serde_json::to_string_pretty(&serde_json::json!({
        "exported_by": concat!("Yomi ", env!("CARGO_PKG_VERSION")),
        "exported_at": local_time(crate::config::now()),
        "visual_novels": rows,
    }))
    .map_err(|e| e.to_string())
}

fn csv_field(value: &str) -> String {
    // Leading =, +, - or @ would be read as a formula by spreadsheet apps.
    let safe = if value.starts_with(['=', '+', '-', '@']) {
        format!("'{value}")
    } else {
        value.to_string()
    };
    if safe.contains([',', '"', '\n', '\r']) {
        format!("\"{}\"", safe.replace('"', "\"\""))
    } else {
        safe
    }
}

fn csv(header: &[&str], lines: impl Iterator<Item = Vec<String>>) -> String {
    // The BOM makes Excel read Japanese and other non-ASCII titles correctly.
    let mut out = String::from("\u{feff}");
    out.push_str(&header.join(","));
    out.push_str("\r\n");
    for line in lines {
        let fields: Vec<String> = line.iter().map(|f| csv_field(f)).collect();
        out.push_str(&fields.join(","));
        out.push_str("\r\n");
    }
    out
}

fn hours(seconds: i64) -> String {
    format!("{:.2}", seconds as f64 / 3600.0)
}

/// One line per VN.
pub fn library_csv(rows: &[Row]) -> String {
    csv(
        &[
            "title",
            "status",
            "hours_read",
            "sessions",
            "chars_read",
            "first_read",
            "last_played",
            "finished",
            "vndb_id",
            "notes",
        ],
        rows.iter().map(|r| {
            vec![
                r.title.clone(),
                r.status.clone(),
                hours(r.playtime_seconds),
                r.sessions.to_string(),
                r.chars_read.to_string(),
                r.first_read.clone(),
                r.last_played.clone(),
                r.finished.clone(),
                r.vndb_id.clone(),
                r.notes.len().to_string(),
            ]
        }),
    )
}

/// One line per VN per day read, oldest first: handy for pivot tables and charts.
pub fn daily_csv(rows: &[Row]) -> String {
    let mut lines: Vec<Vec<String>> = Vec::new();
    for r in rows {
        let mut days: Vec<&String> = r.daily_seconds.keys().chain(r.daily_chars.keys()).collect();
        days.sort();
        days.dedup();
        for day in days {
            let seconds = r.daily_seconds.get(day).copied().unwrap_or(0);
            lines.push(vec![
                day.clone(),
                r.title.clone(),
                (seconds / 60).to_string(),
                r.daily_chars.get(day).copied().unwrap_or(0).to_string(),
            ]);
        }
    }
    lines.sort_by(|a, b| a[0].cmp(&b[0]).then_with(|| a[1].cmp(&b[1])));
    csv(
        &["date", "title", "minutes_read", "chars_read"],
        lines.into_iter(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn sample() -> Row {
        let entry = json!({
            "title": "Sakura, \"Spring\"",
            "status": "finished",
            "playtime_seconds": 5400,
            "sessions": 3,
            "chars_read": 1200,
            "daily": { "2026-10-02": 1800, "2026-10-01": 3600 },
            "chars_daily": { "2026-10-02": 1200 },
            "notes": [{ "at": 0, "text": "=great" }],
            "vndb_id": "v1",
        });
        row("sakura.exe", entry.as_object().unwrap())
    }

    #[test]
    fn library_csv_escapes_and_converts() {
        let csv = library_csv(&[sample()]);
        let lines: Vec<&str> = csv.trim_start_matches('\u{feff}').lines().collect();
        assert_eq!(lines[0], "title,status,hours_read,sessions,chars_read,first_read,last_played,finished,vndb_id,notes");
        assert_eq!(
            lines[1],
            "\"Sakura, \"\"Spring\"\"\",finished,1.50,3,1200,2026-10-01,,,v1,1"
        );
    }

    #[test]
    fn daily_csv_has_one_line_per_day() {
        let csv = daily_csv(&[sample()]);
        let lines: Vec<&str> = csv.trim_start_matches('\u{feff}').lines().collect();
        assert_eq!(lines.len(), 3);
        assert!(lines[1].starts_with("2026-10-01,"));
        assert!(lines[1].ends_with(",60,0"));
        assert!(lines[2].ends_with(",30,1200"));
    }

    #[test]
    fn formulas_are_neutralised() {
        assert_eq!(csv_field("=SUM(A1)"), "'=SUM(A1)");
        assert_eq!(csv_field("-5"), "'-5");
        assert_eq!(csv_field("plain"), "plain");
    }

    #[test]
    fn json_keeps_notes() {
        let out = json(&[sample()]).unwrap();
        assert!(out.contains("\"=great\""));
        assert!(out.contains("\"visual_novels\""));
    }
}
