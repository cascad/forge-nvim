// spec: IDE-BOOT-40. Transport stays in PS/Bash, SDK settings stay in shared Lua.
use crate::{invalid, runtime, sdks, Options, Plan, Result};
use std::fs::{self, OpenOptions};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

fn unique(options: &Options, suffix: &str) -> Result<PathBuf> {
    fs::create_dir_all(&options.log_dir)?;
    Ok(options.log_dir.join(format!(
        "preflight-{}-{}.{suffix}",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(invalid)?
            .as_nanos(),
        std::process::id()
    )))
}

// Files avoid unbounded pipe buffers; callers read only a bounded diagnostic tail.
pub(crate) fn capture(command: Command, options: &Options, timeout: Duration) -> Result<String> {
    capture_output(command, options, timeout, None)
}

pub(crate) fn capture_complete(
    command: Command,
    options: &Options,
    timeout: Duration,
    limit: u64,
) -> Result<String> {
    capture_output(command, options, timeout, Some(limit))
}

fn capture_output(
    mut command: Command,
    options: &Options,
    timeout: Duration,
    limit: Option<u64>,
) -> Result<String> {
    let log = unique(options, "log")?;
    let file = OpenOptions::new().create_new(true).write(true).open(&log)?;
    let errors = log.with_extension("stderr.log");
    let error_file = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&errors)?;
    command
        .stdin(Stdio::null())
        .stdout(Stdio::from(file))
        .stderr(Stdio::from(error_file));
    let mut child = command
        .spawn()
        .map_err(|e| invalid(format!("Core preflight: {e}; log: {}", log.display())))?;
    let start = Instant::now();
    let status = loop {
        if let Some(status) = child.try_wait()? {
            break status;
        }
        if start.elapsed() >= timeout {
            let _ = child.kill();
            let _ = child.wait();
            return Err(invalid(format!(
                "Core preflight timeout; log: {}",
                log.display()
            )));
        }
        std::thread::sleep(Duration::from_millis(25));
    };
    let mut bytes = vec![];
    let output = fs::File::open(&log)?;
    if limit.is_some_and(|size| {
        output
            .metadata()
            .is_ok_and(|metadata| metadata.len() > size)
    }) {
        return Err(invalid(format!(
            "Preflight output exceeds bound; log: {}",
            log.display()
        )));
    }
    output
        .take(limit.unwrap_or(16384))
        .read_to_end(&mut bytes)?;
    let text = String::from_utf8_lossy(&bytes).into_owned();
    if !status.success() {
        let mut stderr = vec![];
        fs::File::open(&errors)?
            .take(16384)
            .read_to_end(&mut stderr)?;
        return Err(invalid(format!(
            "Core preflight failed ({status}): {text}{}\nlog: {}",
            String::from_utf8_lossy(&stderr),
            log.display()
        )));
    }
    Ok(text)
}

pub(crate) fn prepare(options: &Options, plan: &Plan) -> Result<PathBuf> {
    eprintln!("Core · получение и проверка перед проверкой SDK");
    let mut core = plan.clone();
    core.components = vec!["core".into()];
    let delivery = runtime::selected(options, &core)?;
    let plan_path = if let Some(rows) = delivery {
        let path = unique(options, "runtime.tsv")?;
        OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&path)?
            .write_all(rows.as_bytes())?;
        Some(path)
    } else {
        None
    };
    let mut command = if cfg!(windows) {
        let mut c = Command::new(&options.powershell);
        c.args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"])
            .arg(options.source.join("scripts/install-private.ps1"))
            .arg("-Source")
            .arg(&options.source)
            .arg("-InstallPath")
            .arg(&plan.install_dir)
            .arg("-PrepareOnly");
        if let Some(path) = &plan_path {
            c.arg("-RuntimePlanPath").arg(path);
        }
        for (flag, value) in [
            ("-RuntimePath", &options.runtime),
            ("-RuntimeArchiveUrl", &options.runtime_url),
            ("-RuntimeSHA256", &options.runtime_sha),
        ] {
            if !value.is_empty() {
                c.arg(flag).arg(value);
            }
        }
        c
    } else {
        let mut c = Command::new("/bin/bash");
        c.arg(options.source.join("scripts/install-private.sh"))
            .arg(&options.source)
            .arg(&plan.install_dir)
            .args([
                &options.runtime,
                &options.runtime_url,
                &options.runtime_sha,
                "",
            ])
            .arg(
                plan_path
                    .as_ref()
                    .map(|p| p.as_os_str())
                    .unwrap_or_default(),
            )
            .arg("prepare");
        // Only bootstrap utilities; these directories never reach language SDK probes.
        let mut bins =
            std::env::split_paths(&sdks::effective_path(&plan.sdk_paths)?).collect::<Vec<_>>();
        bins.extend([PathBuf::from("/usr/bin"), PathBuf::from("/bin")]);
        c.env("PATH", std::env::join_paths(bins).map_err(invalid)?);
        c
    };
    command.env_remove("FRIDE_INSTALL_UI");
    let output = capture(command, options, Duration::from_secs(600))?;
    let path = PathBuf::from(output.trim().trim_start_matches('\u{feff}'));
    if !path.is_absolute() || !path.is_dir() {
        return Err(invalid(format!("Invalid prepared Core path: {output}")));
    }
    Ok(path)
}

