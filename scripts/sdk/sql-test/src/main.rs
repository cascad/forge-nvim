// spec: IDE-SQL-8. SQLLogicTest supplies parsing, conditions and expected comparison.
use rusqlite::{types::ValueRef, Connection, OpenFlags};
use serde_json::{json, Value};
use sqllogictest::{DBOutput, DefaultColumnType, Record, RecordOutput, Runner, DB};
use std::{env, fs, path::PathBuf, process::ExitCode};

struct Sqlite(Connection);

impl DB for Sqlite {
    type Error = rusqlite::Error;
    type ColumnType = DefaultColumnType;

    fn engine_name(&self) -> &str {
        "sqlite"
    }

    fn run(&mut self, sql: &str) -> Result<DBOutput<Self::ColumnType>, Self::Error> {
        let mut statement = self.0.prepare(sql)?;
        let count = statement.column_count();
        if count == 0 {
            drop(statement);
            let before = self.0.total_changes();
            self.0.execute_batch(sql)?;
            return Ok(DBOutput::StatementComplete(self.0.total_changes() - before));
        }
        let mut rows = statement.query([])?;
        let mut output = Vec::new();
        while let Some(row) = rows.next()? {
            let mut values = Vec::new();
            for column in 0..count {
                values.push(match row.get_ref(column)? {
                    ValueRef::Null => "NULL".to_string(),
                    ValueRef::Integer(value) => value.to_string(),
                    ValueRef::Real(value) => format!("{value:.3}"),
                    ValueRef::Text(value) if value.is_empty() => "(empty)".to_string(),
                    ValueRef::Text(value) => String::from_utf8_lossy(value).into_owned(),
                    ValueRef::Blob(value) => value.iter().map(|b| format!("{b:02x}")).collect(),
                });
            }
            output.push(values);
        }
        // SQLite expressions are dynamically typed. Validate column count;
        // the library validates expected values/order/hash using SLT rules.
        Ok(DBOutput::Rows {
            types: vec![DefaultColumnType::Any; count],
            rows: output,
        })
    }
}

fn failure(file: &str, line: u32, checks: usize, message: String) -> Value {
    json!({"protocol":1,"file":file,"status":"failed","checks":checks,
        "errors":[{"file":file,"line":line,"message":message}],"output":message})
}

fn failure_at(file: &str, loc: &sqllogictest::Location, checks: usize, message: String) -> Value {
    let mut report = failure(file, loc.line(), checks, message);
    report["errors"][0]["file"] = json!(loc.file());
    report
}

fn execute(file: &str) -> Value {
    let records = match sqllogictest::parse_file::<DefaultColumnType>(file) {
        Ok(records) => records,
        Err(error) => return failure_at(file, &error.location(), 0, error.to_string()),
    };
    // Shell extensions are outside this native SQLite backend. Never silently
    // skip one and report a successful SQL test on a different platform.
    for record in &records {
        if let Record::System { loc, .. } = record {
            return failure_at(
                file,
                loc,
                0,
                "The native SQLite runner does not support SLT system commands".into(),
            );
        }
    }
    let mut runner = Runner::new(|| async {
        // Named SLT connections share this script's DB; the URI cache is
        // process-local. A different script/process receives a fresh DB.
        Connection::open_with_flags(
            "file:forge-sqltest?mode=memory&cache=shared",
            OpenFlags::SQLITE_OPEN_READ_WRITE
                | OpenFlags::SQLITE_OPEN_CREATE
                | OpenFlags::SQLITE_OPEN_URI,
        )
        .map(Sqlite)
    });
    runner.with_column_validator(|actual, expected| actual.len() == expected.len());
    let mut checks = 0;
    for record in records {
        if matches!(record, Record::Halt { .. }) {
            break;
        }
        match runner.run(record) {
            Ok(RecordOutput::Query { .. } | RecordOutput::Statement { .. }) => checks += 1,
            Ok(_) => {}
            Err(error) => {
                return failure_at(
                    file,
                    &error.location(),
                    checks,
                    error.display(false).to_string(),
                );
            }
        }
    }
    if checks == 0 {
        return failure(
            file,
            1,
            0,
            "No SQL assertions executed (empty or skipped script)".into(),
        );
    }
    json!({"protocol":1,"file":file,"status":"passed","checks":checks,"errors":[],
        "output":format!("PASS {file} ({checks} SQL checks)")})
}

fn main() -> ExitCode {
    let mut args = env::args_os().skip(1);
    let mut report_path = None;
    let mut input = None;
    while let Some(arg) = args.next() {
        if arg == "--version" {
            println!(
                "forge-sqltest {} (sqllogictest 0.29.1; SQLite {})",
                env!("CARGO_PKG_VERSION"),
                rusqlite::version()
            );
            return ExitCode::SUCCESS;
        } else if arg == "--report" {
            report_path = args.next().map(PathBuf::from);
            if report_path.is_none() {
                eprintln!("--report requires a JSON path");
                return ExitCode::from(2);
            }
        } else if arg == "--" {
            input = args.next().map(PathBuf::from);
            if args.next().is_some() {
                eprintln!("One .slt script per process");
                return ExitCode::from(2);
            }
            break;
        } else if input.is_none() {
            input = Some(PathBuf::from(arg));
        } else {
            eprintln!("One .slt script per process");
            return ExitCode::from(2);
        }
    }
    let Some(path) = input else {
        eprintln!("Usage: forge-sqltest [--report <json>] -- <script.slt>");
        return ExitCode::from(2);
    };
    let path = if path.is_absolute() {
        path
    } else {
        match env::current_dir() {
            Ok(cwd) => cwd.join(path),
            Err(error) => {
                eprintln!("{error}");
                return ExitCode::from(2);
            }
        }
    };
    let file = path.to_string_lossy();
    let report = match fs::read_to_string(&path) {
        Ok(_) => execute(&file),
        Err(error) => failure(&file, 1, 0, error.to_string()),
    };
    if let Some(target) = report_path {
        if let Err(error) = fs::write(target, serde_json::to_vec_pretty(&report).unwrap()) {
            eprintln!("Cannot write SQL test report: {error}");
            return ExitCode::from(2);
        }
    }
    println!("{}", report["output"].as_str().unwrap());
    if report["status"] == "passed" {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}
