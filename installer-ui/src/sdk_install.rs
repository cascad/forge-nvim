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
    pub preserve_nextest: Option<PathBuf>,
    pub sdk_result: Option<PathBuf>,
}
impl Recipe {
    pub fn display(&self) -> String {
        std::iter::once(self.program.to_string_lossy().to_string())
            .chain(self.args.iter().map(|a| format!("{:?}", a)))
            .collect::<Vec<_>>()
            .join(" ")
    }
}
fn manager(name: &str, path: &std::ffi::OsStr) -> Option<PathBuf> {
    sdks::find(name, path).or_else(|| {
        let directories = if cfg!(windows) && name == "winget" {
            std::env::var_os("LOCALAPPDATA")
                .map(|p| vec![PathBuf::from(p).join("Microsoft/WindowsApps")])
                .unwrap_or_default()
        } else if cfg!(target_os = "macos") && name == "brew" {
            vec![
                PathBuf::from("/opt/homebrew/bin"),
                PathBuf::from("/usr/local/bin"),
            ]
        } else {
            vec![]
        };
        directories
            .into_iter()
            .find_map(|directory| sdks::find(name, directory.as_os_str()))
    })
}
pub(crate) fn recipe(options: &Options, id: &str, paths: &[PathBuf]) -> Result<Recipe> {
    let path = sdks::effective_path(paths)?;
    let rustup_home = std::env::var_os("CARGO_HOME")
        .map(PathBuf::from)
        .or_else(|| {
            std::env::var_os(if cfg!(windows) { "USERPROFILE" } else { "HOME" })
                .map(|home| PathBuf::from(home).join(".cargo"))
        });
    let has_rustup = rustup_home.is_some_and(|home| {
        home.join(if cfg!(windows) {
            "bin/rustup.exe"
        } else {
            "bin/rustup"
        })
        .is_file()
    });
    if (cfg!(target_os = "linux") && id == "go") || (id == "rust" && (!cfg!(windows) || has_rustup))
    {
        let core = options
            .prepared_core
            .as_ref()
            .ok_or_else(|| invalid("Verified Core required for official SDK install"))?;
        fs::create_dir_all(&options.log_dir)?;
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(invalid)?
            .as_nanos();
        let result = options.log_dir.join(format!("sdk-provider-{stamp}.json"));
        let script = options.configuration().join("scripts/install-sdk.lua");
        if !script.is_file() {
            return Err(invalid(format!("SDK worker missing: {}", script.display())));
        }
        return Ok(Recipe {
            program:core.join(if cfg!(windows){"bin/nvim.exe"}else{"bin/nvim"}),
            args:vec!["--headless".into(),"-u".into(),"NONE".into(),"-i".into(),"NONE".into(),"-l".into(),script.into_os_string(),id.into(),result.clone().into_os_string()],
            source:if id=="go" {"Официальный stable Go: go.dev metadata/archive/SHA256, обычный ~/sdk/go<version>; существующие SDK сохраняются. https://go.dev/dl/"}
                else {"Официальный rustup: обычные Cargo/Rustup homes, rustfmt/rust-src; без изменения shell profiles/PATH. https://rustup.rs/"}.into(),
            preserve_nextest:None,sdk_result:Some(result),
        });
    }
    if id == "cargo-nextest" {
        let home = std::env::var_os("CARGO_HOME")
            .map(PathBuf::from)
            .or_else(|| {
                std::env::var_os(if cfg!(windows) { "USERPROFILE" } else { "HOME" })
                    .map(|p| PathBuf::from(p).join(".cargo"))
            })
            .ok_or_else(|| {
                invalid(
                    "Cargo home не найден; задайте CARGO_HOME или выберите существующий nextest",
                )
            })?;
        let target = home.join("bin").join(if cfg!(windows) {
            "cargo-nextest.exe"
        } else {
            "cargo-nextest"
        });
        let (program, args) = if cfg!(windows) {
            (manager("powershell",&path).unwrap_or_else(||PathBuf::from(crate::sdk_settings::default_powershell())),
             vec![OsString::from("-NoProfile"),"-Command".into(),r#"$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; $script=Invoke-RestMethod -Uri 'https://get.nexte.st/install.ps1' -TimeoutSec 180; Invoke-Expression -Command $script"#.into()])
        } else {
            (PathBuf::from("/bin/sh"),vec!["-c".into(),r#"set -e; script="$(curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 --connect-timeout 15 --max-time 180 'https://get.nexte.st/install.sh')"; /bin/sh -c "$script""#.into()])
        };
        return Ok(Recipe{program,args,source:format!("cargo-nextest: официальный готовый binary с upstream SHA256; {}. SDK/PATH не меняются. https://nexte.st/docs/installation/pre-built-binaries/",target.display()),preserve_nextest:Some(target),sdk_result:None});
    }
    let (manager, items, source) = if cfg!(windows) {
        let package = match id {
            "go" => "GoLang.Go",
            "rust" => "Rustlang.Rustup",
            "node" => "OpenJS.NodeJS.LTS",
            "python" => "Python.Python.3.14",
            "git" => "Git.Git",
            _ => return Err(invalid("Unknown SDK")),
        };
        ("winget",vec!["install","--exact","--id",package,"--source","winget","--no-upgrade","--accept-source-agreements","--accept-package-agreements","--disable-interactivity"],"WinGet: версия пакета из репозитория winget; штатные каталоги приложения, возможен UAC")
    } else if cfg!(target_os = "macos") {
        let package = match id {
            "go" => "go",
            "rust" => "rust",
            "node" => "node",
            "python" => "python",
            "git" => "git",
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
            "git" => vec!["git"],
            _ => return Err(invalid("Unknown SDK")),
        };
        let mut args = vec!["install", "--yes", "--no-upgrade"];
        args.extend(packages);
        ("apt-get",args,"APT: версии из настроенных репозиториев; системные каталоги /usr и cache APT, возможен sudo")
    };
    let program = manager_path(manager, &path)?;
    let mut recipe = Recipe {
        program,
        args: items.into_iter().map(OsString::from).collect(),
        source: source.into(),
        preserve_nextest: None,
        sdk_result: None,
    };
    if manager == "winget" && id == "rust" {
        recipe.args.extend([
            "--override".into(),
            "-y --no-modify-path --profile minimal --component rustfmt --component rust-src".into(),
        ]);
    }
    if manager == "apt-get" {
        // apt --yes covers package choices, not debconf (for example tzdata).
        // Keep this inside sudo's environment boundary and out of the caller.
        recipe.args.insert(0, recipe.program.into_os_string());
        recipe
            .args
            .insert(0, "DEBIAN_FRONTEND=noninteractive".into());
        recipe.program = PathBuf::from("/usr/bin/env");
        if let Some(sudo) = sdks::find("sudo", &path) {
            recipe.args.insert(0, recipe.program.into_os_string());
            recipe.program = sudo;
        }
    }
    Ok(recipe)
}
fn manager_path(name: &str, path: &std::ffi::OsStr) -> Result<PathBuf> {
    manager(name, path).ok_or_else(|| {
        std::io::Error::new(
            std::io::ErrorKind::NotFound,
            format!(
                "{name} не найден. Выберите существующий каталог программы; для Ubuntu необходим штатный APT."
            ),
        )
    })
}
pub(crate) fn installed_selection(recipe: &Recipe, id: &str) -> Result<Option<sdks::Selection>> {
    let Some(path) = &recipe.sdk_result else {
        return Ok(None);
    };
    let file = fs::File::open(path)?;
    if file.metadata()?.len() > 65536 {
        return Err(invalid("SDK provider report exceeds 64KiB"));
    }
    let data: serde_json::Value = serde_json::from_reader(file).map_err(invalid)?;
    if data["schema"] != 1 || data["kind"] != id || data["ready"] != true {
        return Err(invalid("Invalid SDK provider result"));
    }
    let bin = PathBuf::from(
        data["bin"]
            .as_str()
            .ok_or_else(|| invalid("SDK bin missing"))?,
    );
    if !bin.is_absolute() || !bin.is_dir() {
        return Err(invalid("SDK bin must be an existing absolute directory"));
    }
    let selected: sdks::Selection =
        serde_json::from_value(data["selection"].clone()).map_err(invalid)?;
    if selected.bin != bin
        || selected
            .tools
            .values()
            .any(|path| !path.is_absolute() || !path.is_file())
    {
        return Err(invalid("Invalid SDK provider selection"));
    }
    Ok(Some(selected))
}
pub(crate) fn run(options: &Options, paths: &[PathBuf], recipe: &Recipe) -> Result<bool> {
    run_with_env(options, paths, recipe, &[])
}
pub(crate) fn run_with_env(
    options: &Options,
    paths: &[PathBuf],
    recipe: &Recipe,
    environment: &[(OsString, OsString)],
) -> Result<bool> {
    if let Some(target) = &recipe.preserve_nextest {
        let mut search = paths.to_vec();
        search.push(
            target
                .parent()
                .ok_or_else(|| invalid("Missing Cargo bin"))?
                .to_owned(),
        );
        if sdks::inspect(&["cargo-nextest".into()], &options.log_dir, &search)?.ready() {
            cliclack::log::info("Используется уже установленный cargo-nextest; версия сохранена.")?;
            return Ok(true);
        }
        match fs::symlink_metadata(target) {
            Ok(_)=>return Err(invalid(format!("cargo-nextest target уже существует и не готов; файл сохранён: {}. Исправьте его или выберите другой executable в tools.json.",target.display()))),
            Err(error) if error.kind()==std::io::ErrorKind::NotFound=>{},
            Err(error)=>return Err(error),
        }
    }
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
    cliclack::log::info(format!("Штатная установка · лог: {}", log.display()))?;
    let mut command = Command::new(&recipe.program);
    command
        .args(&recipe.args)
        .env("PATH", sdks::effective_path(paths)?)
        .envs(environment.iter().map(|(key, value)| (key, value)))
        .env_remove("FRIDE_SDK_BASE")
        .env_remove("FRIDE_SDK_PROJECT")
        .env("HOMEBREW_NO_AUTO_UPDATE", "1")
        .env("HOMEBREW_NO_INSTALL_UPGRADE", "1");
    if let Some(target) = &recipe.preserve_nextest {
        // Use the reviewed destination, including when the caller has another
        // upstream install-directory override. This does not change their env.
        command.env(
            "NEXTEST_INSTALL_DIR",
            target
                .parent()
                .ok_or_else(|| invalid("Missing Cargo bin"))?,
        );
    }
    let mut child = command
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
            "Штатная установка завершилась с {status}; лог: {}",
            log.display()
        ))?;
    }
    Ok(status.success())
}

// Read-only: native installers can register paths without changing this process.
pub(crate) fn registered_paths() -> Result<Vec<PathBuf>> {
    if cfg!(target_os = "macos") {
        return Ok(["/opt/homebrew/bin", "/usr/local/bin"]
            .into_iter()
            .map(PathBuf::from)
            .filter(|p| p.is_dir())
            .collect());
    }
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
