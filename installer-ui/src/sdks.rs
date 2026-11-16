// spec: IDE-BOOT-18. Native SDK discovery, never provisioning.
use crate::{invalid, Result};
use serde::Serialize;
use std::ffi::{OsStr, OsString};
use std::fs::{self, OpenOptions};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitStatus, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

pub(crate) fn is_sdk_part(id: &str) -> bool {
    matches!(id, "node-runtime" | "go-runtime")
}

pub(crate) fn required(components: &[String]) -> Vec<String> {
    [
        ("go", &["go", "go-runtime"][..]),
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
    pub path: Option<PathBuf>,
    status: String,
    version: Option<String>,
    detail: Option<String>,
    log: Option<PathBuf>,
}

#[derive(Serialize)]
pub(crate) struct Sdk {
    pub id: String,
    pub status: String,
    pub tools: Vec<Tool>,
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

pub(crate) fn find(name: &str, path: &OsStr) -> Option<PathBuf> {
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
                && matches!(name, "python" | "python3" | "py")
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

// Shared bounded runner: no shell, no interactive installer, finite output read.
fn version_output(mut command: Command, log_path: &Path) -> Result<(Option<ExitStatus>, String)> {
    let log = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(log_path)?;
    command
        .current_dir(std::env::temp_dir())
        .stdin(Stdio::null())
        .stdout(Stdio::from(log.try_clone()?))
        .stderr(Stdio::from(log));
    let mut child = command.spawn()?;
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
    Ok((code, String::from_utf8_lossy(&bytes).into_owned()))
}

fn probe(name: &str, directory: &Path, stamp: u128, search_path: &OsStr) -> Result<Tool> {
    let mut tool = Tool {
        command: name.into(),
        path: find(name, search_path),
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
    #[cfg(target_os = "macos")]
    if name == "git" && fs::canonicalize(path).is_ok_and(|p| p == Path::new("/usr/bin/git")) {
        // Apple shim may prompt to install CLT. xcode-select -p is read-only.
        let select_log = log_path.with_extension("select.log");
        let mut selector = Command::new("/usr/bin/xcode-select");
        selector.arg("--print-path");
        let ready = version_output(selector, &select_log).is_ok_and(|(status, output)| {
            status.is_some_and(|s| s.success())
                && Path::new(output.trim()).is_absolute()
                && Path::new(output.trim()).join("usr/bin/git").is_file()
        });
        if !ready {
            tool.status = "unavailable".into();
            tool.detail = Some(
                "Apple Git: Developer Tools не выбраны; выберите Git или установите его явно"
                    .into(),
            );
            tool.log = Some(select_log);
            return Ok(tool);
        }
    }
    let mut command = Command::new(path);
    if name == "py" {
        command.arg("-3");
    }
    command
        .env("PATH", search_path)
        .arg(if name == "go" { "version" } else { "--version" })
        .env("GOTOOLCHAIN", "local")
        .env("RUSTUP_AUTO_INSTALL", "0");
    tool.status = "unavailable".into();
    tool.log = Some(log_path.clone());
    let (code, output) = match version_output(command, &log_path) {
        Ok(output) => output,
        Err(error) => {
            tool.detail = Some(error.to_string());
            return Ok(tool);
        }
    };
    let line = output.lines().next().unwrap_or("").trim();
    let expected = match name {
        "go" => line.starts_with("go version go"),
        "rustc" => line.starts_with("rustc "),
        "cargo" => line.starts_with("cargo "),
        "python" | "python3" | "py" => line.starts_with("Python 3."),
        "node" => line.starts_with('v') && line.chars().nth(1).is_some_and(|c| c.is_ascii_digit()),
        "git" => line
            .strip_prefix("git version ")
            .and_then(|v| v.split('.').next())
            .and_then(|v| v.parse::<u32>().ok())
            .is_some_and(|v| v >= 2),
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

pub(crate) fn inspect(ids: &[String], directory: &Path, paths: &[PathBuf]) -> Result<Report> {
    let path = effective_path(paths)?;
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
            "git" => vec![vec!["git"]],
            _ => return Err(invalid(format!("Unknown native SDK: {id}"))),
        };
        let mut tools = vec![];
        for alternatives in groups {
            let mut chosen = None;
            for name in alternatives {
                let candidate = probe(name, directory, stamp, &path)?;
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

pub(crate) fn effective_path(paths: &[PathBuf]) -> Result<OsString> {
    let mut entries =
        std::env::split_paths(&std::env::var_os("PATH").unwrap_or_default()).collect::<Vec<_>>();
    entries.extend(paths.iter().cloned());
    std::env::join_paths(entries).map_err(invalid)
}

pub(crate) fn directory(path: &Path) -> Result<PathBuf> {
    if path.as_os_str().is_empty() || path.to_string_lossy().chars().any(|c| c.is_control()) {
        return Err(invalid("Введите каталог SDK без управляющих символов"));
    }
    let path = if path.is_absolute() {
        path.to_owned()
    } else {
        std::env::current_dir()?.join(path)
    };
    if !path.is_dir() {
        return Err(invalid("Каталог SDK не найден"));
    }
    std::env::join_paths([&path]).map_err(invalid)?;
    Ok(path)
}

pub(crate) fn add_path(plan: &mut crate::Plan, path: PathBuf) -> Result<()> {
    let path = directory(&path)?;
    let target = PathBuf::from(&plan.install_dir);
    let target = if target.is_absolute() {
        target
    } else {
        std::env::current_dir()?.join(target)
    };
    let real = fs::canonicalize(&path)?;
    if path.starts_with(&target) || real.starts_with(fs::canonicalize(&target).unwrap_or(target)) {
        return Err(invalid(
            "SDK должен находиться вне заменяемого комплекта IDE",
        ));
    }
    if !plan.sdk_paths.contains(&path) {
        plan.sdk_paths.push(path);
    }
    Ok(())
}
