fn main() {
    let value = forge_math::calculate_answer(21);
    let observed = value; // E2E_BREAKPOINT
    println!("RUST_BEFORE {observed}");
    eprintln!("RUST_STDERR");
    println!("RUST_AFTER {}", std::env::args().nth(1).unwrap_or_default());
    std::fs::write("rust-cwd.txt", std::env::current_dir().unwrap().to_string_lossy().as_bytes()).unwrap();
}
