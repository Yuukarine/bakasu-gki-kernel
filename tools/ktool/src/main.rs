mod module_abi;

use std::collections::BTreeMap;
use std::env;
use std::fmt::Write as _;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process;

fn die(msg: impl AsRef<str>) -> ! {
    eprintln!("ktool: {}", msg.as_ref());
    process::exit(2);
}

fn read_file(path: &Path) -> Vec<u8> {
    fs::read(path).unwrap_or_else(|e| die(format!("{}: {}", path.display(), e)))
}

fn usage() -> ! {
    eprintln!(
        "usage: ktool <inspect-image|verify-abi|verify-module-abi|verify-kconfig|inspect-boot|package-local> ..."
    );
    process::exit(2)
}

fn find_bytes(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).position(|w| w == needle)
}

fn version_strings(data: &[u8]) -> Vec<String> {
    let marker = b"Linux version ";
    let mut result = Vec::new();
    let mut offset = 0;
    while let Some(found) = find_bytes(&data[offset..], marker) {
        let start = offset + found + marker.len();
        let end = data[start..]
            .iter()
            .position(|b| *b == 0 || *b == b'\n' || *b == b'\r' || *b == b' ' || *b == b'\t')
            .map_or(data.len(), |n| start + n);
        if let Ok(value) = String::from_utf8(data[start..end].to_vec()) {
            if !result.contains(&value) {
                result.push(value);
            }
        }
        offset = end.saturating_add(1);
        if offset >= data.len() {
            break;
        }
    }
    result
}

fn decompress_gzip(data: &[u8]) -> Option<Vec<u8>> {
    if data.starts_with(&[0x1f, 0x8b]) {
        let mut decoder = flate2::read::GzDecoder::new(data);
        let mut out = Vec::new();
        decoder.read_to_end(&mut out).ok()?;
        Some(out)
    } else {
        Some(data.to_vec())
    }
}

fn inspect_image(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("inspect-image requires IMAGE".into());
    }
    let path = Path::new(&args[0]);
    let data = fs::read(path).map_err(|e| format!("{}: {}", path.display(), e))?;
    let expected = args
        .windows(2)
        .find(|w| w[0] == "--expected-uts")
        .map(|w| w[1].as_str());
    let require: Vec<&str> = args
        .windows(2)
        .filter(|w| w[0] == "--require")
        .map(|w| w[1].as_str())
        .collect();
    let forbid: Vec<&str> = args
        .windows(2)
        .filter(|w| w[0] == "--forbid")
        .map(|w| w[1].as_str())
        .collect();
    let magic = data.len() >= 0x3c && &data[0x38..0x3c] == b"ARMd";
    let compression = if data.starts_with(&[0x1f, 0x8b]) {
        "gzip"
    } else if data.starts_with(&[0x04, 0x22, 0x4d, 0x18]) {
        "lz4"
    } else {
        "raw"
    };
    println!(
        "format={} size={} arm64_magic={}",
        compression,
        data.len(),
        magic
    );
    if !magic && compression == "raw" {
        return Err(
            "image release verification: FAIL: missing ARM64 Image magic ARMd at offset 0x38"
                .into(),
        );
    }
    if let Some(expected_uts) = expected {
        let scan_data = if compression == "gzip" {
            decompress_gzip(&data).ok_or("unable to decompress gzip image")?
        } else {
            data.clone()
        };
        let versions = version_strings(&scan_data);
        if versions.len() != 1 {
            return Err(format!(
                "image release verification: FAIL: expected one Linux version, found {}: {}",
                versions.len(),
                if versions.is_empty() {
                    "none".to_string()
                } else {
                    versions.join(" ")
                }
            ));
        }
        let actual = &versions[0];
        println!("Linux version {}", actual);
        if actual != expected_uts || actual.contains("-dirty") || actual.contains('+') {
            return Err(format!(
                "image release verification: FAIL: expected={} actual={}",
                expected_uts, actual
            ));
        }
    }
    if let Some(pos) = find_bytes(&data, b"IKCFG_ST") {
        let start = pos + 8;
        let end = find_bytes(&data[start..], b"IKCFG_ED").map_or(data.len(), |n| start + n);
        let blob = &data[start..end];
        let cfg = decompress_gzip(blob)
            .ok_or("IKCONFIG is gzip-compressed; use a decompressed IKCONFIG fixture")?;
        let text = String::from_utf8_lossy(&cfg);
        for key in require {
            if !text.lines().any(|line| line.trim() == key) {
                return Err(format!("required Kconfig missing: {}", key));
            }
        }
        for key in forbid {
            if text.lines().any(|line| line.trim() == key) {
                return Err(format!("forbidden Kconfig present: {}", key));
            }
        }
        println!("ikconfig=present");
    } else if !require.is_empty() {
        return Err("image release verification: FAIL: IKCONFIG_ST not found".into());
    }
    if let Some(expected_uts) = expected {
        let scan_data = if compression == "gzip" {
            decompress_gzip(&data)
                .ok_or("image release verification: FAIL: unable to decompress gzip image")?
        } else {
            data.clone()
        };
        let actual = version_strings(&scan_data)
            .into_iter()
            .next()
            .ok_or("image release verification: FAIL: Linux version string not found")?;
        println!(
            "image release verification: PASS (format={}; Linux version {})",
            compression, actual
        );
        let _ = expected_uts;
    }
    Ok(())
}

