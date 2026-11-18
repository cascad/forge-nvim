// spec: IDE-BOOT-13. Presentation без установки SDK/пакетов в пользовательскую ОС.
mod runtime;
mod sdk_actions;
mod sdk_bootstrap;
mod sdk_install;
mod sdk_settings;
mod sdks;
mod wizard;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs::{self, OpenOptions};
use std::io::{self, BufRead, BufReader, IsTerminal, Read, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

type Result<T> = io::Result<T>;
pub(crate) fn invalid(message: impl ToString) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidInput, message.to_string())
}

#[derive(Default)]
pub struct Options {
    pub source: PathBuf,
    pub install_dir: String,
    pub command_dir: String,
    pub profile: String,
    pub components: Option<String>,
    pub runtime: String,
    pub runtime_url: String,
    pub runtime_sha: String,
    pub powershell: String,
    pub log_dir: PathBuf,
    pub result_file: Option<PathBuf>,
    pub preview: bool,
    pub plain: bool,
    pub print_plan: bool,
    pub check_sdks: bool,
    pub check_tools: bool,
    pub sdk_report: Option<PathBuf>,
    pub sdk_paths: Vec<PathBuf>,
    pub go_toolchain_download: Option<bool>,
    prepared_core: Option<PathBuf>,
}

impl Options {
    pub fn parse(arguments: impl IntoIterator<Item = String>) -> Result<Self> {
        let mut result = Self {
            source: std::env::current_dir()?,
            powershell: sdk_settings::default_powershell(),
            ..Default::default()
        };
        let mut arguments = arguments.into_iter();
        while let Some(argument) = arguments.next() {
            match argument.as_str() {
                "--preview" => {
                    result.preview = true;
                    continue;
                }
                "--plain" | "--no-color" => {
                    result.plain = true;
                    continue;
                }
                "--print-plan" => {
                    result.print_plan = true;
                    continue;
                }
                "--check-sdks" => {
                    result.check_sdks = true;
                    continue;
                }
                "--check-tools" => {
                    result.check_tools = true;
                    continue;
                }
                "--help" => {
                    println!("fride-setup --source DIR --profile default|custom [--components CSV] --install-dir DIR\n--command-dir DIR --runtime-path DIR --runtime-archive-url URL --runtime-sha256 SHA\n--preview --no-color --print-plan --result FILE --log-dir DIR\n--check-sdks --sdk-report FILE\n--go-toolchain-download allow|deny (explicit Go build toolchain choice; default deny)\n--check-tools (Git prerequisite) --tool-path DIR (repeatable fallback bin; alias --sdk-path)");
                    std::process::exit(0);
                }
                _ => {}
            }
            let (key, value) = if let Some((key, value)) = argument.split_once('=') {
                (key.to_owned(), value.to_owned())
            } else {
                let value = arguments
                    .next()
                    .ok_or_else(|| invalid(format!("Нет значения: {argument}")))?;
                (argument, value)
            };
            match key.as_str() {
                "--source" => result.source = value.into(),
                "--install-dir" => result.install_dir = value,
                "--command-dir" => result.command_dir = value,
                "--profile" => result.profile = value.to_ascii_lowercase(),
                "--components" => result.components = Some(value),
                "--runtime-path" => result.runtime = value,
                "--runtime-archive-url" => result.runtime_url = value,
                "--runtime-sha256" => result.runtime_sha = value,
                "--powershell" => result.powershell = value,
                "--log-dir" => result.log_dir = value.into(),
                "--result" => result.result_file = Some(value.into()),
                "--sdk-report" => result.sdk_report = Some(value.into()),
                "--sdk-path" | "--tool-path" => result.sdk_paths.push(value.into()),
                "--go-toolchain-download" => result.go_toolchain_download = Some(match value.as_str() {
                    "allow" => true,
                    "deny" => false,
                    _ => return Err(invalid("--go-toolchain-download: allow или deny")),
                }),
                _ => return Err(invalid(format!("Неизвестный параметр: {key}"))),
            }
        }
        if !matches!(result.profile.as_str(), "" | "default" | "custom") {
            return Err(invalid("Профиль: default или custom"));
        }
        if result.install_dir.is_empty() {
            let base = if cfg!(windows) {
                std::env::var_os("LOCALAPPDATA").map(PathBuf::from)
            } else {
                std::env::var_os("XDG_DATA_HOME")
                    .map(PathBuf::from)
                    .or_else(|| {
                        std::env::var_os("HOME")
                            .map(|home| PathBuf::from(home).join(".local/share"))
                    })
            }
            .ok_or_else(|| invalid("Не найдена домашняя папка"))?;
            result.install_dir = base
                .join("forge-nvim/installation")
                .to_string_lossy()
                .into();
        }
        if result.log_dir.as_os_str().is_empty() {
            result.log_dir = result.source.join(".tests/installer-ui/logs");
        }
        Ok(result)
    }
}

