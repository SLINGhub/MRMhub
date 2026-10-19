use quick_xml::events::Event;
use quick_xml::reader::Reader;
use std::io::Read;
use std::str;
pub struct Q1Q3RtI {
    pub ord: u16,
    pub q1: f32,
    pub q3: f32,
    pub rt_i_l: Vec<(f32, f32)>,
    pub polarity: bool,
    pub ce: f32,
}

/// Checks that an mzML file has the layout `mzml()` relies on, so that a wrongly converted file stops step 1 with a
/// clear message instead of a panic or silently empty chromatograms:
/// - root element `indexedmzML` (MSConvert "Write index"; `mzml()` finds the chromatograms at that depth),
/// - at least one chromatogram,
/// - chromatogram arrays of 32- or 64-bit floats, zlib-compressed or uncompressed (no MS-Numpress).
///
/// Only the start of the file is read: the root element and the binary arrays of the first chromatogram.
pub fn check_format(mzml_f: &std::path::Path) -> Result<(), String> {
    let file = std::fs::File::open(mzml_f).map_err(|e| format!("cannot be opened ({e})"))?;
    check_format_reader(std::io::BufReader::new(file))
}

fn check_format_reader<R: std::io::BufRead>(rdr: R) -> Result<(), String> {
    let mut reader = Reader::from_reader(rdr);
    reader.config_mut().trim_text(true);
    let mut buf = Vec::new();
    let mut root_seen = false;
    let mut in_chrom_list = false;
    let mut in_array = false;
    let mut supported_compression = false;
    let mut other_compression = None;
    let mut float_precision = false;
    loop {
        let event = reader
            .read_event_into(&mut buf)
            .map_err(|e| format!("is not valid XML ({e})"))?;
        match event {
            Event::Start(e) => {
                let name = e.local_name();
                if !root_seen {
                    if name.as_ref() != b"indexedmzML" {
                        return Err(format!(
                            "is not an indexed mzML (root element <{}> instead of <indexedmzML>); convert it again \
                             with MSConvert with \"Write index\" enabled (no --noindex)",
                            String::from_utf8_lossy(name.as_ref())
                        ));
                    }
                    root_seen = true;
                }
                match name.as_ref() {
                    b"chromatogramList" => in_chrom_list = true,
                    b"binaryDataArray" if in_chrom_list => in_array = true,
                    _ => {}
                }
            }
            Event::Empty(e) if in_array && e.local_name().as_ref() == b"cvParam" => {
                let Ok(Some(acc)) = e.try_get_attribute("accession") else {
                    continue;
                };
                let name = e
                    .try_get_attribute("name")
                    .ok()
                    .flatten()
                    .map(|n| String::from_utf8_lossy(&n.value).into_owned())
                    .unwrap_or_default();
                match acc.value.as_ref() {
                    // 32-bit / 64-bit float
                    b"MS:1000521" | b"MS:1000523" => float_precision = true,
                    // zlib compression / no compression
                    b"MS:1000574" | b"MS:1000576" => supported_compression = true,
                    // any other compression term (MS-Numpress, ...)
                    _ if name.to_lowercase().contains("compression") => {
                        other_compression = Some(name)
                    }
                    _ => {}
                }
            }
            Event::End(e) if in_array && e.local_name().as_ref() == b"binaryDataArray" => {
                if let Some(name) = other_compression {
                    return Err(format!(
                        "uses an unsupported compression ({name}); convert it again with MSConvert with zlib or no \
                         compression (no MS-Numpress)"
                    ));
                }
                if !supported_compression {
                    return Err("has chromatogram arrays without a compression term".into());
                }
                if !float_precision {
                    return Err("has chromatogram arrays that are not 32- or 64-bit floats".into());
                }
                return Ok(());
            }
            Event::Eof if root_seen => return Err("contains no chromatograms".into()),
            Event::Eof => return Err("is empty or not an XML file".into()),
            _ => {}
        }
        buf.clear();
    }
}

