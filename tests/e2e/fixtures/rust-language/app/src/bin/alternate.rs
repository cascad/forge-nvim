fn main() {
    let value = forge_math::calculate_answer(21);
    let observed = value; // E2E_BREAKPOINT
    println!("RUST_ALTERNATE {observed} {}", std::env::args().nth(1).unwrap_or_default());
    eprintln!("RUST_ALT_STDERR");
}
