pub fn run(label: &str) {
    std::fs::write("rust-target-ran.txt", label).unwrap();
    let value = 42;
    let observed = value; // E2E_BREAKPOINT
    println!("RUST_CHOICE_{label} {observed}");
}
