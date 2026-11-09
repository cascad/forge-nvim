pub const FORGE_ANSWER: i32 = 42;

pub fn calculate_answer(value: i32) -> i32 {
    value * 2
}

#[cfg(test)]
mod tests {
    #[test]
    fn nearest_pass() {
        let value = super::calculate_answer(21);
        let observed = value; // E2E_BREAKPOINT
        println!("RUST_TEST_VALUE {observed}");
        assert_eq!(value, 42);
    }

    #[test]
    fn neighbor_fail() {
        std::fs::write("neighbor-ran.txt", "yes").unwrap();
        assert_eq!(1, 2, "FORGE_EXPECTED_TEST_FAILURE");
    }
}
