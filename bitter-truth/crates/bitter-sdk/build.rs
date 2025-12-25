use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .join("proto");

    println!("cargo:rerun-if-changed={}", proto_root.display());

    prost_build::Config::new()
        .out_dir("src/gen")
        .compile_protos(
            &[
                proto_root.join("bitter/common.proto"),
                proto_root.join("bitter/tools/echo.proto"),
            ],
            &[&proto_root],
        )?;

    Ok(())
}
