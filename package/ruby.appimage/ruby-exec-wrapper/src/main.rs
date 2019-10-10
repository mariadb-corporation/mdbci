mod ext_process;

use nix::unistd;
use std::ffi::{CString};
use std::env;
use exitcode;

fn main() {
    let ruby_executable = ext_process::get_executable_path();
    if ruby_executable.is_err() {
        eprintln!("Could not find the Ruby executable with error: {}",
                  ruby_executable.err().unwrap());
        std::process::exit(exitcode::IOERR);
    }
    let ruby_executable = ruby_executable.unwrap();
    let environment = ext_process::create_new_environment();
    let args: Vec<CString> = env::args().map( |argument| {
        CString::new(argument).unwrap()
    }).collect();
    let execution_result = unistd::execve(&ruby_executable, &args, &environment);
    match execution_result {
        Err(error) => {
            eprintln!("Could not start the program with error: {}", error);
            std::process::exit(exitcode::IOERR);
        },
        _ => eprintln!("Should not see this printed at all")
    }
}