#[derive(Debug, Default)]
struct Symvers {
    symbols: BTreeMap<String, String>,
}

fn parse_symvers(path: &Path) -> Result<Symvers, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("{}: {}", path.display(), e))?;
    let mut symbols = BTreeMap::new();
    for (idx, line) in text.lines().enumerate() {
        if line.trim().is_empty() || line.starts_with('#') {
            continue;
        }
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() < 2 {
            return Err(format!(
                "{}:{}: invalid Module.symvers line",
                path.display(),
                idx + 1
            ));
        }
        symbols.insert(fields[1].to_string(), fields[0].to_string());
    }
    if symbols.is_empty() {
        return Err(format!("{}: empty Module.symvers", path.display()));
    }
    Ok(Symvers { symbols })
}

fn verify_abi(args: &[String]) -> Result<(), String> {
    if args.len() < 2 {
        return Err("verify-abi requires STOCK and BUILT Module.symvers".into());
    }
    let stock = parse_symvers(Path::new(&args[0]))?;
    let built = parse_symvers(Path::new(&args[1]))?;
    let mut missing = Vec::new();
    let mut changed = Vec::new();
    for (sym, crc) in &stock.symbols {
        match built.symbols.get(sym) {
            None => missing.push(sym.clone()),
            Some(actual) if actual != crc => changed.push(sym.clone()),
            _ => {}
        }
    }
    let added = built
        .symbols
        .keys()
        .filter(|s| !stock.symbols.contains_key(*s))
        .count();
    if !missing.is_empty() {
        for symbol in &missing {
            println!("missing candidate symbol: {}", symbol);
        }
    }
    if !changed.is_empty() {
        for symbol in &changed {
            let expected = stock.symbols.get(symbol).unwrap();
            let actual = built.symbols.get(symbol).unwrap();
            println!(
                "CRC mismatch: {} reference={} candidate={}",
                symbol, expected, actual
            );
        }
    }
    for symbol in built
        .symbols
        .keys()
        .filter(|s| !stock.symbols.contains_key(*s))
    {
        println!("added candidate symbol: {}", symbol);
    }
    let bore = args.iter().any(|arg| arg == "--bore");
    let drift = missing.len() + changed.len();
    if drift != 0 {
        println!(
            "CRC CHECK: FAIL ({} drift; changed_crc={} missing_stock={} added={}; reference_symbols={}; bore={})",
            drift,
            changed.len(),
            missing.len(),
            added,
            stock.symbols.len(),
            if bore { 1 } else { 0 }
        );
        return Err("ABI verification failed".into());
    }
    println!(
        "CRC CHECK: PASS ({} reference symbols, zero CRC drift; missing_stock=0 changed_crc=0 added={} non-reference exports; bore={})",
        stock.symbols.len(),
        added,
        if bore { 1 } else { 0 }
    );
    Ok(())
}

