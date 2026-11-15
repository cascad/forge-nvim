// Native package managers only, called after SDK-specific confirmation.
use crate::{invalid, sdks, Options, Result};
use std::ffi::OsString;
use std::fs::{self, OpenOptions};
use std::io::{Read, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};
pub(crate) struct Recipe {
    pub program: PathBuf,
    pub args: Vec<OsString>,
    pub source: String,
}
impl Recipe {
    pub fn display(&self) -> String {
        std::iter::once(self.program.to_string_lossy().to_string())
            .chain(self.args.iter().map(|a| format!("{:?}", a)))
            .collect::<Vec<_>>()
            .join(" ")
    }
}
pub(crate) fn recipe(id: &str, paths: &[PathBuf]) -> Result<Recipe> {
    let path = sdks::effective_path(paths)?;
    let (manager, items, source) = if cfg!(windows) {
        let package = match id {
            "go" => "GoLang.Go",
            "rust" => "Rustlang.Rustup",
            "node" => "OpenJS.NodeJS.LTS",
            "python" => "Python.Python.3.14",
            _ => return Err(invalid("Unknown SDK")),
        };
        ("winget",vec!["install","--exact","--id",package,"--source","winget","--no-upgrade","--accept-source-agreements","--accept-package-agreements","--disable-interactivity"],"WinGet: версия пакета из репозитория winget; штатные каталоги приложения, возможен UAC")
    } else if cfg!(target_os = "macos") {
        let package = match id {
            "go" => "go",
            "rust" => "rust",
            "node" => "node",
            "python" => "python",
            _ => return Err(invalid("Unknown SDK")),
        };
        (
            "brew",
            vec!["install", package],
            "Homebrew: версия formula из настроенного репозитория; штатный prefix Homebrew",
        )
    } else {
        let packages = match id {
            "go" => vec!["golang-go"],
            "rust" => vec!["rustc", "cargo"],
            "node" => vec!["nodejs", "npm"],
            "python" => vec!["python3", "python3-venv"],
            _ => return Err(invalid("Unknown SDK")),
        };
        let mut args = vec!["install", "--yes", "--no-upgrade"];
        args.extend(packages);
        ("apt-get",args,"APT: версии из настроенных репозиториев; системные каталоги /usr и cache APT, возможен sudo")
    };
    let program=sdks::find(manager,&path).ok_or_else(||invalid(format!("{manager} не найден. Выберите существующий SDK или установите штатный менеджер отдельно.")))?;
    let mut recipe = Recipe {
        program,
        args: items.into_iter().map(OsString::from).collect(),
        source: source.into(),
    };
    if manager == "apt-get" {
        if let Some(sudo) = sdks::find("sudo", &path) {
            recipe.args.insert(0, recipe.program.into_os_string());
            recipe.program = sudo;
        }
    }
    Ok(recipe)
}
pub(crate) fn run(options: &Options, paths: &[PathBuf], recipe: &Recipe) -> Result<bool> {
    fs::create_dir_all(&options.log_dir)?;
    let log = options.log_dir.join(format!(
        "sdk-install-{}.log",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(invalid)?
            .as_nanos()
    ));
    let mut file = OpenOptions::new().create_new(true).write(true).open(&log)?;
    writeln!(file, "{}\n{}", recipe.source, recipe.display())?;
    cliclack::log::info(format!("SDK installation · лог: {}", log.display()))?;
    let mut child = Command::new(&recipe.program)
        .args(&recipe.args)
        .env("PATH", sdks::effective_path(paths)?)
        .env("HOMEBREW_NO_AUTO_UPDATE", "1")
        .env("HOMEBREW_NO_INSTALL_UPGRADE", "1")
        .stdin(Stdio::inherit())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    let (tx, rx) = std::sync::mpsc::channel();
    let reader = |mut input: Box<dyn Read + Send>, tx: std::sync::mpsc::Sender<Vec<u8>>| {
        std::thread::spawn(move || {
            let mut bytes = [0u8; 4096];
            loop {
                match input.read(&mut bytes) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        if tx.send(bytes[..n].to_vec()).is_err() {
                            break;
                        }
                    }
                }
            }
        })
    };
    let out = reader(Box::new(child.stdout.take().unwrap()), tx.clone());
    let err = reader(Box::new(child.stderr.take().unwrap()), tx.clone());
    drop(tx);
    for bytes in rx {
        file.write_all(&bytes)?;
        std::io::stderr().write_all(&bytes)?;
        std::io::stderr().flush()?;
    }
    out.join()
        .map_err(|_| invalid("SDK output reader failed"))?;
    err.join()
        .map_err(|_| invalid("SDK output reader failed"))?;
    let status = child.wait()?;
    writeln!(file, "\nExit: {status}")?;
    if !status.success() {
        cliclack::log::warning(format!(
            "SDK installation завершилась с {status}; лог: {}",
            log.display()
        ))?;
    }
    Ok(status.success())
}

// Read-only: native installers can register paths without changing this process.
pub(crate) fn registered_paths() -> Result<Vec<PathBuf>> {
    if !cfg!(windows) {
        return Ok(vec![]);
    }
    let Some(shell) = sdks::find("powershell", &std::env::var_os("PATH").unwrap_or_default())
    else {
        return Ok(vec![]);
    };
    let script = r#"[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false);$ErrorActionPreference='SilentlyContinue';foreach($scope in @('User','Machine')){[Environment]::GetEnvironmentVariable('Path',$scope).Split(';')|ForEach-Object{[Environment]::ExpandEnvironmentVariables($_)}};foreach($root in @('HKCU:\Software\Python\PythonCore','HKLM:\Software\Python\PythonCore','HKLM:\Software\WOW6432Node\Python\PythonCore')){Get-ChildItem -LiteralPath $root|ForEach-Object{(Get-Item -LiteralPath ($_.PSPath+'\InstallPath')).GetValue('')}}"#;
    let output = Command::new(shell)
        .args(["-NoProfile", "-Command", script])
        .stdin(Stdio::null())
        .output()?;
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(PathBuf::from)
        .filter(|p| p.is_dir())
        .collect())
}
