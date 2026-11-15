// Native single-process fixture for version/error/timeout; never installs SDKs.
fn main() {
    let name = std::env::current_exe().unwrap().file_stem().unwrap().to_string_lossy().to_string();
    if let Ok(path) = std::env::var("SDK_PROBE_MARKER") {
        std::fs::write(path, format!("{}\n{}\n{}\n", name,
            std::env::var("GOTOOLCHAIN").unwrap_or_default(),
            std::env::var("RUSTUP_AUTO_INSTALL").unwrap_or_default())).unwrap();
    }
    match std::env::var("SDK_PROBE_MODE").as_deref() {
        Ok("timeout") => std::thread::sleep(std::time::Duration::from_secs(30)),
        Ok("invalid") => { println!("not a language SDK"); return; }
        Ok("exit") => { eprintln!("fixture SDK unavailable"); std::process::exit(7); }
        _ => {}
    }
    println!("{}", match name.as_str() {
        "go" => "go version go1.26.0 fixture/fixture",
        "rustc" => "rustc 1.96.1 (fixture)",
        "cargo" => "cargo 1.96.1 (fixture)",
        "python" => "Python 2.7.18",
        "python3" => "Python 3.14.0",
        _ => "unknown fixture",
    });
}