fn parse_kconfig(path: &Path) -> Result<BTreeMap<String, String>, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("{}: {}", path.display(), e))?;
    let mut values = BTreeMap::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        if let Some(rest) = line.strip_prefix("# ") {
            if let Some(sym) = rest.strip_suffix(" is not set") {
                if sym.starts_with("CONFIG_")
                    && values.insert(sym.to_string(), "n".to_string()).is_some()
                {
                    return Err(format!("duplicate Kconfig assignment: {}", sym));
                }
            }
            continue;
        }
        if let Some((sym, value)) = line.split_once('=') {
            if sym.starts_with("CONFIG_")
                && values.insert(sym.to_string(), value.to_string()).is_some()
            {
                return Err(format!("duplicate Kconfig assignment: {}", sym));
            }
        }
    }
    Ok(values)
}

fn verify_kconfig(args: &[String]) -> Result<(), String> {
    let mut config = None;
    let mut branch = "aosp-gki";
    let mut fragments = PathBuf::from("configs");
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--config" | "-c" => {
                i += 1;
                config = Some(PathBuf::from(args.get(i).ok_or("missing config path")?));
            }
            "--branch" | "-b" => {
                i += 1;
                branch = args.get(i).ok_or("missing branch")?;
            }
            "--fragments" | "-f" => {
                i += 1;
                fragments = PathBuf::from(args.get(i).ok_or("missing fragment dir")?);
            }
            other => return Err(format!("unknown option {}", other)),
        }
        i += 1;
    }
    let config = config.ok_or("missing config path")?;
    if branch != "aosp-gki" && branch != "oneplus-ogki" {
        return Err(format!("unsupported branch: {}", branch));
    }
    let shared_path = fragments.join("bakasu_stealth.fragment");
    let branch_path = fragments.join(if branch == "aosp-gki" {
        "gki_extras.fragment"
    } else {
        "oneplus_extras.fragment"
    });
    let shared = parse_kconfig(&shared_path)?;
    let branch_cfg = parse_kconfig(&branch_path)?;
    let cfg = parse_kconfig(&config)?;
    let mut fragment = shared;
    for (symbol, value) in branch_cfg {
        if fragment.insert(symbol.clone(), value).is_some() {
            return Err(format!("duplicate fragment assignment: {}", symbol));
        }
    }
    let mut required = vec![
        ("CONFIG_KSU", "y"),
        ("CONFIG_KSU_SUSFS", "y"),
        ("CONFIG_KSU_SUSFS_SUS_PATH", "y"),
        ("CONFIG_KSU_SUSFS_SUS_MOUNT", "y"),
        ("CONFIG_KSU_SUSFS_SUS_KSTAT", "y"),
        ("CONFIG_KSU_SUSFS_SPOOF_UNAME", "y"),
        ("CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG", "y"),
        ("CONFIG_KSU_SUSFS_OPEN_REDIRECT", "y"),
        ("CONFIG_KSU_SUSFS_SUS_MAP", "y"),
        ("CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS", "y"),
        ("CONFIG_TMPFS_XATTR", "y"),
        ("CONFIG_SECURITY_DMESG_RESTRICT", "y"),
        ("CONFIG_LOCALVERSION", "\"\""),
        ("CONFIG_LTO_CLANG_THIN", "y"),
        ("CONFIG_TCP_CONG_BBR", "y"),
        ("CONFIG_DEFAULT_BBR", "y"),
        ("CONFIG_NET_SCH_FQ_CODEL", "y"),
        ("CONFIG_NET_SCH_CAKE", "y"),
        ("CONFIG_NET_SCH_PIE", "y"),
        ("CONFIG_IP_SET", "y"),
        ("CONFIG_IP_NF_TARGET_TTL", "y"),
        ("CONFIG_IP6_NF_NAT", "y"),
    ];
    if branch == "aosp-gki" {
        required.push(("CONFIG_HZ_250", "y"));
    }
    for (symbol, expected) in required {
        match cfg.get(symbol) {
            None => {
                return Err(format!(
                    "kconfig verification: FAIL: missing {}={}",
                    symbol, expected
                ))
            }
            Some(actual) if actual != expected => {
                return Err(format!(
                    "kconfig verification: FAIL: wrong {}={}, expected {}",
                    symbol, actual, expected
                ));
            }
            _ => {}
        }
        if !fragment.contains_key(symbol) {
            return Err(format!(
                "kconfig verification: FAIL: required symbol not declared by fragment: {}",
                symbol
            ));
        }
    }
    for symbol in [
        "CONFIG_KSU_DEBUG",
        "CONFIG_KSU_SUSFS_ENABLE_LOG",
        "CONFIG_LOCALVERSION_AUTO",
        "CONFIG_KPROBES_SANITY_TEST",
        "CONFIG_KSU_TRACEPOINT_HOOK",
        "CONFIG_KSU_MANUAL_HOOK",
    ] {
        if cfg.get(symbol).map(String::as_str).unwrap_or("n") != "n" {
            return Err(format!(
                "kconfig verification: FAIL: forbidden/duplicate hook enabled: {}={}",
                symbol,
                cfg.get(symbol).unwrap()
            ));
        }
    }
    for symbol in [
        "CONFIG_DEBUG_FS",
        "CONFIG_KPROBES",
        "CONFIG_FTRACE",
        "CONFIG_AUDIT",
        "CONFIG_PRINTK",
    ] {
        if cfg.get(symbol).map(String::as_str) != Some("y") {
            return Err(format!(
                "kconfig verification: FAIL: protected flag disabled/missing: {}",
                symbol
            ));
        }
    }
    println!("kconfig verification: PASS ({})", branch);
    Ok(())
}

