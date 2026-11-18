use quick_xml::events::Event;
use quick_xml::reader::Reader;
use std::io::{self, BufRead, Read};
use std::str;
// stores one parsed transition chromatogram
pub struct Q1Q3RtI {
    pub ord: u16,
    pub q1: f32,
    pub q3: f32,
    pub rt_i_l: Vec<(f32, f32)>,
    pub polarity: bool,
    pub ce: f32,
}
// parses the timestamp and transition chromatograms from an mzml file
pub fn mzml(mzml_f: &std::path::Path) -> io::Result<(String, Vec<Q1Q3RtI>)> {
    let file = std::fs::File::open(mzml_f)?;
    parse_reader(Reader::from_reader(io::BufReader::new(file)))
        .map_err(|error| io::Error::new(error.kind(), format!("{}: {error}", mzml_f.display())))
}

fn parse_reader<R: BufRead>(mut reader: Reader<R>) -> io::Result<(String, Vec<Q1Q3RtI>)> {
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
            Err(error) => return Err(io::Error::new(io::ErrorKind::InvalidData, error)),
            Ok(Event::Eof) => {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    "mzML run element not found",
                ));
            }
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
            Err(error) => return Err(io::Error::new(io::ErrorKind::InvalidData, error)),
            Ok(Event::Eof) => {
                if !stack.is_empty() {
                    return Err(io::Error::new(
                        io::ErrorKind::InvalidData,
                        "mzML ended before all elements were closed",
                    ));
                }
                break;
            }
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
                    &e.decode().unwrap(),
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
    Ok((ts, q1q3eics))
}
// decodes a compressed or uncompressed binary mzml array
fn decode_bin(
    bin: &str,
    zlibc: bool,
    pre64: bool,
    arr_l: &mut Vec<f32>,
    buf0: &mut Vec<u8>,
    buf1: &mut Vec<u8>,
) -> std::io::Result<()> {
    let mut wrapped_reader = bin.as_bytes();
    let mut decoder = base64::read::DecoderReader::new(
        &mut wrapped_reader,
        &base64::engine::general_purpose::STANDARD,
    );
    buf0.clear();
    decoder.read_to_end(buf0)?;
    let buf2 = if zlibc {
        buf1.clear();
        flate2::read::ZlibDecoder::new(buf0.as_slice()).read_to_end(buf1)?;
        buf1
    } else {
        buf0
    };
    arr_l.clear();
    if pre64 {
        arr_l.extend(
            buf2.chunks_exact(std::mem::size_of::<f64>())
                .map(|s| f64::from_le_bytes(s.try_into().unwrap()) as f32),
        );
    } else {
        arr_l.extend(
            buf2.chunks_exact(std::mem::size_of::<f32>())
                .map(|s| f32::from_le_bytes(s.try_into().unwrap())),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_run_is_an_error_instead_of_an_endless_eof_loop() {
        for input in ["", "<mzML></mzML>", "<not-mzml/>"] {
            let error = parse_reader(Reader::from_reader(input.as_bytes()))
                .err()
                .unwrap();
            assert_eq!(error.kind(), io::ErrorKind::InvalidData);
            assert!(error.to_string().contains("run element not found"));
        }
    }

    #[test]
    fn invalid_xml_before_or_after_run_returns_an_error() {
        for input in ["<mzML></wrong>", "<mzML><run></wrong>", "<mzML><run>"] {
            assert!(parse_reader(Reader::from_reader(input.as_bytes())).is_err());
        }
    }

    #[test]
    fn valid_run_preserves_its_acquisition_timestamp() {
        let input = b"<mzML><run startTimeStamp=\"2026-10-18T10:00:00Z\"></run></mzML>";
        let (timestamp, traces) = parse_reader(Reader::from_reader(&input[..])).unwrap();
        assert_eq!(timestamp, "2026-10-18T10:00:00Z");
        assert!(traces.is_empty());
    }
}
