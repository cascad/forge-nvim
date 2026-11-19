use crate::{
    inspect_rust_tools, inspect_sdks, inspect_tools, review, sdk_bootstrap, sdk_install, sdks,
    Options, Plan, Result, Row,
};
use std::path::{Path, PathBuf};

fn interrupted<T>(value: &Result<T>) -> bool {
    value
        .as_ref()
        .is_err_and(|e| e.kind() == std::io::ErrorKind::Interrupted)
}

#[derive(Clone, Copy)]
enum Subject {
    Sdks,
    Git,
    RustTools,
}
impl Subject {
    fn git(self) -> bool {
        matches!(self, Self::Git)
    }
    fn label(self, id: &str) -> String {
        if self.rust_tools() {
            "Rust Tests · cargo-nextest".into()
        } else if self.git() {
            "Git".into()
        } else {
            format!("SDK {id}")
        }
    }
    fn inspect(self, options: &Options, plan: &Plan) -> Result<sdks::Report> {
        if self.rust_tools() {
            inspect_rust_tools(options, plan)
        } else if self.git() {
            inspect_tools(options, plan)
        } else {
            inspect_sdks(options, plan)
        }
    }
    fn rust_tools(self) -> bool {
        matches!(self, Self::RustTools)
    }
    fn noun(self) -> &'static str {
        if self.git() {
            "Git"
        } else if self.rust_tools() {
            "cargo-nextest"
        } else {
            "SDK"
        }
    }
}

fn discover(
    subject: Subject,
    options: &Options,
    plan: &mut Plan,
    id: &str,
) -> Result<sdks::Report> {
    let report = subject.inspect(options, plan)?;
    if report
        .sdks
        .iter()
        .any(|s| s.id == id && s.status == "ready")
    {
        return Ok(report);
    }
    let mut candidate = plan.clone();
    for path in sdk_install::registered_paths()? {
        let _ = sdks::add_path(&mut candidate, path);
    }
    let found = subject.inspect(options, &candidate)?;
    if let Some(sdk) = found
        .sdks
        .iter()
        .find(|s| s.id == id && s.status == "ready")
    {
        for tool in &sdk.tools {
            if let Some(path) = tool.path.as_ref().and_then(|p| p.parent()) {
                sdks::add_path(plan, path.to_owned())?;
            }
        }
    }
    subject.inspect(options, plan)
}

fn existing(
    subject: Subject,
    options: &Options,
    plan: &mut Plan,
    id: &str,
    root: PathBuf,
) -> Result<sdks::Report> {
    for directory in [
        root.clone(),
        root.join("bin"),
        root.join(if subject.git() { "cmd" } else { "Scripts" }),
    ] {
        if !directory.is_dir() {
            continue;
        }
        let mut candidate = plan.clone();
        sdks::add_path(&mut candidate, directory)?;
        let report = subject.inspect(options, &candidate)?;
        if report
            .sdks
            .iter()
            .any(|s| s.id == id && s.status == "ready")
        {
            *plan = candidate;
            return Ok(report);
        }
    }
    Err(crate::invalid(format!("{} из каталога не готов. Проверьте root/bin{} и программу раньше в PATH; приоритет PATH сохраняется.", subject.noun(), if subject.git() { "/cmd" } else { "" })))
}

pub(crate) fn configure(
    options: &Options,
    rows: &[Row],
    plan: &mut Plan,
    report: sdks::Report,
) -> Result<Option<sdks::Report>> {
    configure_for(Subject::Sdks, options, rows, plan, report)
}

pub(crate) fn configure_git(
    options: &Options,
    rows: &[Row],
    plan: &mut Plan,
    report: sdks::Report,
) -> Result<Option<sdks::Report>> {
    configure_for(Subject::Git, options, rows, plan, report)
}

pub(crate) fn configure_rust_tools(
    options: &Options,
    rows: &[Row],
    plan: &mut Plan,
    report: sdks::Report,
) -> Result<Option<sdks::Report>> {
    configure_for(Subject::RustTools, options, rows, plan, report)
}