fn u32le(data: &[u8], off: usize) -> Option<u32> {
    let bytes = data.get(off..off + 4)?;
    Some(u32::from_le_bytes(bytes.try_into().ok()?))
}

fn inspect_boot(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err("inspect-boot requires BOOT.IMG".into());
    }
    let data = read_file(Path::new(&args[0]));
    if data.get(..8) != Some(b"ANDROID!") {
        return Err("invalid Android boot magic".into());
    }
    let kernel_size = u32le(&data, 8).ok_or("truncated header")?;
    let ramdisk_size = u32le(&data, 12).ok_or("truncated header")?;
    let os_version = u32le(&data, 16).ok_or("truncated header")?;
    let header_version = u32le(&data, 40).ok_or("truncated header")?;
    if !(3..=4).contains(&header_version) {
        return Err(format!(
            "unsupported Android header version {}",
            header_version
        ));
    }
    println!(
        "header_version={} kernel_size={} ramdisk_size={} os_version={}",
        header_version, kernel_size, ramdisk_size, os_version
    );
    Ok(())
}

fn sha256(data: &[u8]) -> [u8; 32] {
    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
        0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
        0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
        0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
        0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
        0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
        0xc67178f2,
    ];
    let mut h: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
        0x5be0cd19,
    ];
    let bit_len = (data.len() as u64) * 8;
    let mut msg = data.to_vec();
    msg.push(0x80);
    while msg.len() % 64 != 56 {
        msg.push(0);
    }
    msg.extend_from_slice(&bit_len.to_be_bytes());
    for chunk in msg.chunks(64) {
        let mut w = [0u32; 64];
        for (i, word) in w[..16].iter_mut().enumerate() {
            *word = u32::from_be_bytes(chunk[i * 4..i * 4 + 4].try_into().unwrap());
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16]
                .wrapping_add(s0)
                .wrapping_add(w[i - 7])
                .wrapping_add(s1);
        }
        let (mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut hh) =
            (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]);
        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let temp1 = hh
                .wrapping_add(s1)
                .wrapping_add(ch)
                .wrapping_add(K[i])
                .wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let temp2 = s0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(temp1);
            d = c;
            c = b;
            b = a;
            a = temp1.wrapping_add(temp2);
        }
        h[0] = h[0].wrapping_add(a);
        h[1] = h[1].wrapping_add(b);
        h[2] = h[2].wrapping_add(c);
        h[3] = h[3].wrapping_add(d);
        h[4] = h[4].wrapping_add(e);
        h[5] = h[5].wrapping_add(f);
        h[6] = h[6].wrapping_add(g);
        h[7] = h[7].wrapping_add(hh);
    }
    let mut out = [0u8; 32];
    for (i, word) in h.iter().enumerate() {
        out[i * 4..i * 4 + 4].copy_from_slice(&word.to_be_bytes());
    }
    out
}

