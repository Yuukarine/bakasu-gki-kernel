//! Check actual ROM module imports against explicit provider exports and built vmlinux.
//! Import CRCs are requirements only: they never establish that a provider exports a symbol.
use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

type Exports = BTreeMap<(String, String), u32>;

#[derive(Debug)]
struct Import {
    consumer: String,
    symbol: String,
    crc: u32,
    provider: String,
}

fn crc(value: &str) -> Result<u32, String> {
    let hex = value
        .strip_prefix("0x")
        .or_else(|| value.strip_prefix("0X"))
        .unwrap_or(value);
    if hex.is_empty() || hex.len() > 8 || !hex.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err(format!("invalid 32-bit CRC: {value}"));
    }
    u32::from_str_radix(hex, 16).map_err(|e| e.to_string())
}

fn identifier(value: &str) -> bool {
    !value.is_empty()
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"_.+-".contains(&b))
}

fn lines(text: &str) -> impl Iterator<Item = (usize, Vec<&str>)> {
    text.lines().enumerate().filter_map(|(index, line)| {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            None
        } else {
            Some((index + 1, line.split_whitespace().collect()))
        }
    })
}

fn parse_imports(text: &str) -> Result<Vec<Import>, String> {
    let mut imports = Vec::new();
    let mut seen = BTreeSet::new();
    for (line, fields) in lines(text) {
        if fields.len() != 4
            || !identifier(fields[0])
            || !identifier(fields[1])
            || !identifier(fields[3])
        {
            return Err(format!(
                "imports:{line}: expected consumer symbol crc provider"
            ));
        }
        if !seen.insert((fields[0], fields[1])) {
            return Err(format!(
                "imports:{line}: duplicate/conflicting import {} {}",
                fields[0], fields[1]
            ));
        }
        imports.push(Import {
            consumer: fields[0].into(),
            symbol: fields[1].into(),
            crc: crc(fields[2]).map_err(|e| format!("imports:{line}: {e}"))?,
            provider: fields[3].into(),
        });
    }
    if imports.is_empty() {
        return Err("imports: empty module requirements".into());
    }
    Ok(imports)
}

fn parse_exports(text: &str) -> Result<Exports, String> {
    let mut exports = BTreeMap::new();
    for (line, fields) in lines(text) {
        if fields.len() != 3 || !identifier(fields[0]) || !identifier(fields[1]) {
            return Err(format!("exports:{line}: expected provider symbol crc"));
        }
        if fields[0] == "vmlinux" || fields[0] == "unresolved" {
            return Err(format!(
                "exports:{line}: provider {} must not be supplied as module export evidence",
                fields[0]
            ));
        }
        let key = (fields[0].to_owned(), fields[1].to_owned());
        if exports
            .insert(
                key,
                crc(fields[2]).map_err(|e| format!("exports:{line}: {e}"))?,
            )
            .is_some()
        {
            return Err(format!(
                "exports:{line}: duplicate/conflicting export {} {}",
                fields[0], fields[1]
            ));
        }
    }
    Ok(exports)
}

fn parse_modules(text: &str) -> Result<BTreeSet<String>, String> {
    let mut modules = BTreeSet::new();
    for (line, fields) in lines(text) {
        if fields.len() != 1
            || !identifier(fields[0])
            || matches!(fields[0], "vmlinux" | "unresolved")
        {
            return Err(format!("modules:{line}: expected one module identifier"));
        }
        if !modules.insert(fields[0].into()) {
            return Err(format!("modules:{line}: duplicate module {}", fields[0]));
        }
    }
    if modules.is_empty() {
        return Err("modules: empty module inventory".into());
    }
    Ok(modules)
}

fn parse_kernel(text: &str) -> Result<BTreeMap<String, u32>, String> {
    let mut symbols = BTreeMap::new();
    let mut seen = BTreeSet::new();
    for (line, fields) in lines(text) {
        if !(3..=5).contains(&fields.len()) || !identifier(fields[1]) {
            return Err(format!("kernel:{line}: invalid Module.symvers row"));
        }
        let value = crc(fields[0]).map_err(|e| format!("kernel:{line}: {e}"))?;
        if !seen.insert(fields[1]) {
            return Err(format!(
                "kernel:{line}: duplicate/conflicting symbol {}",
                fields[1]
            ));
        }
        if fields[2] == "vmlinux" {
            symbols.insert(fields[1].into(), value);
        }
    }
    if symbols.is_empty() {
        return Err("kernel: no vmlinux exports in Module.symvers".into());
    }
    Ok(symbols)
}

#[derive(Default, Debug, PartialEq)]
struct Counts {
    imports: usize,
    missing_provider: usize,
    missing_symbol: usize,
    changed_crc: usize,
}

fn check(
    imports: &[Import],
    exports: &Exports,
    kernel: &BTreeMap<String, u32>,
    modules: &BTreeSet<String>,
) -> (BTreeMap<String, Counts>, Vec<String>) {
    let mut counts = BTreeMap::<String, Counts>::new();
    let mut details = Vec::new();
    for import in imports {
        let count = counts.entry(import.consumer.clone()).or_default();
        count.imports += 1;
        if !modules.contains(&import.consumer) {
            count.missing_provider += 1;
            details.push(format!(
                "missing_provider: consumer={} provider={} symbol={} reason=consumer-not-in-inventory",
                import.consumer, import.consumer, import.symbol
            ));
            continue;
        }
        let actual = if import.provider == "vmlinux" {
            kernel.get(&import.symbol)
        } else {
            if import.provider == "unresolved" || !modules.contains(&import.provider) {
                count.missing_provider += 1;
                details.push(format!(
                    "missing_provider: consumer={} provider={} symbol={}",
                    import.consumer, import.provider, import.symbol
                ));
                continue;
            }
            exports.get(&(import.provider.clone(), import.symbol.clone()))
        };
        match actual {
            None => {
                count.missing_symbol += 1;
                details.push(format!(
                    "missing_symbol: consumer={} provider={} symbol={}",
                    import.consumer, import.provider, import.symbol
                ));
            }
            Some(value) if *value != import.crc => {
                count.changed_crc += 1;
                details.push(format!(
                    "changed_crc: consumer={} provider={} symbol={} expected=0x{:08x} actual=0x{:08x}",
                    import.consumer, import.provider, import.symbol, import.crc, value
                ));
            }
            _ => {}
        }
    }
    (counts, details)
}

