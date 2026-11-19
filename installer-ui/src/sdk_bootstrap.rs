// spec: IDE-BOOT-21. Only called after an SDK install action, never at startup.
use crate::{invalid, sdk_install::Recipe, sdks, Options, Result};
use std::path::PathBuf;

pub(crate) fn recipe(options: &Options, paths: &[PathBuf]) -> Result<Option<Recipe>> {
    let path = sdks::effective_path(paths)?;
    if cfg!(windows) {
        let program = sdks::find("powershell", &path)
            .or_else(|| {
                let configured = PathBuf::from(&options.powershell);
                configured.is_file().then_some(configured)
            })
            .or_else(|| std::env::var_os("SystemRoot").map(|p| PathBuf::from(p).join("System32/WindowsPowerShell/v1.0/powershell.exe")).filter(|p| p.is_file()))
            .ok_or_else(|| invalid("Для установки WinGet нужен Windows PowerShell. Выберите существующий SDK или установите App Installer."))?;
        let script = r#"$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; if (-not (Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) { if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) { Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null }; Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Repository PSGallery -Force }; Import-Module Microsoft.WinGet.Client -ErrorAction Stop; Repair-WinGetPackageManager -Force -Latest -ErrorAction Stop"#;
        Ok(Some(Recipe {
            preserve_nextest:None,
            sdk_result:None,
            program,
            args: ["-NoProfile", "-Command", script].into_iter().map(Into::into).collect(),
            source: "WinGet: Microsoft.WinGet.Client из PSGallery, CurrentUser; штатный App Installer текущего пользователя. Может понадобиться системное подтверждение. https://learn.microsoft.com/windows/package-manager/winget/troubleshooting".into(),
        }))
    } else if cfg!(target_os = "macos") {
        let program = sdks::find("bash", &path).unwrap_or_else(|| PathBuf::from("/bin/bash"));
        // Pinned official installer, not a moving HEAD or a third-party mirror.
        // set -e prevents an unsuccessful/partial curl download from being run.
        let script = r#"set -e; script="$(/usr/bin/curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 --connect-timeout 15 --max-time 180 'https://raw.githubusercontent.com/Homebrew/install/e5b3c5834e3932c8aaa42deef4794076c9b0cbf0/install.sh')"; /bin/bash -c "$script""#;
        Ok(Some(Recipe {
            preserve_nextest:None,
            sdk_result:None,
            program,
            args: ["-c", script].into_iter().map(Into::into).collect(),
            source: "Homebrew: официальный Homebrew/install, commit e5b3c5834e3932c8aaa42deef4794076c9b0cbf0; стандартный /opt/homebrew либо /usr/local. Установщик может запросить пароль sudo и Command Line Tools. https://docs.brew.sh/Installation".into(),
        }))
    } else {
        Ok(None)
    }
}
