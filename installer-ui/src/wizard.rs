// Тема и navigation pattern LocalVox; MIT notice в LOCALVOX-LICENSE.txt.
use crate::{invalid, review, Options, Plan, Result, Row};
use std::io;

struct InstallerTheme {
    can_go_back: bool,
}
impl cliclack::Theme for InstallerTheme {
    fn format_footer_with_message(&self, state: &cliclack::ThemeState, message: &str) -> String {
        let help = if self.can_go_back {
            "Esc — назад / отмена"
        } else {
            "Esc — отмена"
        };
        let line = match state {
            cliclack::ThemeState::Active => format!(
                "└  {}{help}",
                if message.is_empty() {
                    String::new()
                } else {
                    format!("{message} · ")
                }
            ),
            cliclack::ThemeState::Cancel => "└  Ввод прерван".into(),
            cliclack::ThemeState::Submit => "│".into(),
            cliclack::ThemeState::Error(error) => format!("└  {error} · {help}"),
        };
        format!("{}\n", self.bar_color(state).apply_to(line))
    }
}

pub(crate) fn intro(preview: bool) -> Result<()> {
    cliclack::intro(
        console::style(" Fride · установка ")
            .on_cyan()
            .black()
            .bold(),
    )?;
    if preview {
        cliclack::log::info("ПРЕДПРОСМОТР · Установка не запускается.")?;
    }
    cliclack::log::info(
        "Редактор и инструменты — отдельным комплектом. Ваш Neovim и настройки сохраняются.",
    )
}

#[derive(Clone, Copy)]
enum Step {
    Profile,
    Components,
    Directories,
    InstallPath,
    Command,
    CommandPath,
    Review,
}
enum Move {
    Next(Step),
    Back,
    Stay,
    Cancel,
    Finish,
}

fn path(prompt: &str, value: &str) -> Result<String> {
    cliclack::input(prompt)
        .default_input(value)
        .validate(|input: &String| {
            if input.trim().is_empty() || input.chars().any(char::is_control) {
                Err("Введите путь без управляющих символов")
            } else {
                Ok(())
            }
        })
        .interact()
}

fn navigation() -> Result<Move> {
    cliclack::set_theme(InstallerTheme { can_go_back: false });
    cliclack::select("Вернуться или отменить?")
        .item(0, "← Назад", "Подтверждённые ответы сохранятся")
        .item(1, "Продолжить текущий шаг", "Вернуться к вводу")
        .item(2, "Отменить установку", "Выйти без установки")
        .initial_value(0)
        .interact()
        .map(|answer| match answer {
            0 => Move::Back,
            1 => Move::Stay,
            _ => Move::Cancel,
        })
}

