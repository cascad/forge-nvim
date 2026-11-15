use crate::{inspect_sdks, review, sdk_bootstrap, sdk_install, sdks, Options, Plan, Result, Row};
use std::path::{Path, PathBuf};

fn interrupted<T>(value: &Result<T>) -> bool {
    value
        .as_ref()
        .is_err_and(|e| e.kind() == std::io::ErrorKind::Interrupted)
}

fn discover(options: &Options, plan: &mut Plan, id: &str) -> Result<sdks::Report> {
    let report = inspect_sdks(options, plan)?;
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
    let found = inspect_sdks(options, &candidate)?;
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
    inspect_sdks(options, plan)
}

fn existing(options: &Options, plan: &mut Plan, id: &str, root: PathBuf) -> Result<sdks::Report> {
    for directory in [root.clone(), root.join("bin"), root.join("Scripts")] {
        if !directory.is_dir() {
            continue;
        }
        let mut candidate = plan.clone();
        sdks::add_path(&mut candidate, directory)?;
        let report = inspect_sdks(options, &candidate)?;
        if report
            .sdks
            .iter()
            .any(|s| s.id == id && s.status == "ready")
        {
            *plan = candidate;
            return Ok(report);
        }
    }
    Err(crate::invalid("SDK из каталога не готов. Проверьте root/bin и SDK раньше в PATH; приоритет PATH сохраняется."))
}

pub(crate) fn configure(
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
        cliclack::note("Готовность SDK", report.summary())?;
        let action = cliclack::select(format!("SDK {id}: действие"))
            .item(
                0,
                "Выбрать существующий SDK",
                "root/bin; fallback после вашего PATH",
            )
            .item(
                1,
                "Установить штатным способом",
                "Сначала команда и отдельное подтверждение",
            )
            .item(
                2,
                "Пропустить зависимые компоненты",
                "Показать, какие функции будут сняты",
            )
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
                    let input: Result<String> = cliclack::input(format!("Каталог SDK {id}"))
                        .validate(|v: &String| {
                            sdks::directory(Path::new(v))
                                .map(|_| ())
                                .map_err(|e| e.to_string())
                        })
                        .interact();
                    if interrupted(&input) {
                        return Ok(None);
                    }
                    Ok(Some(existing(options, plan, &id, PathBuf::from(input?))?))
                }
                1 => {
                    let recipe = match sdk_install::recipe(&id, &plan.sdk_paths) {
                        Ok(recipe) => recipe,
                        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                            let Some(bootstrap) = sdk_bootstrap::recipe(options, &plan.sdk_paths)?
                            else {
                                return Err(error);
                            };
                            cliclack::note("Менеджер SDK не найден", format!("{}\n{}\nМенеджер останется в системе при отмене IDE. Языковой SDK подтверждается отдельно.", bootstrap.source, bootstrap.display()))?;
                            let confirm =
                                cliclack::confirm("Установить менеджер SDK этой командой?")
                                    .initial_value(false)
                                    .interact();
                            if interrupted(&confirm) || !confirm? {
                                return Ok(None);
                            }
                            if !sdk_install::run(options, &plan.sdk_paths, &bootstrap)? {
                                return Ok(None);
                            }
                            sdk_install::recipe(&id, &plan.sdk_paths).map_err(|_| crate::invalid("Команда завершилась, но менеджер SDK не найден. Проверьте лог, выберите существующий SDK или повторите."))?
                        }
                        Err(error) => return Err(error),
                    };
                    cliclack::note("Штатная установка SDK",format!("{}\n{}\nНе запрашиваем upgrade выбранного SDK; зависимости обрабатывает штатный менеджер. SDK останется в системе при последующей отмене IDE.",recipe.source,recipe.display()))?;
                    let confirm = cliclack::confirm(format!("Установить SDK {id} этой командой?"))
                        .initial_value(false)
                        .interact();
                    if interrupted(&confirm) || !confirm? {
                        return Ok(None);
                    }
                    if sdk_install::run(options, &plan.sdk_paths, &recipe)? {
                        let checked = discover(options, plan, &id)?;
                        if checked
                            .sdks
                            .iter()
                            .any(|s| s.id == id && s.status != "ready")
                        {
                            cliclack::log::warning("Команда завершилась, но SDK пока не готов. Выберите каталог или исправьте PATH и повторите.")?;
                        }
                        Ok(Some(checked))
                    } else {
                        Ok(None)
                    }
                }
                2 => {
                    let affected = plan
                        .components
                        .iter()
                        .filter(|component| sdks::required(&[(*component).clone()]).contains(&id))
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
                    Ok(Some(inspect_sdks(options, plan)?))
                }
                3 => Ok(Some(discover(options, plan, &id)?)),
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
