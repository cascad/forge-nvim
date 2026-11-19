// IDE-BOOT-50. Prepare only the requested language; never replace the running kit.
use crate::{invalid, sdk_actions, sdk_install, sdks, Options, Plan, Result};
use std::fs::{self, OpenOptions};
use std::io::{self, IsTerminal};
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

fn rust_components(
    options: &Options,
    plan: &Plan,
    report: &sdks::Report,
    interactive: bool,
) -> Result<bool> {
    let rustc = report
        .sdks
        .iter()
        .find(|sdk| sdk.id == "rust")
        .and_then(|sdk| sdk.tools.first())
        .and_then(|tool| tool.path.clone())
        .ok_or_else(|| invalid("Rust SDK missing"))?;
    let check = || -> Result<serde_json::Value> {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(invalid)?
            .as_nanos();
        let result = options
            .log_dir
            .join(format!("rust-components-{stamp}.json"));
        let mut command = std::process::Command::new(
            options
                .prepared_core
                .as_ref()
                .ok_or_else(|| invalid("Core missing"))?
                .join(if cfg!(windows) {
                    "bin/nvim.exe"
                } else {
                    "bin/nvim"
                }),
        );
        command
            .args(["--headless", "-u", "NONE", "-i", "NONE", "-l"])
            .arg(options.source.join("scripts/check-rust-components.lua"))
            .arg(&rustc)
            .arg(&result)
            .arg("project")
            .env("PATH", sdks::effective_path(&plan.sdk_paths)?)
            .envs(plan.provisioned_environment()?)
            .env("NVIM_APPNAME", "fride")
            .env_remove("FRIDE_SDK_BASE")
            .env_remove("FRIDE_SDK_PROJECT");
        crate::sdk_settings::capture(command, options, std::time::Duration::from_secs(30))?;
        let data: serde_json::Value =
            serde_json::from_reader(fs::File::open(result)?).map_err(invalid)?;
        if data["schema"] != 1 {
            return Err(invalid("Invalid Rust component report"));
        }
        Ok(data)
    };
    let data = check()?;
    if data["ready"] == true {
        return Ok(true);
    }
    let repair = &data["repair"];
    if !interactive || repair.is_null() {
        return Err(invalid(format!(
            "Rust components не готовы: {}. {}",
            data["missing"], data["error"]
        )));
    }
    let program = PathBuf::from(
        repair["program"]
            .as_str()
            .ok_or_else(|| invalid("Rustup executable missing"))?,
    );
    let args = repair["args"]
        .as_array()
        .ok_or_else(|| invalid("Rustup argv missing"))?
        .iter()
        .map(|arg| {
            arg.as_str()
                .map(std::ffi::OsString::from)
                .ok_or_else(|| invalid("Invalid Rustup argument"))
        })
        .collect::<Result<Vec<_>>>()?;
    let source = repair["source"]
        .as_str()
        .unwrap_or("rustup components")
        .to_owned();
    let recipe = sdk_install::Recipe {
        program,
        args,
        source,
        preserve_nextest: None,
        sdk_result: None,
    };
    cliclack::note(
        "Компоненты Rust SDK",
        format!("{}\n{}", recipe.source, recipe.display()),
    )?;
    let choice = cliclack::confirm("Добавить компоненты Rust SDK этой командой?")
        .initial_value(false)
        .interact();
    let accept = match choice {
        Ok(value) => value,
        Err(error) if error.kind() == io::ErrorKind::Interrupted => false,
        Err(error) => return Err(error),
    };
    if !accept {
        return Ok(false);
    }
    let environment = repair["environment"]
        .as_object()
        .ok_or_else(|| invalid("Rustup environment missing"))?
        .iter()
        .map(|(key, value)| {
            value
                .as_str()
                .map(|value| (key.into(), value.into()))
                .ok_or_else(|| invalid("Invalid Rustup environment"))
        })
        .collect::<Result<Vec<_>>>()?;
    if !sdk_install::run_with_env(options, &plan.sdk_paths, &recipe, &environment)? {
        return Err(invalid("Rustup component installation failed"));
    }
    let after = check()?;
    if after["ready"] != true {
        return Err(invalid(format!(
            "Rust components не готовы после команды: {after}"
        )));
    }
    Ok(true)
}

