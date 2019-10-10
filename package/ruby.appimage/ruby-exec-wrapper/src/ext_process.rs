use std::{
    collections::HashMap,
    env,
    ffi::CString,
};
use std::borrow::Borrow;
use std::path::PathBuf;
use std::io::{
    Error,
    ErrorKind,
    Result
};

pub fn get_executable_path() -> Result<CString> {
    let current_exe = env::current_exe().expect("Failed to get path to current executable");
    let exe_directory = current_exe.parent();
    if exe_directory.is_none() {
        return Err(Error::new(ErrorKind::NotFound,
                              "Cannot get the wrapper directory"));
    }
    let ruby_executable = exe_directory.unwrap().join("ruby");
    if ruby_executable.exists() {
        Ok(CString::new(ruby_executable.to_str().unwrap())
            .expect("Path to Ruby executable contains invalid characters"))
    } else {
        Err(Error::new(ErrorKind::NotFound,
                       format!("Ruby executable not found in {}",
                               ruby_executable.to_str().unwrap())))
    }
}

pub fn create_new_environment() -> Vec<CString> {
    let mut environment = Environment {
        env: copy_environment(),
        root_dir: get_appimage_directory()
    };
    patch_variables(&mut environment);
    disable_python_cache(&mut environment);
    identify_as_appimage(&mut environment);
    specify_ssl_cert_file(&mut environment);
    convert_environment_to_cstrings(&environment)
}

struct Environment {
    env: HashMap<String, String>,
    root_dir: String,
}

const OS_ENV_PREFIX: &str = "OS_ENV_";
const BLACKLISTED_ENVS: [&str; 3]= ["GEM_PATH", "GEM_HOME", "GEM_ROOT"];

fn copy_environment() -> HashMap<String, String> {
    let mut environment = HashMap::new();
    for(key, value) in env::vars() {
        let os_key = format!("{}{}", OS_ENV_PREFIX, key);
        environment.insert(os_key, String::from(&value));
        if BLACKLISTED_ENVS.contains(&key.borrow()) {
            continue;
        }
        environment.insert(key, value);
    }
    environment
}

fn get_appimage_directory() -> String {
    let current_exe = env::current_exe().expect("Failed to get path to current executable");
    let parent_path = current_exe.parent().and_then( |path| {
        path.parent()
    }).and_then( |path| {
        path.parent()
    }).expect("Failed to get the location of the AppImage");
    let mut path = String::new();
    path.push_str(parent_path.to_str().unwrap());
    return path;
}

fn patch_variables(environment: &mut Environment) {
    patch_variable("PATH", vec!["/usr/bin"], environment);
    patch_variable("LD_LIBRARY_PATH", vec!["/usr/lib", "/usr/lib/x86_64-linux-gnu",
                                           "/usr/lib64"], environment);
    patch_variable("PYTHONPATH", vec!["/usr/share/pyshared"], environment);
    patch_variable("XDG_DATA_DIRS", vec!["/usr/share"], environment);
    patch_variable("PERLLIB", vec!["/usr/share/perl5", "/usr/lib/perl5"],
                   environment);
    // http://askubuntu.com/questions/251712/how-can-i-install-a-gsettings-schema-without-root-privileges
    patch_variable("GSETTINGS_SCHEMA_DIR", vec!["/usr/share/glib-2.0/schemas/"],
                   environment);
    patch_variable("QT_PLUGIN_PATH", vec![], environment);
}

fn patch_variable(variable: &str, paths: Vec<&str>, environment: &mut Environment) {
    let mut printed_paths: Vec<String> = paths.into_iter().map(|path| {
        format!("{root_dir}{path}", root_dir = environment.root_dir, path = path)
    }).collect();
    let cur_value = environment.env.get(variable);
    if cur_value.is_some() {
        printed_paths.push(cur_value.unwrap().to_string());
    }
    environment.env.insert(variable.to_string(), printed_paths.join(":"));
}

fn disable_python_cache(environment: &mut Environment) {
    environment.env.insert(String::from("PYTHONDONTWRITEBYTECODE"), String::from("1"));
}

fn identify_as_appimage(environment: &mut Environment) {
    environment.env.insert(String::from("APPIMAGE"), String::from("1"));
}

fn specify_ssl_cert_file(environment: &mut Environment) {
    let ssl_cert_file = String::from("SSL_CERT_FILE");
    if environment.env.contains_key(&ssl_cert_file) {
        return;
    }
    let ssl_file_path: PathBuf = [&environment.root_dir, "cacert.pem"].iter().collect();
    if ssl_file_path.exists() {
        environment.env.insert(ssl_cert_file, ssl_file_path.to_str().unwrap().to_string());
    }
}

fn convert_environment_to_cstrings(environment: &Environment) -> Vec<CString> {
    let mut result = Vec::new();
    for (key, value) in &environment.env {
        let new_env = format!("{}={}", key, value);
        result.push(CString::new(new_env).unwrap());
    }
    result
}