pub(crate) fn snapshot(options: &Options, plan: &Plan) -> Result<sdks::Snapshot> {
    snapshot_for(options, plan, &plan.native_sdks)
}

pub(crate) fn snapshot_for(
    options: &Options,
    plan: &Plan,
    ids: &[String],
) -> Result<sdks::Snapshot> {
    if ids.is_empty() && options.installed_kit.is_none() {
        return Ok(sdks::Snapshot::default());
    }
    let runtime = options
        .prepared_core
        .as_ref()
        .ok_or_else(|| invalid("Core must be prepared before SDK inspection"))?;
    let request = unique(options, "request.json")?;
    let output = unique(options, "settings.json")?;
    OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&request)?
        .write_all(serde_json::to_string(ids)?.as_bytes())?;
    let mut command = Command::new(runtime.join(if cfg!(windows) {
        "bin/nvim.exe"
    } else {
        "bin/nvim"
    }));
    command
        .args(["--headless", "-u", "NONE", "-i", "NONE", "-l"])
        .arg(options.source.join("scripts/sdk-preflight.lua"))
        .arg(&options.source)
        .arg(runtime)
        .arg(&request)
        .arg(&output)
        .env("NVIM_APPNAME", "fride")
        .env("NVIM_LOG_FILE", unique(options, "nvim.log")?)
        .env("PATH", sdks::effective_path(&plan.sdk_paths)?);
    if options.installed_kit.is_some() {
        command.arg(&options.source).arg("project");
    }
    for key in [
        "VIM",
        "VIMRUNTIME",
        "VIMINIT",
        "EXINIT",
        "LUA_INIT",
        "LUA_PATH",
        "LUA_CPATH",
        "FRIDE_SDK_BASE",
        "FRIDE_SDK_PROJECT",
    ] {
        command.env_remove(key);
    }
    capture(command, options, Duration::from_secs(30))?;
    let file = fs::File::open(&output)?;
    if file.metadata()?.len() > 262144 {
        return Err(invalid("SDK settings snapshot exceeds 256KiB"));
    }
    let mut snapshot: sdks::Snapshot = serde_json::from_reader(file).map_err(invalid)?;
    if snapshot.schema != 1 {
        return Err(invalid("Unsupported SDK settings snapshot"));
    }
    let target = PathBuf::from(&plan.install_dir);
    let target = if target.is_absolute() {
        target
    } else {
        std::env::current_dir()?.join(target)
    };
    let target = fs::canonicalize(&target).unwrap_or(target);
    for (id, selected) in &snapshot.selections {
        if selected.tools.values().any(|p| {
            fs::canonicalize(p)
                .unwrap_or_else(|_| p.clone())
                .starts_with(&target)
        }) {
            snapshot.errors.insert(
                id.clone(),
                format!(
                    "SDK [{}]: SDK должен находиться вне заменяемого комплекта IDE",
                    selected.source
                ),
            );
        }
    }
    Ok(snapshot)
}

pub(crate) fn default_powershell() -> String {
    std::env::var_os("SystemRoot")
        .map(|p| {
            Path::new(&p)
                .join("System32/WindowsPowerShell/v1.0/powershell.exe")
                .to_string_lossy()
                .into_owned()
        })
        .unwrap_or_else(|| "powershell.exe".into())
}
