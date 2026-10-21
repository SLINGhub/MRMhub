fn main() {
    // Embed the checked-out QUANT package, not whichever mrmhub happens to be
    // installed on the user's machine. Also works in cross-compiled installers.
    use std::{
        collections::hash_map::DefaultHasher,
        fs,
        hash::{Hash, Hasher},
        path::Path,
    };
    fn collect(root: &Path, dir: &Path, files: &mut Vec<std::path::PathBuf>) {
        for entry in fs::read_dir(dir).expect("read QUANT source") {
            let path = entry.unwrap().path();
            if path.is_dir() {
                collect(root, &path, files);
            } else {
                files.push(path.strip_prefix(root).unwrap().to_owned());
            }
        }
    }
    let root = Path::new("../../..").canonicalize().unwrap();
    let mut files = vec!["DESCRIPTION".into(), "NAMESPACE".into()];
    for folder in ["R", "data", "inst/extdata"] {
        // File-only watches miss newly added package source/data files. Watch
        // each collected directory as well so Cargo rebuilds the embedded copy.
        println!("cargo:rerun-if-changed={}", root.join(folder).display());
        collect(&root, &root.join(folder), &mut files);
    }
    files.sort();
    let mut hash = DefaultHasher::new();
    let mut code = String::from("const PACKAGE_FILES: &[(&str, &[u8])] = &[\n");
    for file in files {
        let path = root.join(&file);
        println!("cargo:rerun-if-changed={}", path.display());
        file.hash(&mut hash);
        fs::read(&path).unwrap().hash(&mut hash);
        code.push_str(&format!(
            "({:?}, include_bytes!({:?})),\n",
            file.to_str().unwrap().replace('\\', "/"),
            path
        ));
    }
    code.push_str(&format!(
        "];\nconst PACKAGE_ID: &str = \"{:016x}\";\n",
        hash.finish()
    ));
    fs::write(
        Path::new(&std::env::var("OUT_DIR").unwrap()).join("quant_source.rs"),
        code,
    )
    .unwrap();
    tauri_build::build();
}
