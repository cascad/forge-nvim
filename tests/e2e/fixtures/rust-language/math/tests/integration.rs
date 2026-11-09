#[test]
fn integration_pass() {
    assert_eq!(forge_math::calculate_answer(21), 42);
    println!("RUST_INTEGRATION_OK");
}