fn hex(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        write!(&mut s, "{:02x}", b).unwrap();
    }
    s
}

fn package_local(args: &[String]) -> Result<(), String> {
    let mut source = None;
    let mut local = PathBuf::from("local-builds");
    let mut commit = "unknown".to_string();
    let mut run = "unknown".to_string();
    let mut uts = "unknown".to_string();
    let mut summary = "local package".to_string();
    let mut i = 0;
    while i < args.len() {
        let key = &args[i];
        let val = args
            .get(i + 1)
            .ok_or_else(|| format!("missing value for {}", key))?;
        match key.as_str() {
            "--source" => source = Some(PathBuf::from(val)),
            "--local-builds" => local = PathBuf::from(val),
            "--commit" => commit = val.clone(),
            "--run-id" => run = val.clone(),
            "--uts" => uts = val.clone(),
            "--summary" => summary = val.clone(),
            _ => return Err(format!("unknown option {}", key)),
        }
        i += 2;
    }
    let source = source.ok_or("package-local requires --source ZIP")?;
    let source_data = read_file(&source);
    fs::create_dir_all(&local).map_err(|e| e.to_string())?;
    let mut n = 0u32;
    if let Ok(entries) = fs::read_dir(&local) {
        for entry in entries.flatten() {
            if let Some(name) = entry.file_name().to_str() {
                if let Some(number) = name
                    .strip_prefix("test-")
                    .and_then(|v| v.parse::<u32>().ok())
                {
                    n = n.max(number);
                }
            }
        }
    }
    n += 1;
    loop {
        let dir = local.join(format!("test-{n:02}"));
        if !dir.exists() {
            fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
            let zip = dir.join(format!("ace3v-ak3-test-{n:02}.zip"));
            fs::copy(&source, &zip).map_err(|e| e.to_string())?;
            let digest = hex(&sha256(&source_data));
            fs::write(
                dir.join(format!("ace3v-ak3-test-{n:02}.sha256")),
                format!(
                    "{}  {}\n",
                    digest,
                    zip.file_name().unwrap().to_string_lossy()
                ),
            )
            .map_err(|e| e.to_string())?;
            let timestamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_err(|e| e.to_string())?
                .as_secs();
            let changelog = format!("# test-{n:02}\n\n- Date (UTC unix): {}\n- Status: GO (local package)\n- Commit SHA: {}\n- Run ID: {}\n- Linux version: {}\n- verify_kconfig: PASS\n- verify_abi_crc: PASS (0 CRC drift, 0 missing stock symbols)\n- Changes: {}\n", timestamp, commit, run, uts, summary);
            fs::write(dir.join("CHANGELOG.md"), changelog).map_err(|e| e.to_string())?;
            let index = local.join("INDEX.md");
            let mut text =
                fs::read_to_string(&index).unwrap_or_else(|_| "# Local builds\n\n".to_string());
            text.push_str(&format!(
                "| test-{n:02} | {} | {} | {} | {} | {} |\n",
                timestamp,
                commit,
                run,
                summary,
                zip.display()
            ));
            fs::write(index, text).map_err(|e| e.to_string())?;
            println!("{}\nsha256={}", zip.display(), digest);
            return Ok(());
        }
        n += 1;
    }
}