fn configure_for(
    subject: Subject,
    options: &Options,
    rows: &[Row],
    plan: &mut Plan,
    mut report: sdks::Report,
) -> Result<Option<sdks::Report>> {
    loop {
        let Some(id) = report
            .sdks
            .iter()
            .find(|sdk| sdk.status != "ready")
            .map(|s| s.id.clone())
        else {
            cliclack::note("Обновлённый план", review(rows, plan))?;
            let proceed = cliclack::confirm("Продолжить установку IDE с этим планом?")
                .initial_value(true)
                .interact();
            if interrupted(&proceed) {
                return Ok(None);
            }
            return Ok(if proceed? { Some(report) } else { None });
        };
        let label = subject.label(&id);
        cliclack::note(format!("Готовность {}", subject.noun()), report.summary())?;
        let mut menu = cliclack::select(format!("{label}: действие"))
            .item(
                0,
                format!("Выбрать существующий {}", subject.noun()),
                if subject.git() {
                    "root/bin/cmd; fallback после вашего PATH"
                } else {
                    "root/bin; fallback после вашего PATH"
                },
            )
            .item(
                1,
                "Установить штатным способом",
                "Сначала команда и отдельное подтверждение",
            );
        if !subject.git() {
            menu = menu.item(
                2,
                "Пропустить зависимые компоненты",
                "Показать, какие функции будут сняты",
            );
        }
        let action = menu
            .item(
                3,
                "Проверить снова",
                "После внешней установки или исправления PATH",
            )
            .item(4, "Отменить установку IDE", "Прежний комплект сохраняется")
            .interact();
        if interrupted(&action) {
            return Ok(None);
        }
        let action = action?;
        if action == 4 {
            return Ok(None);
        }
        let result = (|| -> Result<Option<sdks::Report>> {
            match action {
                0 => {
                    let input: Result<String> = cliclack::input(format!("Каталог {label}"))
                        .validate(|v: &String| {
                            sdks::directory(Path::new(v))
                                .map(|_| ())
                                .map_err(|e| e.to_string())
                        })
                        .interact();
                    if interrupted(&input) {
                        return Ok(None);
                    }
                    Ok(Some(existing(
                        subject,
                        options,
                        plan,
                        &id,
                        PathBuf::from(input?),
                    )?))
                }
                1 => {
                    let recipe = match sdk_install::recipe(options, &id, &plan.sdk_paths) {
                        Ok(recipe) => recipe,
                        Err(error)
                            if error.kind() == std::io::ErrorKind::NotFound
                                && !subject.rust_tools() =>
                        {
                            let Some(bootstrap) = sdk_bootstrap::recipe(options, &plan.sdk_paths)?
                            else {
                                return Err(error);
                            };
                            cliclack::note(if subject.git() { "Менеджер для Git не найден" } else { "Менеджер SDK не найден" }, format!("{}\n{}\nМенеджер останется в системе при отмене IDE. Установка программы подтверждается отдельно.", bootstrap.source, bootstrap.display()))?;
                            let confirm = cliclack::confirm(if subject.git() {
                                "Установить менеджер для Git этой командой?"
                            } else {
                                "Установить менеджер SDK этой командой?"
                            })
                            .initial_value(false)
                            .interact();
                            if interrupted(&confirm) || !confirm? {
                                return Ok(None);
                            }
                            if !sdk_install::run(options, &plan.sdk_paths, &bootstrap)? {
                                return Ok(None);
                            }
                            sdk_install::recipe(options, &id, &plan.sdk_paths).map_err(|_| crate::invalid(format!("Команда завершилась, но менеджер {} не найден. Проверьте лог, выберите существующий каталог или повторите.", if subject.git() { "для Git" } else { "SDK" })))?
                        }
                        Err(error) => return Err(error),
                    };
                    cliclack::note(format!("Штатная установка {}",subject.noun()),format!("{}\n{}\nНе запрашиваем upgrade выбранной программы; зависимости обрабатывает штатный менеджер. Программа останется в системе при последующей отмене IDE.",recipe.source,recipe.display()))?;
                    let confirm = cliclack::confirm(format!("Установить {label} этой командой?"))
                        .initial_value(false)
                        .interact();
                    if interrupted(&confirm) || !confirm? {
                        return Ok(None);
                    }
                    if sdk_install::run(options, &plan.sdk_paths, &recipe)? {
                        if let Some(selected) = sdk_install::installed_selection(&recipe, &id)? {
                            sdks::add_path(plan, selected.bin.clone())?;
                            plan.provisioned_sdks.insert(id.clone(), selected);
                        }
                        let checked = discover(subject, options, plan, &id)?;
                        if checked
                            .sdks
                            .iter()
                            .any(|s| s.id == id && s.status != "ready")
                        {
                            cliclack::log::warning(format!("Команда завершилась, но {} пока не готов. Выберите каталог или исправьте PATH и повторите.", subject.noun()))?;
                        }
                        Ok(Some(checked))
                    } else {
                        Ok(None)
                    }
                }
                2 if !subject.git() => {
                    let affected = plan
                        .components
                        .iter()
                        .filter(|component| {
                            sdks::required(&[(*component).clone()]).contains(&if subject
                                .rust_tools()
                            {
                                "rust".into()
                            } else {
                                id.clone()
                            })
                        })
                        .cloned()
                        .collect::<Vec<_>>();
                    let labels = rows
                        .iter()
                        .filter(|r| affected.contains(&r.id))
                        .map(|r| r.label.as_str())
                        .collect::<Vec<_>>()
                        .join(", ");
                    let confirm = cliclack::confirm(format!("Убрать компоненты: {labels}?"))
                        .initial_value(false)
                        .interact();
                    if interrupted(&confirm) || !confirm? {
                        return Ok(None);
                    }
                    plan.select(
                        rows,
                        plan.components
                            .iter()
                            .filter(|c| !affected.contains(c))
                            .cloned()
                            .collect::<Vec<_>>(),
                    )?;
                    Ok(Some(subject.inspect(options, plan)?))
                }
                3 => Ok(Some(discover(subject, options, plan, &id)?)),
                _ => unreachable!("SDK action"),
            }
        })();
        match result {
            Ok(Some(next)) => report = next,
            Ok(None) => {}
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => return Ok(None),
            Err(error) => {
                cliclack::log::warning(error.to_string())?;
            }
        }
    }
}