#[derive(Clone)]
pub(crate) struct Row {
    pub id: String,
    pub label: String,
    pub dependencies: Vec<String>,
}

pub(crate) fn table(source: &std::path::Path) -> Result<Vec<Row>> {
    let content = fs::read_to_string(source.join("nvim_forge/scripts/components.tsv"))?;
    let mut rows = Vec::new();
    let mut ids = HashSet::new();
    for line in content.lines() {
        let parts: Vec<_> = line.split('\t').collect();
        if parts.len() != 5 || !ids.insert(parts[0].to_owned()) {
            return Err(invalid("Некорректная таблица компонентов"));
        }
        rows.push(Row {
            id: parts[0].into(),
            label: parts[1].into(),
            dependencies: if parts[2] == "-" {
                vec![]
            } else {
                parts[2].split(',').map(str::to_owned).collect()
            },
        });
    }
    if !ids.contains("core")
        || rows
            .iter()
            .any(|r| r.dependencies.iter().any(|id| !ids.contains(id)))
    {
        return Err(invalid("Некорректные зависимости компонентов"));
    }
    Ok(rows)
}

pub(crate) fn resolve(
    rows: &[Row],
    selected: impl IntoIterator<Item = String>,
) -> Result<Vec<String>> {
    let mut selected: HashSet<_> = selected
        .into_iter()
        .filter(|v| !v.trim().is_empty())
        .map(|v| v.trim().to_ascii_lowercase())
        .collect();
    selected.insert("core".into());
    for id in &selected {
        if !rows.iter().any(|row| row.id == *id) {
            return Err(invalid(format!("Unknown component: {id}")));
        }
    }
    loop {
        let before = selected.len();
        for row in rows {
            if selected.contains(&row.id) {
                selected.extend(row.dependencies.iter().cloned());
            }
        }
        if selected.len() == before {
            break;
        }
    }
    Ok(rows
        .iter()
        .filter(|r| selected.contains(&r.id))
        .map(|r| r.id.clone())
        .collect())
}

#[derive(Clone, Serialize)]
pub(crate) struct Plan {
    pub schema: u8,
    pub components: Vec<String>,
    pub native_sdks: Vec<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub sdk_paths: Vec<PathBuf>,
    pub install_dir: String,
    pub command_dir: String,
    pub go_toolchain_download: bool,
}

impl Plan {
    pub(crate) fn select(
        &mut self,
        rows: &[Row],
        selected: impl IntoIterator<Item = String>,
    ) -> Result<()> {
        let components = resolve(rows, selected)?;
        self.native_sdks = sdks::required(&components);
        self.components = components
            .into_iter()
            .filter(|id| !sdks::is_sdk_part(id))
            .collect();
        Ok(())
    }
}