pub(crate) fn prepare(mut options: Options) -> Result<i32> {
    if options.preview
        || options.print_plan
        || options.check_sdks
        || options.check_tools
        || options.check_rust_tools
        || options.check_system
    {
        return Err(invalid(
            "Language preparation cannot be combined with preview/check modes",
        ));
    }
    let kind = options
        .prepare_language
        .clone()
        .ok_or_else(|| invalid("Language required"))?;
    if !["go", "rust", "python", "node", "bash", "sql"].contains(&kind.as_str()) {
        return Err(invalid("Language: go, rust, python, node, bash or sql"));
    }
    let kit = options
        .installed_kit
        .clone()
        .ok_or_else(|| invalid("--installed-kit required"))?;
    let kit = if kit.is_absolute() {
        kit
    } else {
        std::env::current_dir()?.join(kit)
    };
    let owner: serde_json::Value =
        serde_json::from_reader(fs::File::open(kit.join(".forge-install.json"))?)
            .map_err(invalid)?;
    if owner["schema"] != 1 || owner["product"] != "forge-nvim" || owner["ready"] != true {
        return Err(invalid("Ready fride installation required"));
    }
    options.source = kit.join("config/forge");
    options.runtime = kit.join("runtime").to_string_lossy().into();
    options.prepared_core = Some(kit.join("runtime"));
    options.install_dir = kit.to_string_lossy().into();
    options.prepare_languages = true;
    fs::create_dir_all(&options.log_dir)?;
    if options
        .result_file
        .as_ref()
        .is_some_and(|path| path.exists())
    {
        return Err(invalid("Use a new language result path"));
    }
    let rows = crate::table_file(&options.source.join("scripts/components.tsv"))?;
    let mut plan = Plan {
        schema: 1,
        components: vec![],
        native_sdks: vec![],
        prepare_languages: true,
        sdk_paths: vec![],
        install_dir: options.install_dir.clone(),
        command_dir: String::new(),
        provisioned_sdks: Default::default(),
        go_toolchain_download: options.go_toolchain_download.unwrap_or(false),
        tools_versions: if options.tools_versions.is_empty() {
            "preserve".into()
        } else {
            options.tools_versions.clone()
        },
    };
    plan.select(&rows, vec!["core".into(), kind.clone()])?;
    for path in &options.sdk_paths {
        sdks::add_path(&mut plan, path.clone())?;
    }
    if let Ok(paths) = fs::read_to_string(kit.join("bin/sdk-paths.txt")) {
        for path in paths.lines().filter(|line| !line.is_empty()) {
            let _ = sdks::add_path(&mut plan, PathBuf::from(path));
        }
    }
    let interactive = io::stdin().is_terminal() && io::stderr().is_terminal();
    if interactive {
        cliclack::intro(format!("Fride · подготовка {kind}"))?;
    }
    eprintln!("SDK и инструменты {kind}; редактор и проект продолжают работать.");
    if !crate::system::ensure(&options, &plan)? {
        return Ok(130);
    }
    // The installed preflight validates Core even for a language without an SDK.
    let report = crate::inspect_sdks(&options, &plan)?;
    let report = if !report.ready() && interactive {
        match sdk_actions::configure(&options, &rows, &mut plan, report)? {
            Some(report) => report,
            None => return Ok(130),
        }
    } else {
        report
    };
    if !plan.components.contains(&kind) {
        return Ok(130);
    }
    if !report.ready() {
        return Err(invalid(format!("SDK не готов: {}", report.summary())));
    }
    if kind == "rust" {
        if !rust_components(&options, &plan, &report, interactive)? {
            return Ok(130);
        }
        let tools = crate::inspect_rust_tools(&options, &plan)?;
        let tools = if !tools.ready() && interactive {
            match sdk_actions::configure_rust_tools(&options, &rows, &mut plan, tools)? {
                Some(tools) => tools,
                None => return Ok(130),
            }
        } else {
            tools
        };
        if !plan.components.contains(&kind) {
            return Ok(130);
        }
        if !tools.ready() {
            return Err(invalid(format!(
                "Rust test tools не готовы: {}",
                tools.summary()
            )));
        }
    }
    if kind == "go"
        && interactive
        && options.go_toolchain_download.is_none()
        && !crate::configure_go_build(&mut plan)?
    {
        return Ok(130);
    }
    let runtime = kit.join("runtime");
    let nvim = runtime.join(if cfg!(windows) {
        "bin/nvim.exe"
    } else {
        "bin/nvim"
    });
    let preinit = "lua vim.opt.rtp:prepend(vim.env.FRIDE_CONFIG);require('forge.setup_sdks').prepare({scope='project'})";
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(invalid)?
        .as_nanos();
    let mut args = vec![
        "--headless".into(),
        "-i".into(),
        "NONE".into(),
        "--cmd".into(),
        preinit.into(),
        "-u".into(),
    ];
    args.push(options.source.join("init.lua").into_os_string());
    args.push("-l".into());
    args.push(
        options
            .source
            .join("scripts/setup-stage.lua")
            .into_os_string(),
    );
    args.push("tools".into());
    // run() tees output and rejects native signals. The child gets its selected
    // SDK environment before Mason captures it, just like the original setup.
    let recipe = sdk_install::Recipe {
        program: nvim,
        args,
        source: format!("IDE tools {kind} через штатный Mason; готовые версии сохраняются"),
        preserve_nextest: None,
        sdk_result: None,
    };
    let mut child_options = options;
    // Environment is supplied to run through a scoped Recipe, not parent env.
    let mut environment = vec![
        ("NVIM_APPNAME".into(), "fride".into()),
        (
            "NVIM_LOG_FILE".into(),
            child_options
                .log_dir
                .join(format!("language-{stamp}.nvim.log"))
                .into_os_string(),
        ),
        (
            "FRIDE_CONFIG".into(),
            child_options.source.clone().into_os_string(),
        ),
        ("FRIDE_RUNTIME".into(), runtime.into_os_string()),
        (
            "FORGE_NVIM_COMPONENTS".into(),
            plan.components.join(",").into(),
        ),
        (
            "FORGE_PREPARE_COMPONENTS".into(),
            plan.components.join(",").into(),
        ),
        (
            "FRIDE_SETUP_GO_TOOLCHAIN".into(),
            if plan.go_toolchain_download {
                "auto"
            } else {
                "local"
            }
            .into(),
        ),
        (
            "GOTOOLCHAIN".into(),
            if plan.go_toolchain_download {
                "auto"
            } else {
                "local"
            }
            .into(),
        ),
        ("RUSTUP_AUTO_INSTALL".into(), "0".into()),
        (
            "FRIDE_TOOLS_VERSIONS".into(),
            plan.tools_versions.clone().into(),
        ),
        ("FORGE_INSTALL_TARGET".into(), "".into()),
    ];
    environment.extend(plan.provisioned_environment()?);
    if !sdk_install::run_with_env(&child_options, &plan.sdk_paths, &recipe, &environment)? {
        return Err(invalid(
            "Подготовка IDE tools не завершилась; смотри лог задачи",
        ));
    }
    let report = crate::inspect_sdks(&child_options, &plan)?;
    if !report.ready() {
        return Err(invalid("SDK изменился во время подготовки"));
    }
    let fallback = kit.join("bin/sdk-paths.txt");
    let temporary = kit.join(format!("bin/.sdk-paths-{stamp}.tmp"));
    let paths = plan
        .sdk_paths
        .iter()
        .map(|path| path.to_string_lossy().to_string())
        .collect::<Vec<_>>()
        .join("\n");
    fs::write(
        &temporary,
        if paths.is_empty() {
            paths
        } else {
            paths + "\n"
        },
    )?;
    if let Err(error) = fs::rename(&temporary, &fallback) {
        let _ = fs::remove_file(&temporary);
        return Err(error);
    }
    let result = serde_json::json!({"schema":1,"language":kind,"ready":true,"sdks":report.sdks,"sdk_paths":plan.sdk_paths});
    if let Some(path) = child_options.result_file.take() {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        serde_json::to_writer_pretty(
            OpenOptions::new().create_new(true).write(true).open(path)?,
            &result,
        )?;
    }
    eprintln!("Среда {kind} готова. Выбери SDK и примени его через Языки и инструменты.");
    Ok(0)
}