pub(crate) fn choose(options: &Options, rows: &[Row], mut plan: Plan) -> Result<Option<Plan>> {
    intro(options.preview)?;
    let mut history = vec![];
    let mut step = if options.profile == "custom" {
        Step::Components
    } else {
        Step::Profile
    };
    let mut custom = options.profile == "custom";
    let mut custom_path = false;
    let mut register = !plan.command_dir.is_empty();
    let mut saved_command_path = plan.command_dir.clone();
    if saved_command_path.is_empty() {
        let home = std::env::var("USERPROFILE")
            .or_else(|_| std::env::var("HOME"))
            .unwrap_or_default();
        saved_command_path = std::path::Path::new(&home)
            .join(".local/bin")
            .to_string_lossy()
            .into();
    }
    loop {
        cliclack::set_theme(InstallerTheme {
            can_go_back: !history.is_empty(),
        });
        let mut confirmed = None;
        let answer: Result<Move> = (|| match step {
            Step::Profile => {
                custom = cliclack::select("Как установить Fride?")
                    .item(
                        false,
                        "Установить всё необходимое",
                        "Рекомендуемый набор · без ручной подготовки",
                    )
                    .item(true, "Выбрать компоненты", "Языки, папки и команда запуска")
                    .initial_value(custom)
                    .interact()?;
                Ok(Move::Next(if custom {
                    Step::Components
                } else {
                    Step::Review
                }))
            }
            Step::Components => {
                cliclack::note(
                    "Всегда включено",
                    "✓ Редактор, поиск и базовые инструменты\nCore входит в любую установку.",
                )?;
                let visible: Vec<_> = rows
                    .iter()
                    .filter(|r| r.label != "-" && r.id != "core")
                    .collect();
                let mut prompt =
                    cliclack::multiselect("Компоненты · ↑/↓ · Пробел — галочка · Enter — дальше")
                        .required(false);
                for row in &visible {
                    prompt = prompt.item(row.id.clone(), &row.label, "");
                }
                let selected = prompt
                    .initial_values(
                        plan.components
                            .iter()
                            .filter(|id| visible.iter().any(|r| r.id == **id))
                            .cloned()
                            .collect(),
                    )
                    .interact()?;
                plan.select(rows, selected)?;
                Ok(Move::Next(Step::Directories))
            }
            Step::Directories => {
                custom_path = cliclack::select("Куда установить комплект?")
                    .item(
                        false,
                        "Использовать предложенную папку",
                        &options.install_dir,
                    )
                    .item(
                        true,
                        "Выбрать другую папку",
                        "Отсутствующие каталоги будут созданы",
                    )
                    .initial_value(custom_path)
                    .interact()?;
                if !custom_path {
                    plan.install_dir = options.install_dir.clone();
                }
                Ok(Move::Next(if custom_path {
                    Step::InstallPath
                } else {
                    Step::Command
                }))
            }
            Step::InstallPath => {
                plan.install_dir = path("Папка комплекта", &plan.install_dir)?;
                Ok(Move::Next(Step::Command))
            }
            Step::Command => {
                register = cliclack::select("Команда fride")
                    .item(
                        false,
                        "Запускать по полному пути",
                        "PATH и shell profiles не меняются",
                    )
                    .item(
                        true,
                        "Создать команду в моём bin",
                        "Выберите каталог, уже доступный через PATH",
                    )
                    .initial_value(register)
                    .interact()?;
                if !register {
                    plan.command_dir.clear();
                }
                Ok(Move::Next(if register {
                    Step::CommandPath
                } else {
                    Step::Review
                }))
            }
            Step::CommandPath => {
                saved_command_path = path("Каталог команды fride", &saved_command_path)?;
                plan.command_dir = saved_command_path.clone();
                Ok(Move::Next(Step::Review))
            }
            Step::Review => {
                let reviewed = if custom {
                    plan.clone()
                } else {
                    let mut value = plan.clone();
                    value.select(
                        rows,
                        rows.iter().filter(|r| r.label != "-").map(|r| r.id.clone()),
                    )?;
                    value.install_dir = options.install_dir.clone();
                    value.command_dir = options.command_dir.clone();
                    value
                };
                cliclack::note("Перед установкой", review(rows, &reviewed))?;
                let answer = cliclack::select(if options.preview {
                    "Завершить предпросмотр?"
                } else {
                    "Начать установку?"
                })
                .item(
                    0,
                    "Продолжить",
                    if options.preview {
                        "Установка не запускается"
                    } else {
                        "Подготовить выбранный комплект"
                    },
                )
                .item(1, "← Назад", "Изменить подтверждённые ответы")
                .item(2, "Отменить установку", "Выйти без установки")
                .interact()?;
                Ok(match answer {
                    0 => {
                        confirmed = Some(reviewed);
                        Move::Finish
                    }
                    1 => Move::Back,
                    _ => Move::Cancel,
                })
            }
        })();
        let action = match answer {
            Err(error) if error.kind() == io::ErrorKind::Interrupted => {
                if history.is_empty() {
                    Move::Cancel
                } else {
                    match navigation() {
                        Err(error) if error.kind() == io::ErrorKind::Interrupted => Move::Cancel,
                        other => other?,
                    }
                }
            }
            other => other?,
        };
        match action {
            Move::Next(next) => {
                history.push(step);
                step = next;
            }
            Move::Back => {
                step = history
                    .pop()
                    .ok_or_else(|| invalid("Нет предыдущего шага"))?;
            }
            Move::Stay => {}
            Move::Cancel => return Ok(None),
            Move::Finish => return Ok(confirmed),
        }
    }
}