fn review(rows: &[Row], plan: &Plan) -> String {
    let mut lines = vec![];
    for row in rows.iter().filter(|r| plan.components.contains(&r.id)) {
        let label = match row.id.as_str() {
            "core" => "Редактор, поиск и базовые инструменты",
            _ => &row.label,
        };
        lines.push(format!("✓ {label}"));
    }
    lines.extend([
        String::new(),
        format!("Комплект: {}", plan.install_dir),
        if plan.command_dir.is_empty() {
            "Запуск: полный путь к bin/fride; PATH не меняется".into()
        } else {
            format!("Команда fride: {} (без изменения PATH)", plan.command_dir)
        },
    ]);
    if !plan.native_sdks.is_empty() {
        lines.push(format!(
            "SDK из вашей системы: {}",
            plan.native_sdks.join(", ")
        ));
    }
    if plan.native_sdks.iter().any(|sdk| sdk == "go") {
        lines.push(format!("Загрузка Go для сборки IDE tools: {}", if plan.go_toolchain_download { "разрешена" } else { "запрещена" }));
    }
    for path in &plan.sdk_paths {
        lines.push(format!("Внешний fallback (после PATH): {}", path.display()));
    }
    lines.push("Git из вашей системы (обязателен для Core)".into());
    lines.join("\n")
}