pub fn run(args: &[String]) -> Result<(), String> {
    let mut options = BTreeMap::new();
    for pair in args.chunks(2) {
        if pair.len() != 2
            || !matches!(
                pair[0].as_str(),
                "--imports" | "--exports" | "--kernel" | "--modules"
            )
            || options.insert(pair[0].as_str(), pair[1].as_str()).is_some()
        {
            return Err("verify-module-abi requires --imports FILE --exports FILE --kernel FILE --modules FILE (no duplicate options)".into());
        }
    }
    let read = |option| -> Result<String, String> {
        let path = options.get(option).ok_or(format!("missing {option}"))?;
        fs::read_to_string(Path::new(path)).map_err(|e| format!("{path}: {e}"))
    };
    let imports = parse_imports(&read("--imports")?)?;
    let exports = parse_exports(&read("--exports")?)?;
    let kernel = parse_kernel(&read("--kernel")?)?;
    let modules = parse_modules(&read("--modules")?)?;
    let (counts, details) = check(&imports, &exports, &kernel, &modules);
    for detail in details {
        println!("{detail}");
    }
    let mut total = Counts::default();
    for (consumer, count) in &counts {
        println!(
            "module={} imports={} missing_provider={} missing_symbol={} changed_crc={}",
            consumer,
            count.imports,
            count.missing_provider,
            count.missing_symbol,
            count.changed_crc
        );
        total.imports += count.imports;
        total.missing_provider += count.missing_provider;
        total.missing_symbol += count.missing_symbol;
        total.changed_crc += count.changed_crc;
    }
    let ok = total.missing_provider == 0 && total.missing_symbol == 0 && total.changed_crc == 0;
    println!(
        "MODULE ABI CHECK: {} (imports={} modules={} missing_provider={} missing_symbol={} changed_crc={})",
        if ok { "PASS" } else { "FAIL" }, total.imports, counts.len(), total.missing_provider, total.missing_symbol, total.changed_crc
    );
    if ok {
        Ok(())
    } else {
        Err("ROM module ABI requirements not satisfied".into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn crc_normalizes_and_rejects_invalid() {
        assert_eq!(crc("0Xabcd"), crc("0x0000ABCD"));
        for bad in ["0x", "not-crc", "0x100000000", "-1"] {
            assert!(crc(bad).is_err());
        }
    }

    #[test]
    fn malformed_duplicates_and_conflicts_fail() {
        assert!(parse_imports("wifi.ko foo 0x1 vmlinux\nwifi.ko foo 0x1 vmlinux").is_err());
        assert!(parse_exports("provider.ko foo 0x1\nprovider.ko foo 0x2").is_err());
        assert!(parse_exports("vmlinux foo 0x1").is_err());
        assert!(parse_imports("wifi.ko foo 0x1").is_err());
        assert!(parse_modules("wifi.ko\nwifi.ko").is_err());
        assert!(parse_kernel("0x1 foo vmlinux\n0x1 foo vmlinux").is_err());
    }

    #[test]
    fn real_provider_evidence_is_required() {
        let imports =
            parse_imports("wifi.ko kernel_api 0x1 vmlinux\nwifi.ko wireless_api 0x2 cfg80211.ko")
                .unwrap();
        let exports = parse_exports("cfg80211.ko wireless_api 0x2").unwrap();
        let kernel = parse_kernel("0x1 kernel_api vmlinux EXPORT_SYMBOL").unwrap();
        let modules = parse_modules("wifi.ko\ncfg80211.ko").unwrap();
        let (counts, _) = check(&imports, &exports, &kernel, &modules);
        assert_eq!(
            counts["wifi.ko"],
            Counts {
                imports: 2,
                ..Counts::default()
            }
        );
        let (counts, _) = check(&imports, &Exports::new(), &kernel, &modules);
        assert_eq!(counts["wifi.ko"].missing_symbol, 1);
        let missing = parse_modules("wifi.ko").unwrap();
        let (counts, _) = check(&imports, &exports, &kernel, &missing);
        assert_eq!(counts["wifi.ko"].missing_provider, 1);
        let drifted = parse_exports("cfg80211.ko wireless_api 0x3").unwrap();
        let (counts, _) = check(&imports, &drifted, &kernel, &modules);
        assert_eq!(counts["wifi.ko"].changed_crc, 1);
    }

    #[test]
    fn unresolved_provider_fails_instead_of_guessing() {
        let imports = parse_imports("wifi.ko foo 0x1 unresolved").unwrap();
        let kernel = parse_kernel("0x1 foo vmlinux").unwrap();
        let modules = parse_modules("wifi.ko").unwrap();
        let (counts, _) = check(&imports, &Exports::new(), &kernel, &modules);
        assert_eq!(counts["wifi.ko"].missing_provider, 1);
    }
}
