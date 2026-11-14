// spec: IDE-BOOT-14. Native catalog selection; transport remains in PS/Bash.
use crate::{invalid, Options, Plan, Result};
use std::collections::HashMap;

pub(crate) fn platform() -> String {
    let os = match std::env::consts::OS {
        "windows" => "windows",
        "macos" => "macos",
        _ => "linux",
    };
    let arch = match std::env::consts::ARCH {
        "x86_64" => "x64",
        "aarch64" => "arm64",
        other => other,
    };
    format!("{os}-{arch}")
}

pub(crate) fn selected(options: &Options, plan: &Plan) -> Result<Option<String>> {
    if !options.runtime.is_empty() || !options.runtime_url.is_empty() {
        return Ok(None);
    }
    let file = options.source.join("scripts/runtime/artifacts.tsv");
    let text = std::fs::read_to_string(&file).map_err(|_| {
        invalid(format!(
            "Private SDK catalog unavailable: {}",
            file.display()
        ))
    })?;
    let native = platform();
    let mut entries = HashMap::new();
    for line in text
        .lines()
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
    {
        let row: Vec<_> = line.split('\t').collect();
        if row.len() != 4
            || row
                .iter()
                .any(|field| field.is_empty() || field.chars().any(char::is_control))
            || !row[1].bytes().all(|b| b.is_ascii_lowercase() || b == b'-')
            || !(row[2].starts_with("https://") || row[2].starts_with("http://"))
            || row[3].len() != 64
            || !row[3]
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(invalid("Invalid private SDK catalog row"));
        }
        if entries.insert((row[0], row[1]), line).is_some() {
            return Err(invalid("Duplicate private SDK catalog entry"));
        }
    }
    let mut rows = Vec::new();
    let mut missing = Vec::new();
    for component in &plan.components {
        match entries.get(&(native.as_str(), component.as_str())) {
            Some(row) => rows.push(*row),
            None => missing.push(component.as_str()),
        }
    }
    if !missing.is_empty() {
        return Err(invalid(format!("Private SDK artifacts not published for {native}: {}. System packages were not changed.",missing.join(", "))));
    }
    if plan.components.first().map(String::as_str) != Some("core") {
        return Err(invalid("Core must be the first runtime component"));
    }
    Ok(Some(rows.join("\n") + "\n"))
}
