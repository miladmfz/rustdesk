use std::{
    fs::{self},
    io::{Cursor, Read},
    path::Path,
};

#[cfg(windows)]
const BIN_DATA: &[u8] = include_bytes!("../data.bin");
#[cfg(not(windows))]
const BIN_DATA: &[u8] = &[];
// 4bytes
const LENGTH: usize = 4;
const IDENTIFIER_LENGTH: usize = 8;
const MD5_LENGTH: usize = 32;
const BUF_SIZE: usize = 4096;

pub(crate) struct BinaryData {
    pub md5_code: &'static [u8],
    // compressed gzip data
    pub raw: &'static [u8],
    pub path: String,
}

pub(crate) struct BinaryReader {
    pub files: Vec<BinaryData>,
    pub exe: String,
}

impl Default for BinaryReader {
    fn default() -> Self {
        let (files, exe) = BinaryReader::read();
        Self { files, exe }
    }
}

impl BinaryData {
    fn decompress(&self) -> std::io::Result<Vec<u8>> {
        let cursor = Cursor::new(self.raw);
        let mut decoder = brotli::Decompressor::new(cursor, BUF_SIZE);
        let mut buf = Vec::new();
        decoder.read_to_end(&mut buf)?;
        if format!("{:x}", md5::compute(&buf)).as_bytes() != self.md5_code {
            return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "Portable payload checksum mismatch"));
        }
        Ok(buf)
    }

    pub fn write_to_file(&self, prefix: &Path) -> std::io::Result<()> {
        let p = prefix.join(&self.path);
        if let Some(parent) = p.parent() {
            if !parent.exists() {
                fs::create_dir_all(parent)?;
            }
        }
        if p.exists() {
            // check md5
            let f = fs::read(&p)?;
            let digest = format!("{:x}", md5::compute(&f));
            let md5_record = String::from_utf8_lossy(self.md5_code);
            if digest == md5_record {
                // same, skip this file
                println!("skip {}", &self.path);
                return Ok(());
            } else {
                println!("writing {}", p.display());
                println!("{} -> {}", md5_record, digest)
            }
        }
        fs::write(p, self.decompress()?)
    }
}

impl BinaryReader {
    pub fn cache_id(&self) -> String {
        // Namespace by the complete embedded payload, including its entry point.
        // Old running releases can keep their DLLs locked without affecting this one.
        format!("{:x}", md5::compute(BIN_DATA))
    }

    fn read() -> (Vec<BinaryData>, String) {
        let mut base: usize = 0;
        let mut parsed = vec![];
        assert!(BIN_DATA.len() > IDENTIFIER_LENGTH, "bin data invalid!");
        let mut iden = String::from_utf8_lossy(&BIN_DATA[base..base + IDENTIFIER_LENGTH]);
        if iden != "rustdesk" {
            panic!("bin file is not valid!");
        }
        base += IDENTIFIER_LENGTH;
        loop {
            iden = String::from_utf8_lossy(&BIN_DATA[base..base + IDENTIFIER_LENGTH]);
            if iden == "rustdesk" {
                base += IDENTIFIER_LENGTH;
                break;
            }
            // start reading
            let mut offset = 0;
            let path_length = u32::from_be_bytes([
                BIN_DATA[base + offset],
                BIN_DATA[base + offset + 1],
                BIN_DATA[base + offset + 2],
                BIN_DATA[base + offset + 3],
            ]) as usize;
            offset += LENGTH;
            let path =
                String::from_utf8_lossy(&BIN_DATA[base + offset..base + offset + path_length])
                    .to_string();
            offset += path_length;
            // file sz
            let file_length = u32::from_be_bytes([
                BIN_DATA[base + offset],
                BIN_DATA[base + offset + 1],
                BIN_DATA[base + offset + 2],
                BIN_DATA[base + offset + 3],
            ]) as usize;
            offset += LENGTH;
            let raw = &BIN_DATA[base + offset..base + offset + file_length];
            offset += file_length;
            // md5
            let md5 = &BIN_DATA[base + offset..base + offset + MD5_LENGTH];
            offset += MD5_LENGTH;
            parsed.push(BinaryData {
                md5_code: md5,
                raw: raw,
                path: path,
            });
            base += offset;
        }
        // executable
        let executable = String::from_utf8_lossy(&BIN_DATA[base..]).to_string();
        (parsed, executable)
    }

    #[cfg(linux)]
    pub fn configure_permission(&self, prefix: &Path) {
        use std::os::unix::prelude::PermissionsExt;

        let exe_path = prefix.join(&self.exe);
        if exe_path.exists() {
            if let Ok(f) = File::open(exe_path) {
                if let Ok(meta) = f.metadata() {
                    let mut permissions = meta.permissions();
                    permissions.set_mode(0o755);
                    f.set_permissions(permissions).ok();
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn fixture() -> BinaryData {
        let mut compressed = Vec::new();
        {
            let mut writer = brotli::CompressorWriter::new(&mut compressed, 4096, 3, 22);
            writer.write_all(b"hello").unwrap();
        }
        BinaryData {
            md5_code: b"5d41402abc4b2a76b9719d911017c592",
            raw: Box::leak(compressed.into_boxed_slice()),
            path: "librustdesk.dll".to_owned(),
        }
    }

    fn temp_dir() -> std::path::PathBuf {
        let path = std::env::temp_dir().join(format!("kowsardesk-test-{}-{}", std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        fs::create_dir_all(&path).unwrap();
        path
    }

    #[test]
    fn extracts_and_reuses_matching_payload() {
        let dir = temp_dir();
        let file = fixture();
        file.write_to_file(&dir).unwrap();
        assert_eq!(fs::read(dir.join(&file.path)).unwrap(), b"hello");
        file.write_to_file(&dir).unwrap();
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn checksum_mismatch_preserves_previous_file() {
        let dir = temp_dir();
        let mut file = fixture();
        fs::write(dir.join(&file.path), b"previous").unwrap();
        file.md5_code = b"00000000000000000000000000000000";
        assert!(file.write_to_file(&dir).is_err());
        assert_eq!(fs::read(dir.join(&file.path)).unwrap(), b"previous");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn invalid_compressed_data_is_rejected() {
        let mut file = fixture();
        file.raw = b"invalid brotli";
        assert!(file.decompress().is_err());
    }

    #[test]
    fn cannot_write_over_directory() {
        let dir = temp_dir();
        let file = fixture();
        fs::create_dir(dir.join(&file.path)).unwrap();
        assert!(file.write_to_file(&dir).is_err());
        fs::remove_dir_all(dir).unwrap();
    }

    #[cfg(windows)]
    #[test]
    fn locked_old_payload_cannot_be_silently_reused() {
        use std::os::windows::fs::OpenOptionsExt;
        let dir = temp_dir();
        let file = fixture();
        fs::write(dir.join(&file.path), b"legacy").unwrap();
        let locked = fs::OpenOptions::new().read(true).share_mode(0).open(dir.join(&file.path)).unwrap();
        assert!(file.write_to_file(&dir).is_err());
        drop(locked);
        assert_eq!(fs::read(dir.join(&file.path)).unwrap(), b"legacy");
        fs::remove_dir_all(dir).unwrap();
    }
}