#[must_use]
pub fn mzml(mzml_f: &std::path::Path) -> (String, Vec<Q1Q3RtI>) {
    let mut reader = Reader::from_file(mzml_f).unwrap();
    reader.config_mut().trim_text(true);
    let mut stack = Vec::<Vec<u8>>::new();
    let mut buf = Vec::new();
    let mut rt_l = Vec::<f32>::new();
    let mut i_l = Vec::<f32>::new();
    let mut buf0 = Vec::<u8>::new();
    let mut buf1 = Vec::<u8>::new();
    let mut zlibc = None;
    let mut pre64 = None;
    let mut time_arr = None;
    let mut polarity = None;
    let mut ce = 0.;
    let mut q1 = f32::NAN;
    let mut q3 = f32::NAN;
    let mut ord = 0;
    let mut q1q3eics = Vec::new();
    let mut ts = String::new();
    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(e)) => {
                stack.push(e.local_name().as_ref().to_vec());
                if e.local_name().as_ref() == b"run" {
                    if let Ok(Some(value)) = e.try_get_attribute("startTimeStamp") {
                        ts = String::from_utf8(value.value.to_vec()).unwrap();
                    }
                    break;
                }
            }
            Ok(Event::End(_)) => {
                stack.pop();
            }
            _ => (),
        }
        buf.clear();
    }
    loop {
        match reader.read_event_into(&mut buf) {
            Err(e) => panic!("Error at position {}: {e:?}", reader.buffer_position()),
            Ok(Event::Eof) => break,
            Ok(Event::Start(e)) => {
                if e.local_name().as_ref() == b"chromatogram"
                    && let Ok(Some(index)) = e.try_get_attribute("index")
                {
                    ord = str::from_utf8(&index.value).unwrap().parse().unwrap();
                }
                if e.local_name().as_ref() == b"binaryDataArray" {
                    zlibc = None;
                    pre64 = None;
                    time_arr = None;
                }
                stack.push(e.local_name().as_ref().to_vec());
            }
            Ok(Event::End(e)) => {
                if e.local_name().as_ref() == b"chromatogram" {
                    if q1.is_finite() && q3.is_finite() {
                        q1q3eics.push(Q1Q3RtI {
                            ord,
                            q1,
                            q3,
                            rt_i_l: rt_l.drain(..).zip(i_l.drain(..)).collect(),
                            polarity: polarity.unwrap(),
                            ce,
                        });
                    }
                    q1 = f32::NAN;
                    q3 = f32::NAN;
                    ce = 0.;
                    polarity = None;
                }
                stack.pop();
            }
            Ok(Event::Empty(e)) if e.local_name().as_ref() == b"cvParam" => {
                let Ok(Some(accession)) = e.try_get_attribute("accession") else {
                    continue;
                };
                match accession.value.as_ref() {
                    b"MS:1000827" => match stack[stack.len() - 2].as_slice() {
                        b"precursor" => {
                            if let Ok(Some(value)) = e.try_get_attribute("value") {
                                q1 = str::from_utf8(&value.value).unwrap().parse().unwrap();
                            }
                        }
                        b"product" => {
                            if let Ok(Some(value)) = e.try_get_attribute("value") {
                                q3 = str::from_utf8(&value.value).unwrap().parse().unwrap();
                            }
                        }
                        _ => {}
                    },
                    b"MS:1000523" => pre64 = Some(true),
                    b"MS:1000521" => pre64 = Some(false),
                    b"MS:1000574" => zlibc = Some(true),
                    b"MS:1000576" => zlibc = Some(false),
                    b"MS:1000595" => time_arr = Some(true),
                    b"MS:1000515" => time_arr = Some(false),
                    b"MS:1000130" => polarity = Some(true),
                    b"MS:1000129" => polarity = Some(false),
                    b"MS:1000045" => {
                        if let Ok(Some(value)) = e.try_get_attribute("value") {
                            ce = str::from_utf8(&value.value).unwrap().parse().unwrap();
                        }
                    }
                    _ => {}
                }
            }
            Ok(Event::Text(e))
                if stack[stack.len() - 1] == b"binary" && stack[3] == b"chromatogramList" =>
            {
                let Some(pre64) = pre64 else {
                    continue;
                };
                let arr_l = if time_arr.expect("array type not set") {
                    &mut rt_l
                } else {
                    &mut i_l
                };
                decode_bin(
                    e.as_ref(),
                    zlibc.expect("zlib not set"),
                    pre64,
                    arr_l,
                    &mut buf0,
                    &mut buf1,
                )
                .unwrap();
            }
            _ => (),
        }
        buf.clear();
    }
    q1q3eics.sort_unstable_by(|x, y| x.q1.partial_cmp(&y.q1).unwrap());
    (ts, q1q3eics)
}
fn decode_bin(
    bin: &[u8],
    zlibc: bool,
    pre64: bool,
    arr_l: &mut Vec<f32>,
    buf0: &mut Vec<u8>,
    buf1: &mut Vec<u8>,
) -> std::io::Result<()> {
    use base64::Engine as _;
    buf0.clear();
    base64::engine::general_purpose::STANDARD
        .decode_vec(bin, buf0)
        .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidData, error))?;
    let buf2 = if zlibc {
        buf1.clear();
        flate2::bufread::ZlibDecoder::new(buf0.as_slice()).read_to_end(buf1)?;
        buf1
    } else {
        buf0
    };
    arr_l.clear();
    if pre64 {
        arr_l.extend(
            buf2.as_chunks::<{ std::mem::size_of::<f64>() }>()
                .0
                .iter()
                .map(|&s| f64::from_le_bytes(s) as f32),
        );
    } else {
        arr_l.extend(
            buf2.as_chunks::<{ std::mem::size_of::<f32>() }>()
                .0
                .iter()
                .map(|&s| f32::from_le_bytes(s)),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::check_format_reader;

    // A minimal mzML with one chromatogram, wrapped in <indexedmzML> if `indexed`; `compression` and `precision`
    // are the cvParams of both arrays.
    fn mzml(indexed: bool, compression: &str, precision: &str) -> String {
        let arrays = format!(
            r#"<binaryDataArrayList count="2">
<binaryDataArray encodedLength="0">{precision}{compression}<cvParam cvRef="MS" accession="MS:1000595" name="time array"/><binary/></binaryDataArray>
<binaryDataArray encodedLength="0">{precision}{compression}<cvParam cvRef="MS" accession="MS:1000515" name="intensity array"/><binary/></binaryDataArray>
</binaryDataArrayList>"#
        );
        let body = format!(
            r#"<mzML xmlns="http://psi.hupo.org/ms/mzml" version="1.1.0"><run id="r" startTimeStamp="2021-10-22T18:07:18Z">
<chromatogramList count="1"><chromatogram index="0" id="x" defaultArrayLength="0">{arrays}</chromatogram></chromatogramList>
</run></mzML>"#
        );
        let xml = if indexed {
            format!(
                r#"<indexedmzML xmlns="http://psi.hupo.org/ms/mzml">{body}<indexList count="0"/></indexedmzML>"#
            )
        } else {
            body
        };
        format!("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n{xml}")
    }
    const ZLIB: &str = r#"<cvParam cvRef="MS" accession="MS:1000574" name="zlib compression"/>"#;
    const NONE: &str = r#"<cvParam cvRef="MS" accession="MS:1000576" name="no compression"/>"#;
    const NUMPRESS: &str = r#"<cvParam cvRef="MS" accession="MS:1002312" name="MS-Numpress linear prediction compression"/>"#;
    const F32: &str = r#"<cvParam cvRef="MS" accession="MS:1000521" name="32-bit float"/>"#;
    const I32: &str = r#"<cvParam cvRef="MS" accession="MS:1000519" name="32-bit integer"/>"#;

    fn check(xml: &str) -> Result<(), String> {
        check_format_reader(xml.as_bytes())
    }

    #[test]
    fn accepts_indexed_zlib_and_uncompressed() {
        assert_eq!(check(&mzml(true, ZLIB, F32)), Ok(()));
        assert_eq!(check(&mzml(true, NONE, F32)), Ok(()));
    }

    #[test]
    fn rejects_mzml_without_index() {
        let err = check(&mzml(false, ZLIB, F32)).unwrap_err();
        assert!(err.contains("not an indexed mzML"), "{err}");
    }

    #[test]
    fn rejects_numpress() {
        let err = check(&mzml(true, NUMPRESS, F32)).unwrap_err();
        assert!(err.contains("unsupported compression"), "{err}");
    }

    #[test]
    fn rejects_non_float_arrays() {
        let err = check(&mzml(true, ZLIB, I32)).unwrap_err();
        assert!(err.contains("32- or 64-bit floats"), "{err}");
    }

    #[test]
    fn rejects_files_without_chromatograms_or_xml() {
        let no_chrom = r#"<indexedmzML><mzML><run id="r"/></mzML></indexedmzML>"#;
        assert!(check(no_chrom).unwrap_err().contains("no chromatograms"));
        assert!(check("").unwrap_err().contains("empty or not an XML file"));
    }
}