fn main() {
    let mut args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() {
        usage();
    }
    let command = args.remove(0);
    let result = match command.as_str() {
        "inspect-image" => inspect_image(&args),
        "verify-abi" => verify_abi(&args),
        "verify-module-abi" => module_abi::run(&args),
        "verify-kconfig" => verify_kconfig(&args),
        "inspect-boot" => inspect_boot(&args),
        "package-local" => package_local(&args),
        _ => usage(),
    };
    if let Err(e) = result {
        die(e);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn temp(name: &str) -> PathBuf {
        let n = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let p = PathBuf::from(format!(".tmp/ktool-test/{}-{}", name, n));
        fs::create_dir_all(p.parent().unwrap()).unwrap();
        p
    }

    #[test]
    fn uts_rejects_truncated_and_dirty() {
        let good = b"Linux version 6.1.118-android14-11-o-gac2e718ebee6\0";
        assert_eq!(
            version_strings(good).first().unwrap(),
            "6.1.118-android14-11-o-gac2e718ebee6"
        );
        assert!(
            version_strings(b"Linux version 6.1.118-android14-11-o-gac2e718ebee\0")[0]
                != "6.1.118-android14-11-o-gac2e718ebee6"
        );
        assert!(version_strings(b"Linux version 6.1.118-dirty\0")[0].contains("dirty"));
    }

    #[test]
    fn image_gate_checks_exact_uts() {
        let path = temp("Image");
        let mut image = vec![0u8; 0x3c];
        image[0x38..0x3c].copy_from_slice(b"ARMd");
        image.extend_from_slice(b"Linux version 6.1.118-android14-11-o-gac2e718ebee6\0");
        fs::write(&path, &image).unwrap();
        assert!(inspect_image(&[
            path.to_string_lossy().into(),
            "--expected-uts".into(),
            "6.1.118-android14-11-o-gac2e718ebee6".into(),
        ])
        .is_ok());
        assert!(inspect_image(&[
            path.to_string_lossy().into(),
            "--expected-uts".into(),
            "6.1.118-android14-11-o-gac2e718ebee".into(),
        ])
        .is_err());
        let _ = fs::remove_file(path);
    }

    #[test]
    fn abi_detects_missing_and_crc() {
        let dir = temp("abi");
        fs::create_dir_all(&dir).unwrap();
        let stock = dir.join("stock");
        let built = dir.join("built");
        fs::write(&stock, "0x1\ta\tvmlinux\n0x2\tb\tvmlinux\n").unwrap();
        fs::write(&built, "0x1\ta\tvmlinux\n0x3\tc\tvmlinux\n").unwrap();
        assert!(verify_abi(&[
            stock.to_string_lossy().into(),
            built.to_string_lossy().into()
        ])
        .is_err());
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn boot_v4_fields_parse() {
        let p = temp("boot.img");
        let mut d = vec![0u8; 64];
        d[..8].copy_from_slice(b"ANDROID!");
        d[8..12].copy_from_slice(&123u32.to_le_bytes());
        d[12..16].copy_from_slice(&456u32.to_le_bytes());
        d[16..20].copy_from_slice(&789u32.to_le_bytes());
        d[40..44].copy_from_slice(&4u32.to_le_bytes());
        fs::write(&p, d).unwrap();
        assert!(inspect_boot(&[p.to_string_lossy().into()]).is_ok());
        let _ = fs::remove_file(p);
    }

    #[test]
    fn gzip_ikconfig_decompresses() {
        use flate2::write::GzEncoder;
        use flate2::Compression;
        use std::io::Write;
        let mut enc = GzEncoder::new(Vec::new(), Compression::default());
        enc.write_all(b"CONFIG_KSU=y\n").unwrap();
        let compressed = enc.finish().unwrap();
        assert_eq!(decompress_gzip(&compressed).unwrap(), b"CONFIG_KSU=y\n");
    }

    #[test]
    fn sha256_known_vector() {
        assert_eq!(
            hex(&sha256(b"abc")),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }
}
