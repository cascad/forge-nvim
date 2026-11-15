// Native single-process fixture for version/error/timeout; never installs SDKs.
fn main() {
    let name = std::env::current_exe().unwrap().file_stem().unwrap().to_string_lossy().to_string();
    if ["winget","apt-get","sudo","brew"].contains(&name.as_str()) {
        use std::io::Write;
        let trace=std::env::var("SDK_PACKAGE_TRACE").unwrap();
        let previous=std::fs::read_to_string(&trace).unwrap_or_default().lines().count();
        let mut file=std::fs::OpenOptions::new().create(true).append(true).open(trace).unwrap();
        writeln!(file,"{}\t{}",name,std::env::args().skip(1).collect::<Vec<_>>().join("\t")).unwrap();
        println!("fixture package manager");
        let mode=std::env::var("SDK_PACKAGE_MODE").unwrap_or_default();
        if mode=="fail" || (mode=="once-fail" && previous==0) {std::process::exit(7);}
        if mode=="noop" {return;}
        let root=std::path::PathBuf::from(std::env::var("SDK_PACKAGE_BIN").unwrap());
        std::fs::create_dir_all(&root).unwrap();
        std::fs::copy(std::env::current_exe().unwrap(),root.join(if cfg!(windows) {"node.exe"} else {"node"})).unwrap();
        let npm=root.join(if cfg!(windows) {"npm.cmd"} else {"npm"});std::fs::write(&npm,"fixture entrypoint\n").unwrap();
        #[cfg(unix)] {use std::os::unix::fs::PermissionsExt;std::fs::set_permissions(npm,std::fs::Permissions::from_mode(0o755)).unwrap();}
        return;
    }
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
        "node" => "v24.11.0",
        _ => "unknown fixture",
    });
}