pub fn run(mut options: Options) -> Result<i32> {
    let rows = table(&options.source)?;
    let selected = options
        .components
        .as_deref()
        .map(|csv| csv.split(',').map(str::to_owned).collect())
        .unwrap_or_else(|| {
            rows.iter()
                .filter(|r| r.label != "-")
                .map(|r| r.id.clone())
                .collect::<Vec<_>>()
        });
    let mut plan = Plan {
        schema: 1,
        components: vec![],
        native_sdks: vec![],
        sdk_paths: vec![],
        install_dir: options.install_dir.clone(),
        command_dir: options.command_dir.clone(),
        go_toolchain_download: options.go_toolchain_download.unwrap_or(false),
    };
    plan.select(&rows, selected)?;
    // Upgrade reuses only locations recorded by an owned fride installation.
    let marker = PathBuf::from(&plan.install_dir).join(".forge-install.json");
    if let Ok(bytes) = fs::read(&marker) {
        if let Ok(owner) = serde_json::from_slice::<serde_json::Value>(&bytes) {
            if owner["product"] == "forge-nvim" && owner["schema"] == 1 {
                if let Ok(text) =
                    fs::read_to_string(PathBuf::from(&plan.install_dir).join("bin/sdk-paths.txt"))
                {
                    for line in text.lines().filter(|line| !line.is_empty()) {
                        let _ = sdks::add_path(&mut plan, PathBuf::from(line));
                    }
                }
            }
        }
    }
    for path in &options.sdk_paths {
        sdks::add_path(&mut plan, path.clone())?;
    }
    if options.print_plan {
        println!("{}", serde_json::to_string(&plan)?);
        return Ok(0);
    }
    if options.check_sdks {
        if !plan.native_sdks.is_empty() {
            options.prepared_core = Some(sdk_settings::prepare(&options, &plan)?);
        }
        let report = inspect_sdks(&options, &plan)?;
        write_sdk_report(&options, &report)?;
        println!("{}", serde_json::to_string(&report)?);
        return Ok(if report.ready() { 0 } else { 2 });
    }
    if options.check_tools {
        let report = inspect_tools(&options, &plan)?;
        println!("{}", serde_json::to_string(&tool_report(&report))?);
        return Ok(if report.ready() { 0 } else { 2 });
    }
    let automatic = options.components.is_some() || options.profile == "default";
    let plain = options.plain || !io::stderr().is_terminal();
    let color = !plain && std::env::var_os("NO_COLOR").is_none();
    console::set_colors_enabled(color);
    console::set_colors_enabled_stderr(color);
    if !automatic {
        if !io::stdin().is_terminal() || !io::stderr().is_terminal() {
            return Err(invalid(
                "Custom требует интерактивный терминал; для автоматизации укажите --components",
            ));
        }
        match wizard::choose(&options, &rows, plan)? {
            Some(value) => plan = value,
            None => {
                cliclack::outro_cancel("Отменено. Установка не запускалась.")?;
                return Ok(130);
            }
        }
    } else if plain {
        eprintln!("Fride · установка\n{}", review(&rows, &plan));
    } else {
        wizard::intro(options.preview)?;
        cliclack::note("План установки", review(&rows, &plan))?;
    }
    if !options.preview {
        let report = inspect_tools(&options, &plan)?;
        let interactive = io::stdin().is_terminal() && io::stderr().is_terminal();
        let report = if !report.ready() && interactive {
            match sdk_actions::configure_git(&options, &rows, &mut plan, report)? {
                Some(report) => report,
                None => {
                    cliclack::outro_cancel("Отмена IDE. Прежний комплект сохранён; явно установленные программы остаются в системе.")?;
                    return Ok(130);
                }
            }
        } else {
            report
        };
        if plain {
            eprintln!("Git\n{}", report.summary());
        } else {
            cliclack::note("Git", report.summary())?;
        }
        if !report.ready() {
            return Err(invalid(format!("Git prerequisite не готов. Выберите Git в PATH/--tool-path или установите его штатно. IDE artifacts не загружались; прежний комплект сохранён. Отчёты: {}", options.log_dir.display())));
        }
    }
    if !options.preview && !plan.native_sdks.is_empty() {
        options.prepared_core = Some(sdk_settings::prepare(&options, &plan)?);
        let report = inspect_sdks(&options, &plan)?;
        let interactive = io::stdin().is_terminal() && io::stderr().is_terminal();
        let report = if !report.ready() && interactive {
            match sdk_actions::configure(&options, &rows, &mut plan, report)? {
                Some(report) => report,
                None => {
                    cliclack::outro_cancel("Отмена IDE. Прежний комплект сохранён; явно установленные SDK остаются в системе.")?;
                    return Ok(130);
                }
            }
        } else {
            report
        };
        let file = write_sdk_report(&options, &report)?;
        if !report.sdks.is_empty() {
            if plain {
                eprintln!("Языковые SDK\n{}", report.summary());
            } else {
                cliclack::note("Языковые SDK", report.summary())?;
            }
        }
        if !report.ready() {
            return Err(invalid(format!("SDK prerequisites не готовы. Исправьте/reset сохранённый выбор fride либо выберите SDK в PATH/--sdk-path, установите его штатно или снимите компонент. Core подготовлен; прежний комплект сохранён, остальные компоненты не устанавливались. Отчёт: {}",file.display())));
        }
    }
    if !options.preview && plan.native_sdks.iter().any(|sdk| sdk == "go")
        && options.go_toolchain_download.is_none()
        && io::stdin().is_terminal() && io::stderr().is_terminal()
    {
        cliclack::note("Сборка инструментов Go",
            "Некоторым IDE tools может понадобиться более новый Go. Штатный Go может скачать его в свой кеш для сборки tools. SDK проекта, системные настройки и go.mod сохраняются.")?;
        match cliclack::confirm("Разрешить Go скачать toolchain для сборки IDE tools?")
            .initial_value(false).interact()
        {
            Ok(allow) => plan.go_toolchain_download = allow,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => {
                cliclack::outro_cancel("Отменено. Прежний комплект сохранён.")?;
                return Ok(130);
            }
            Err(error) => return Err(error),
        }
    }
    if !options.preview && plan.native_sdks.iter().any(|sdk| sdk == "go") {
        let message = format!("Go tools: загрузка build toolchain {}; SDK проекта сохраняется.",
            if plan.go_toolchain_download { "разрешена" } else { "запрещена" });
        if plain { eprintln!("{message}"); } else { cliclack::log::info(message)?; }
    }
    if let Some(path) = &options.result_file {
        let mut file = OpenOptions::new().create_new(true).write(true).open(path)?;
        serde_json::to_writer(&mut file, &plan)?;
    }
    if options.preview {
        let message = "Предпросмотр завершён. Установка не запускалась.";
        if plain {
            eprintln!("{message}");
        } else {
            cliclack::outro(message)?;
        }
        return Ok(0);
    }
    execute(&options, &plan, plain)
}

#[derive(Deserialize)]
struct Event {
    stage: String,
    status: String,
}

fn stage_title(stage: &str) -> &str {
    match stage {
        "runtime" => "Среда редактора и инструменты",
        "plugins" => "Плагины редактора",
        "parsers" => "Подсветка языков",
        "tools" => "Языковые инструменты",
        _ => "Подготовка комплекта",
    }
}

