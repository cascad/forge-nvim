// spec: IDE-BOOT-52. OS requirements are separate from language SDKs.
use crate::{invalid, sdk_install, sdk_settings, sdks, Options, Plan, Result};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashSet};
use std::fs;
use std::io::{self, IsTerminal, Read};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[derive(Deserialize)]
struct Catalog {
    schema: u8,
    requirements: Vec<Requirement>,
}
#[derive(Deserialize)]
struct Requirement {
    id: String,
    scopes: Vec<String>,
    command: Option<String>,
    library: Option<String>,
    apt: Vec<String>,
}
#[derive(Serialize)]
pub(crate) struct Missing {
    id: String,
    requirement: String,
}
#[derive(Serialize)]
pub(crate) struct Report {
    schema: u8,
    platform: String,
    family: String,
    scopes: Vec<String>,
    missing: Vec<Missing>,
    packages: Vec<String>,
}
impl Report {
    pub(crate) fn ready(&self) -> bool {
        self.missing.is_empty()
    }
    fn summary(&self) -> String {
        self.missing
            .iter()
            .map(|entry| format!("{}: {}", entry.id, entry.requirement))
            .collect::<Vec<_>>()
            .join("\n")
    }
}
fn read(path: &Path, limit: u64) -> Result<Vec<u8>> {
    let file = fs::File::open(path)?;
    if file.metadata()?.len() > limit {
        return Err(invalid(format!(
            "Oversized system metadata: {}",
            path.display()
        )));
    }
    let mut bytes = vec![];
    file.take(limit + 1).read_to_end(&mut bytes)?;
    if bytes.len() as u64 > limit {
        return Err(invalid("Oversized system metadata"));
    }
    Ok(bytes)
}
fn family(text: &str) -> String {
    let mut id = String::new();
    let mut like = String::new();
    for line in text.lines() {
        if let Some(value) = line.strip_prefix("ID=") {
            id = value.trim().trim_matches(['\'', '"']).to_lowercase();
        }
        if let Some(value) = line.strip_prefix("ID_LIKE=") {
            like = value.trim().trim_matches(['\'', '"']).to_lowercase();
        }
    }
    // An explicit Arch identity must not be routed to APT even with noisy likes.
    if matches!(id.as_str(), "arch" | "omarchy") || like.split_whitespace().any(|v| v == "arch") {
        return "arch".into();
    }
    if matches!(id.as_str(), "ubuntu" | "debian")
        || like
            .split_whitespace()
            .any(|v| v == "debian" || v == "ubuntu")
    {
        return "debian".into();
    }
    if id.is_empty() {
        "unknown".into()
    } else {
        id
    }
}
fn package_name(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= 128
        && name.as_bytes()[0].is_ascii_alphanumeric()
        && name
            .bytes()
            .all(|v| v.is_ascii_lowercase() || v.is_ascii_digit() || b"+.-".contains(&v))
}
pub(crate) fn scopes(plan: &Plan) -> Vec<String> {
    let mut result = vec!["core".into()];
    if plan.components.iter().any(|id| id == "terminal") {
        result.push("terminal".into());
    }
    if plan.prepare_languages && plan.components.iter().any(|id| id == "rust") {
        result.push("rust".into());
    }
    result
}
pub(crate) fn inspect(options: &Options, plan: &Plan) -> Result<Report> {
    let mut report = Report {
        schema: 1,
        platform: std::env::consts::OS.into(),
        family: std::env::consts::OS.into(),
        scopes: scopes(plan),
        missing: vec![],
        packages: vec![],
    };
    if !cfg!(target_os = "linux") {
        return Ok(report);
    }
    report.family =
        family(&String::from_utf8(read(Path::new("/etc/os-release"), 65536)?).map_err(invalid)?);
    let catalog: Catalog = serde_json::from_slice(&read(
        &options
            .configuration()
            .join("scripts/system-dependencies.json"),
        65536,
    )?)
    .map_err(invalid)?;
    if catalog.schema != 1 {
        return Err(invalid("Unsupported system requirements catalog"));
    }
    let selected = catalog
        .requirements
        .into_iter()
        .filter(|item| {
            item.scopes
                .iter()
                .any(|scope| report.scopes.contains(scope))
        })
        .collect::<Vec<_>>();
    let path = sdks::effective_path(&plan.sdk_paths)?;
    let mut libraries = HashSet::new();
    if selected.iter().any(|entry| entry.library.is_some()) {
        let linker=sdks::find("ldconfig",&path).or_else(||["/usr/sbin/ldconfig","/sbin/ldconfig"].iter().map(PathBuf::from).find(|p|p.is_file()))
            .ok_or_else(||invalid("Не найден ldconfig для read-only проверки library cache; проверь системный loader"))?;
        let mut command = Command::new(linker);
        command.arg("-p").env("PATH", &path);
        let output = sdk_settings::capture_complete(
            command,
            options,
            Duration::from_secs(5),
            2 * 1024 * 1024,
        )?;
        for line in output.lines() {
            if let Some(name) = line.split_whitespace().next() {
                libraries.insert(name.to_owned());
            }
        }
    }
    let mut packages = BTreeSet::new();
    for entry in selected {
        if entry.id.is_empty()
            || entry.command.is_some() == entry.library.is_some()
            || entry.apt.is_empty()
            || entry.apt.iter().any(|name| !package_name(name))
        {
            return Err(invalid("Invalid system requirement catalog entry"));
        }
        let (name, ready) = if let Some(command) = entry.command {
            (command.clone(), sdks::find(&command, &path).is_some())
        } else {
            let name = entry.library.unwrap();
            let ready = libraries.contains(&name);
            (name, ready)
        };
        if !ready {
            report.missing.push(Missing {
                id: entry.id,
                requirement: name,
            });
            if report.family == "debian" {
                packages.extend(entry.apt);
            }
        }
    }
    report.packages = packages.into_iter().collect();
    Ok(report)
}
fn save(options: &Options, report: &Report) -> Result<PathBuf> {
    fs::create_dir_all(&options.log_dir)?;
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(invalid)?
        .as_nanos();
    let file = options.log_dir.join(format!("system-{stamp}.json"));
    serde_json::to_writer_pretty(
        fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&file)?,
        report,
    )
    .map_err(invalid)?;
    Ok(file)
}
pub(crate) fn ensure(options: &Options, plan: &Plan) -> Result<bool> {
    let report = inspect(options, plan)?;
    if report.ready() {
        return Ok(true);
    }
    let file = save(options, &report)?;
    if report.family != "debian" {
        return Err(invalid(format!("Системные зависимости не готовы: {}. Native APT provider только Debian/Ubuntu; для {} используй штатный manager. Omarchy/pacman: IDE-143. Отчёт: {}",report.summary(),report.family,file.display())));
    }
    let update = sdk_install::apt_recipe(
        &plan.sdk_paths,
        vec!["update".into()],
        "Обновить индекс штатных репозиториев APT; конфигурация repositories сохраняется",
    )?;
    let mut args = vec![
        "install".into(),
        "--yes".into(),
        "--no-upgrade".into(),
        "--no-remove".into(),
    ];
    args.extend(report.packages.iter().map(Into::into));
    let install = sdk_install::apt_recipe(
        &plan.sdk_paths,
        args,
        "Системные зависимости выбранных компонентов; транзитивные зависимости решает штатный APT",
    )?;
    eprintln!(
        "Системные зависимости ОС\n{}\n{}\n{}\nОтчёт: {}",
        report.summary(),
        update.display(),
        install.display(),
        file.display()
    );
    let policy = if options.system_deps.is_empty() {
        "ask"
    } else {
        options.system_deps.as_str()
    };
    if policy == "check"
        || policy == "ask" && !(io::stdin().is_terminal() && io::stderr().is_terminal())
    {
        return Err(invalid("Системные зависимости не готовы. Для явной автоматической установки укажи --system-deps install; проверка не изменяла ОС"));
    }
    if policy == "ask" {
        match cliclack::confirm("Установить системные зависимости ОС?")
            .initial_value(true)
            .interact()
        {
            Ok(true) => {}
            Ok(false) => return Ok(false),
            Err(error) if error.kind() == io::ErrorKind::Interrupted => return Ok(false),
            Err(error) => return Err(error),
        }
    }
    for recipe in [&update, &install] {
        if !sdk_install::run(options, &plan.sdk_paths, recipe)? {
            return Err(invalid(
                "Установка системных зависимостей не завершилась; смотри native package log",
            ));
        }
    }
    let checked = inspect(options, plan)?;
    let after = save(options, &checked)?;
    if !checked.ready() {
        return Err(invalid(format!(
            "Команда завершилась, но системные зависимости не готовы: {}. Отчёт: {}",
            checked.summary(),
            after.display()
        )));
    }
    eprintln!("Системные зависимости ОС готовы; языковые SDK этим шагом не устанавливались.");
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn native_distribution_routing() {
        assert_eq!(family("ID=ubuntu\nID_LIKE=debian"), "debian");
        assert_eq!(family("ID=debian"), "debian");
        assert_eq!(family("ID=omarchy\nID_LIKE=\"arch\""), "arch");
        assert_eq!(family("ID=arch\nID_LIKE=debian"), "arch");
        assert_eq!(family("ID=some\nID_LIKE=arch"), "arch");
        assert_eq!(family("ID=fedora\nID_LIKE=rhel"), "fedora");
    }
    #[test]
    fn packages_are_native_names_not_flags_or_shell() {
        assert!(package_name("libx11-xcb1"));
        assert!(package_name("build-essential"));
        for name in ["--allow", "pkg;echo", "$(id)", "foo bar", ""] {
            assert!(!package_name(name));
        }
    }
}
