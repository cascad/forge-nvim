// spec: IDE-BOOT-18. Native SDK discovery, never provisioning.
use crate::{invalid, Result};
use serde::Serialize;
use std::fs::{self, OpenOptions};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

pub(crate) fn is_sdk_part(id: &str) -> bool {
    matches!(id, "node-runtime" | "go-runtime")
}

pub(crate) fn required(components: &[String]) -> Vec<String> {
    [
        ("go", &["go", "sql", "go-runtime"][..]),
        ("rust", &["rust"][..]),
        ("python", &["python"][..]),
        ("node", &["node", "python", "bash", "node-runtime"][..]),
    ]
    .into_iter()
    .filter(|(_, features)| components.iter().any(|id| features.contains(&id.as_str())))
    .map(|(id, _)| id.to_owned())
    .collect()
}

#[derive(Serialize)]
pub(crate) struct Tool {
    command: String,
    path: Option<PathBuf>,
    status: String,
    version: Option<String>,
    detail: Option<String>,
    log: Option<PathBuf>,
}

#[derive(Serialize)]
pub(crate) struct Sdk {
    id: String,
    pub status: String,
    tools: Vec<Tool>,
}

#[derive(Serialize)]
pub(crate) struct Report {
    schema: u8,
    pub sdks: Vec<Sdk>,
}

impl Report {
    pub fn ready(&self) -> bool {
        self.sdks.iter().all(|sdk| sdk.status == "ready")
    }
    pub fn summary(&self) -> String {
        self.sdks
            .iter()
            .map(|sdk| {
                let details = sdk
                    .tools
                    .iter()
                    .map(|tool| {
                        format!(
                            "{}: {}{}{}",
                            tool.command,
                            tool.path
                                .as_ref()
                                .map(|p| p.display().to_string())
                                .unwrap_or_else(|| "не найден в PATH".into()),
                            tool.version
                                .as_ref()
                                .map(|v| format!(" · {v}"))
                                .unwrap_or_default(),
                            tool.detail
                                .as_ref()
                                .map(|v| format!(" · {v}"))
                                .unwrap_or_default()
                        )
                    })
                    .collect::<Vec<_>>()
                    .join("; ");
                format!("{} · {} · {details}", sdk.id, sdk.status)
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

fn find(name: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    for directory in std::env::split_paths(&path) {
        let extensions = if cfg!(windows) {
            if name == "npm" {
                vec![".cmd", ".exe"]
            } else {
                vec![".exe"]
            }
        } else {
            vec![""]
        };
        for extension in extensions {
            let candidate = directory.join(format!("{name}{extension}"));
            if !candidate.is_file() {
                continue;
            }
            // Store execution aliases can open an installer instead of Python.
            if cfg!(windows)
                && candidate
                    .to_string_lossy()
                    .replace('\\', "/")
                    .to_ascii_lowercase()
                    .contains("/microsoft/windowsapps/")
            {
                continue;
            }
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                if fs::metadata(&candidate).ok()?.permissions().mode() & 0o111 == 0 {
                    continue;
                }
            }
            // Keep the selected path: resolving a venv Python symlink loses the venv.
            return Some(if candidate.is_absolute() {
                candidate
            } else {
                std::env::current_dir().ok()?.join(candidate)
            });
        }
    }
    None
}

fn probe(name: &str, directory: &Path, stamp: u128) -> Result<Tool> {
    let mut tool = Tool {
        command: name.into(),
        path: find(name),
        status: "missing".into(),
        version: None,
        detail: None,
        log: None,
    };
    let Some(path) = &tool.path else {
        return Ok(tool);
    };
    if name == "npm" {
        // npm.cmd is a native entrypoint, not a Win32 executable. Do not use a shell.
        tool.status = "ready".into();
        return Ok(tool);
    }
    fs::create_dir_all(directory)?;
    let log_path = directory.join(format!("sdk-{stamp}-{}-{name}.log", std::process::id()));
    let log = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&log_path)?;
    let mut command = Command::new(path);
    if name == "py" {
        command.arg("-3");
    }
    command
        .arg(if name == "go" { "version" } else { "--version" })
        .env("GOTOOLCHAIN", "local")
        .env("RUSTUP_AUTO_INSTALL", "0")
        .current_dir(std::env::temp_dir())
        .stdin(Stdio::null())
        .stdout(Stdio::from(log.try_clone()?))
        .stderr(Stdio::from(log));
    tool.status = "unavailable".into();
    tool.log = Some(log_path.clone());
    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(error) => {
            tool.detail = Some(error.to_string());
            return Ok(tool);
        }
    };
    let start = Instant::now();
    let code = loop {
        if let Some(status) = child.try_wait()? {
            break Some(status);
        }
        if start.elapsed() >= Duration::from_secs(2) {
            let _ = child.kill();
            let _ = child.wait();
            break None;
        }
        std::thread::sleep(Duration::from_millis(20));
    };
    let mut bytes = vec![];
    fs::File::open(log_path)?
        .take(8192)
        .read_to_end(&mut bytes)?;
    let output = String::from_utf8_lossy(&bytes);
    let line = output.lines().next().unwrap_or("").trim();
    let expected = match name {
        "go" => line.starts_with("go version go"),
        "rustc" => line.starts_with("rustc "),
        "cargo" => line.starts_with("cargo "),
        "python" | "python3" | "py" => line.starts_with("Python 3."),
        "node" => line.starts_with('v') && line.chars().nth(1).is_some_and(|c| c.is_ascii_digit()),
        _ => false,
    };
    match code {
        Some(status) if status.success() && expected => {
            tool.status = "ready".into();
            tool.version = Some(line.chars().take(240).collect());
        }
        Some(status) => {
            tool.detail = Some(format!(
                "exit {status}; {}",
                line.chars()
                    .filter(|c| !c.is_control())
                    .take(240)
                    .collect::<String>()
            ));
        }
        None => {
            tool.detail = Some("timeout 2s".into());
        }
    }
    Ok(tool)
}

pub(crate) fn inspect(ids: &[String], directory: &Path) -> Result<Report> {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(invalid)?
        .as_nanos();
    let mut report = Report {
        schema: 1,
        sdks: vec![],
    };
    for id in ids {
        let groups: Vec<Vec<&str>> = match id.as_str() {
            "go" => vec![vec!["go"]],
            "rust" => vec![vec!["rustc"], vec!["cargo"]],
            "python" => vec![if cfg!(windows) {
                vec!["python", "python3", "py"]
            } else {
                vec!["python", "python3"]
            }],
            "node" => vec![vec!["node"], vec!["npm"]],
            _ => return Err(invalid(format!("Unknown native SDK: {id}"))),
        };
        let mut tools = vec![];
        for alternatives in groups {
            let mut chosen = None;
            for name in alternatives {
                let candidate = probe(name, directory, stamp)?;
                let ready = candidate.status == "ready";
                if chosen
                    .as_ref()
                    .is_none_or(|tool: &Tool| tool.status == "missing")
                    || ready
                {
                    chosen = Some(candidate);
                }
                if ready {
                    break;
                }
            }
            tools.push(chosen.expect("Nonempty SDK command list"));
        }
        let status = if tools.iter().all(|tool| tool.status == "ready") {
            "ready"
        } else if tools.iter().any(|tool| tool.status == "missing") {
            "missing"
        } else {
            "unavailable"
        };
        report.sdks.push(Sdk {
            id: id.clone(),
            status: status.into(),
            tools,
        });
    }
    Ok(report)
}
