// Native single-process fixture for version/error/timeout; never installs SDKs.
fn main() {
    let name = std::env::current_exe().unwrap().file_stem().unwrap().to_string_lossy().to_string();
    if name=="mise" {
        use std::io::Write;
        let args:Vec<_>=std::env::args().skip(1).collect();
        let root=std::path::PathBuf::from(std::env::var("SDK_MISE_ROOT").expect("controlled Mise fixture only"));
        let mut trace=std::fs::OpenOptions::new().create(true).append(true).open(std::env::var("SDK_MISE_TRACE").unwrap()).unwrap();
        writeln!(trace,"{}",args.join("\t")).unwrap();
        match args[0].as_str() {
            "ls"=>println!("{}",if std::env::var("SDK_MISE_CONFIGURED").as_deref()==Ok("1") {"[{\"requested_version\":\"24\"}]"} else {"[]"}),
            "where"=>{if !root.join("ready").exists() {std::process::exit(2);} println!("{}",root.display());},
            "install"=>{
                match std::env::var("SDK_MISE_MODE").as_deref() {Ok("fail")=>{eprintln!("Mise fixture install failed");std::process::exit(7);},Ok("noop")=>return,_=>{}}
                std::fs::create_dir_all(root.join("bin")).unwrap();
                for tool in ["go","rustc","cargo","node","npm","python3"] {std::fs::copy(std::env::current_exe().unwrap(),root.join("bin").join(tool)).unwrap();}
                std::fs::write(root.join("ready"),"controlled SDK fixture").unwrap();
            },
            _=>panic!("Unexpected Mise command"),
        }
        return;
    }
    if let Ok(folder)=std::env::var("SYSTEM_FIXTURE_BIN") {
        use std::io::Write;
        let args:Vec<_>=std::env::args().skip(1).collect();
        let state=std::path::PathBuf::from(std::env::var("SYSTEM_FIXTURE_STATE").unwrap());
        if name=="ldconfig" {
            // Needed entry is beyond the old 16KiB diagnostic-tail bound.
            for index in 0..1500 {println!("libfixture-padding-{}.so.1 (libc6) => /fixture/lib{}.so",index,index);}
            if state.exists() {println!("libfride-fixture-gui.so.1 (libc6) => /fixture/libgui.so.1");}
            return;
        }
        if name=="sudo" || name=="apt-get" || name=="pacman" {
            let mut trace=std::fs::OpenOptions::new().create(true).append(true).open(std::env::var("SYSTEM_FIXTURE_TRACE").unwrap()).unwrap();
            writeln!(trace,"{}\t{}\t{}",name,std::env::var("DEBIAN_FRONTEND").unwrap_or_default(),args.join("\t")).unwrap();
            if name=="sudo" {
                let status=std::process::Command::new(&args[0]).args(&args[1..]).status().unwrap();std::process::exit(status.code().unwrap_or(1));
            }
            if args.iter().any(|arg|arg=="install" || arg=="-S") {
                match std::env::var("SYSTEM_FIXTURE_MODE").as_deref() {
                    Ok("fail")=>std::process::exit(7),Ok("noop")=>return,_=>{}
                }
                let bin=std::path::PathBuf::from(folder);
                for (package,command) in [("unzip","fride-probe-unzip"),("build-essential","fride-probe-cc"),("base-devel","fride-probe-cc")] {
                    if args.iter().any(|arg|arg==package) {std::fs::copy(std::env::current_exe().unwrap(),bin.join(command)).unwrap();}
                }
                if args.iter().any(|arg|arg=="libegl1" || arg=="libglvnd") {std::fs::write(state,"ready").unwrap();}
            }
            return;
        }
    }
    if ["powershell", "bash"].contains(&name.as_str()) {
        use std::io::Write;
        let trace = std::env::var("SDK_BOOTSTRAP_TRACE").expect("bootstrap fixture only");
        let previous = std::fs::read_to_string(&trace).unwrap_or_default().lines().count();
        let mut file = std::fs::OpenOptions::new().create(true).append(true).open(trace).unwrap();
        writeln!(file, "{}\t{}", name, std::env::args().skip(1).collect::<Vec<_>>().join("\t")).unwrap();
        println!("fixture manager bootstrap");
        let mode = std::env::var("SDK_BOOTSTRAP_MODE").unwrap_or_default();
        if mode == "fail" || (mode == "once-fail" && previous == 0) { std::process::exit(7); }
        if mode == "noop" { return; }
        let root = std::path::PathBuf::from(std::env::var("SDK_BOOTSTRAP_BIN").unwrap());
        std::fs::create_dir_all(&root).unwrap();
        std::fs::copy(std::env::current_exe().unwrap(), root.join(if cfg!(windows) {"winget.exe"} else {"brew"})).unwrap();
        return;
    }
    if ["winget","apt-get","sudo","brew","pacman"].contains(&name.as_str()) {
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
        if std::env::args().any(|arg| arg == "Git.Git" || arg == "git") {
            std::fs::copy(std::env::current_exe().unwrap(),root.join(if cfg!(windows) {"git.exe"} else {"git"})).unwrap();
            return;
        }
        if std::env::args().any(|arg|arg=="python" || arg=="python3") {
            std::fs::copy(std::env::current_exe().unwrap(),root.join(if cfg!(windows) {"python3.exe"} else {"python3"})).unwrap();
            return;
        }
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
    if name == "go" && std::env::args().nth(1).as_deref()==Some("env") && std::env::args().nth(2).as_deref()==Some("GOROOT") {
        println!("{}",std::env::current_exe().unwrap().parent().unwrap().parent().unwrap().display());
        return;
    }
    if name == "curl" {
        if let Ok(folder) = std::env::var("SDK_PROVIDER_FIXTURE") {
            let folder=std::path::PathBuf::from(folder);
            let args:Vec<_>=std::env::args().collect();
            if let Some(index)=args.iter().position(|arg|arg=="--output") {
                std::fs::copy(folder.join("go.tar.gz"),&args[index+1]).unwrap();
            } else {print!("{}",std::fs::read_to_string(folder.join("metadata.json")).unwrap());}
            return;
        }
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
        "npm" => "10.9.0",
        "git" => "git version 2.51.0 fixture",
        _ => "unknown fixture",
    });
}
