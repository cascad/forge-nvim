use fride_setup::Options;

fn main() {
    let result = Options::parse(std::env::args().skip(1)).and_then(fride_setup::run);
    match result {
        Ok(code) => std::process::exit(code),
        Err(error) => {
            eprintln!("Fride: {error}");
            std::process::exit(2);
        }
    }
}