fn execute(options: &Options, plan: &Plan, plain: bool) -> Result<i32> {
    let runtime_plan = runtime::selected(options, plan)?;
    fs::create_dir_all(&options.log_dir)?;
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(invalid)?
        .as_nanos();
    let log_path = options
        .log_dir
        .join(format!("install-{timestamp}-{}.log", std::process::id()));
    let mut log = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&log_path)?;
    let runtime_plan_path = if let Some(rows) = runtime_plan {
        let path = log_path.with_extension("runtime.tsv");
        let mut file = OpenOptions::new()
            .create_new(true)
            .write(true)
            .open(&path)?;
        file.write_all(rows.as_bytes())?;
        Some(path)
    } else {
        None
    };
    let mut command = if cfg!(windows) {
        let mut command = Command::new(&options.powershell);
        command
            .args(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"])
            .arg(options.source.join("scripts/install-private.ps1"))
            .arg("-Source")
            .arg(&options.source)
            .arg("-InstallPath")
            .arg(&plan.install_dir);
        if let Some(path) = &runtime_plan_path {
            command.arg("-RuntimePlanPath").arg(path);
        }
        for (flag, value) in [
            ("-RuntimePath", &options.runtime),
            ("-RuntimeArchiveUrl", &options.runtime_url),
            ("-RuntimeSHA256", &options.runtime_sha),
            ("-CommandDir", &plan.command_dir),
        ] {
            if !value.is_empty() {
                command.arg(flag).arg(value);
            }
        }
        command
    } else {
        let mut command = Command::new("/bin/bash");
        command
            .arg(options.source.join("scripts/install-private.sh"))
            .arg(&options.source)
            .arg(&plan.install_dir)
            .args([
                &options.runtime,
                &options.runtime_url,
                &options.runtime_sha,
                &plan.command_dir,
            ])
            .arg(
                runtime_plan_path
                    .as_ref()
                    .map(|p| p.as_os_str())
                    .unwrap_or_default(),
            );
        command
    };
    command
        .env("PATH", sdks::effective_path(&plan.sdk_paths)?)
        .env("FORGE_SDK_PATHS", serde_json::to_string(&plan.sdk_paths)?)
        .env("FORGE_NVIM_COMPONENTS", plan.components.join(","))
        .env("FRIDE_INSTALL_UI", "1")
        .env("FRIDE_SETUP_GO_TOOLCHAIN", if plan.go_toolchain_download { "auto" } else { "local" })
        // Installation must not turn a missing toolchain into an implicit SDK download.
        .env("GOTOOLCHAIN", "local")
        .env("RUSTUP_AUTO_INSTALL", "0")
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .stdin(Stdio::null());
    let mut child = command.spawn()?;
    let (sender, receiver) = mpsc::channel();
    fn reader(
        pipe: impl Read + Send + 'static,
        sender: mpsc::Sender<(bool, Vec<u8>)>,
        stderr: bool,
    ) -> std::thread::JoinHandle<()> {
        std::thread::spawn(move || {
            let mut reader = BufReader::new(pipe);
            loop {
                let mut line = vec![];
                match reader.read_until(b'\n', &mut line) {
                    Ok(0) | Err(_) => break,
                    Ok(_) => {
                        if sender.send((stderr, line)).is_err() {
                            break;
                        }
                    }
                }
            }
        })
    }
    let out = reader(child.stdout.take().unwrap(), sender.clone(), false);
    let err = reader(child.stderr.take().unwrap(), sender.clone(), true);
    drop(sender);
    let spinner = cliclack::spinner();
    if plain {
        eprintln!("Подготовка комплекта · лог: {}", log_path.display());
    } else {
        cliclack::log::info(format!("Подробный лог: {}", log_path.display()))?;
        spinner.start("Подготовка комплекта");
    }
    let mut launch = String::new();
    let mut last_stage = String::new();
    let mut first_error = String::new();
    loop {
        match receiver.recv_timeout(Duration::from_millis(100)) {
            Ok((stderr, line)) => {
                log.write_all(&line)?;
                let text = String::from_utf8_lossy(&line);
                if stderr && first_error.is_empty() && !text.trim().is_empty() {
                    first_error = text
                        .trim()
                        .chars()
                        .filter(|c| !c.is_control())
                        .take(220)
                        .collect();
                }
                if let Some(data) = text.trim().strip_prefix("FRIDE_EVENT\t") {
                    if let Ok(event) = serde_json::from_str::<Event>(data) {
                        last_stage = event.stage;
                        let title = stage_title(&last_stage);
                        let status = match event.status.as_str() {
                            "start" => "подготовка",
                            "ready" => "готово",
                            "error" => "ошибка",
                            other => other,
                        };
                        if plain {
                            eprintln!("{title}: {status}");
                        } else {
                            spinner.set_message(title);
                        }
                    }
                }
                if let Some(path) = text.trim().strip_prefix("Launch: ") {
                    launch = path.into();
                }
                if let Some(path) = text.trim().strip_prefix("Registered launcher: ") {
                    launch = path.into();
                }
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => break,
            Err(mpsc::RecvTimeoutError::Timeout) => {}
        }
    }
    out.join().map_err(|_| invalid("Ошибка чтения stdout"))?;
    err.join().map_err(|_| invalid("Ошибка чтения stderr"))?;
    let code = child.wait()?.code().unwrap_or(1);
    log.flush()?;
    if code != 0 {
        let message = format!(
            "{}: ошибка. {}\nЛог: {}",
            stage_title(&last_stage),
            first_error,
            log_path.display()
        );
        if plain {
            eprintln!("{message}");
        } else {
            spinner.error(message);
        }
    } else {
        if plain {
            eprintln!("Подготовка завершена. Запуск: {launch}");
        } else {
            spinner.stop("Подготовка завершена");
            cliclack::outro(format!("Запуск: {launch}"))?;
        }
    }
    Ok(code)
}

fn sdk_report_path(options: &Options) -> PathBuf {
    options.sdk_report.clone().unwrap_or_else(|| {
        options.log_dir.join(format!(
            "sdks-{}-{}.json",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_nanos(),
            std::process::id()
        ))
    })
}

pub(crate) fn inspect_sdks(options: &Options, plan: &Plan) -> Result<sdks::Report> {
    let snapshot = sdk_settings::snapshot(options, plan)?;
    let report = sdks::inspect_selected(
        &plan.native_sdks,
        &options.log_dir,
        &plan.sdk_paths,
        &snapshot,
    )?;
    if !plan.native_sdks.is_empty() {
        fs::create_dir_all(&options.log_dir)?;
        let path = options.log_dir.join(format!(
            "sdk-check-{}.json",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map_err(invalid)?
                .as_nanos()
        ));
        serde_json::to_writer_pretty(
            OpenOptions::new().create_new(true).write(true).open(path)?,
            &report,
        )?;
    }
    Ok(report)
}

fn tool_report(report: &sdks::Report) -> serde_json::Value {
    serde_json::json!({"schema": 1, "tools": report.sdks})
}

pub(crate) fn inspect_tools(options: &Options, plan: &Plan) -> Result<sdks::Report> {
    let report = sdks::inspect(&["git".into()], &options.log_dir, &plan.sdk_paths)?;
    fs::create_dir_all(&options.log_dir)?;
    let path = options.log_dir.join(format!(
        "tools-{}-{}.json",
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(invalid)?
            .as_nanos(),
        std::process::id()
    ));
    serde_json::to_writer_pretty(
        OpenOptions::new().create_new(true).write(true).open(path)?,
        &tool_report(&report),
    )?;
    Ok(report)
}

fn write_sdk_report(options: &Options, report: &sdks::Report) -> Result<PathBuf> {
    let path = sdk_report_path(options);
    if let Some(parent) = path.parent().filter(|p| !p.as_os_str().is_empty()) {
        fs::create_dir_all(parent)?;
    }
    let mut file = OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&path)?;
    serde_json::to_writer_pretty(&mut file, &report)?;
    Ok(path)
}
