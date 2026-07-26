// Windows-only: embed a VERSIONINFO resource (company, description, product name,
// copyright, and — via winresource's defaults — the crate version from
// CARGO_PKG_VERSION) into the .exe. Giving an unsigned binary real publisher and
// version metadata reduces SmartScreen / antivirus false positives.
//
// The `#[cfg(windows)]` block is compiled out on macOS and Linux, so `winresource`
// is never referenced there — it is only pulled in as a build-dependency for the
// windows target (see Cargo.toml), and no native tooling is needed elsewhere.
// INTEGRATOR is built natively per OS (one CI runner each), so host == target and
// the host `cfg(windows)` gate matches the intended windows target.
fn main() {
    #[cfg(windows)]
    {
        winresource::WindowsResource::new()
            .set("CompanyName", "National University of Singapore")
            .set("FileDescription", "MRMhub INTEGRATOR — targeted MRM peak integration")
            .set("ProductName", "MRMhub INTEGRATOR")
            .set("OriginalFilename", "MRMhub.exe")
            .set(
                "LegalCopyright",
                "© National University of Singapore. Author: Guo Shou Teo.",
            )
            .compile()
            .unwrap();
    }
}
