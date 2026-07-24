use std::fs::File;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::time::Instant;
use flate2::read::GzDecoder;
use rayon::prelude::*;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: gaia_engine <input.csv[.gz]> [threshold] [output.csv]");
        std::process::exit(1);
    }
    let input = &args[1];
    let threshold = args.get(2).and_then(|s| s.parse::<f64>().ok()).unwrap_or(100.0);
    let output = args.get(3).map(|s| s.as_str()).unwrap_or("gaia_results.csv");

    let t0 = Instant::now();
    eprintln!("Input: {}  Threshold: {}%", input, threshold);

    match run(input, threshold, output) {
        Ok((total, matched)) => eprintln!(
            "Done. {total} records, {matched} matched in {:.3}s",
            t0.elapsed().as_secs_f64()
        ),
        Err(e) => { eprintln!("Error: {e}"); std::process::exit(1); }
    }
}

fn run(path: &str, threshold: f64, out_path: &str)
    -> Result<(usize, usize), Box<dyn std::error::Error>>
{
    let lines = load_lines(path)?;
    let n = lines.len();

    // Parallel: each line -> Option<(source_id, bp_min, bp_max, rp_min, rp_max, var)>
    let results: Vec<Option<[f64; 6]>> = lines
        .par_iter()
        .map(|line| process_line(line, threshold))
        .collect();

    let hits: Vec<&[f64; 6]> = results.iter().flatten().collect();
    let m = hits.len();

    let file = File::create(out_path)?;
    let mut w = BufWriter::new(file);
    writeln!(w, "source_id,bp_min,bp_max,rp_min,rp_max,variability_percent")?;
    for r in &hits {
        // r[0] is source_id as f64 (large int, safe up to 2^53)
        writeln!(w, "{:.0},{:.6},{:.6},{:.6},{:.6},{:.6}",
            r[0], r[1], r[2], r[3], r[4], r[5])?;
    }
    w.flush()?;

    Ok((n, m))
}

fn load_lines(path: &str) -> Result<Vec<Vec<u8>>, Box<dyn std::error::Error>> {
    let file = File::open(path)?;
    let mut lines: Vec<Vec<u8>> = Vec::with_capacity(8192);
    let mut past_header = false;

    macro_rules! read_lines {
        ($reader:expr) => {{
            for line in $reader.lines() {
                let l = line?;
                let b = l.as_bytes();
                if b.first() == Some(&b'#') { continue; }
                if !past_header { past_header = true; continue; }
                if !b.is_empty() { lines.push(l.into_bytes()); }
            }
        }};
    }

    if path.ends_with(".gz") {
        read_lines!(BufReader::new(GzDecoder::new(file)));
    } else {
        read_lines!(BufReader::new(file));
    }

    Ok(lines)
}

// Returns [source_id_f64, bp_min, bp_max, rp_min, rp_max, variability] or None
fn process_line(line: &[u8], threshold: f64) -> Option<[f64; 6]> {
    // We need fields at 0-based index: 1=source_id, 11=bp_flux, 16=rp_flux
    // Fields are comma-separated; array fields are quoted: "val,val,NaN,..."
    // We scan byte-by-byte, counting top-level commas (outside quotes).
    let source_id = get_field_f64(line, 1)?;
    let bp_field  = get_field_bytes(line, 11)?;
    let rp_field  = get_field_bytes(line, 16)?;

    let (bp_min, bp_max) = minmax(bp_field);
    let (rp_min, rp_max) = minmax(rp_field);

    if bp_min == 0.0 && bp_max == 0.0 && rp_min == 0.0 && rp_max == 0.0 {
        return None;
    }

    let var = pct(bp_min, bp_max).max(pct(rp_min, rp_max));
    if var >= threshold {
        Some([source_id, bp_min, bp_max, rp_min, rp_max, var])
    } else {
        None
    }
}

#[inline]
fn pct(min: f64, max: f64) -> f64 {
    if min > 0.0 && max > min { (max - min) / min * 100.0 } else { 0.0 }
}

// Returns a byte slice for the Nth field (0-based), stripping outer quotes/brackets
fn get_field_bytes(line: &[u8], target: usize) -> Option<&[u8]> {
    let mut field = 0usize;
    let mut in_quote = false;
    let mut start = 0usize;

    for (i, &b) in line.iter().enumerate() {
        match b {
            b'"' => in_quote = !in_quote,
            b',' if !in_quote => {
                if field == target {
                    return Some(strip(&line[start..i]));
                }
                field += 1;
                start = i + 1;
            }
            _ => {}
        }
    }
    // last field
    if field == target {
        Some(strip(&line[start..]))
    } else {
        None
    }
}

fn get_field_f64(line: &[u8], target: usize) -> Option<f64> {
    let b = get_field_bytes(line, target)?;
    fast_atof(b)
}

// Strip surrounding quotes, brackets, spaces
#[inline]
fn strip(b: &[u8]) -> &[u8] {
    let mut s = b;
    while s.first() == Some(&b'"') || s.first() == Some(&b'[') || s.first() == Some(&b' ') {
        s = &s[1..];
    }
    while s.last() == Some(&b'"') || s.last() == Some(&b']') || s.last() == Some(&b' ') {
        s = &s[..s.len()-1];
    }
    s
}

// Parse comma-separated floats, find min/max ignoring NaN and non-positive
fn minmax(field: &[u8]) -> (f64, f64) {
    let mut min = f64::INFINITY;
    let mut max = f64::NEG_INFINITY;
    for token in field.split(|&b| b == b',') {
        let t = token.trim_ascii();
        if t == b"NaN" || t == b"nan" || t.is_empty() { continue; }
        if let Some(v) = fast_atof(t) {
            if v > 0.0 && v.is_finite() {
                if v < min { min = v; }
                if v > max { max = v; }
            }
        }
    }
    if min.is_infinite() { (0.0, 0.0) } else { (min, max) }
}

// Fast float parse on ASCII bytes — falls back to std for edge cases
#[inline]
fn fast_atof(b: &[u8]) -> Option<f64> {
    // SAFETY: we only have ASCII digits/sign/dot/e from Gaia CSVs
    let s = std::str::from_utf8(b).ok()?;
    s.trim().parse::<f64>().ok()
}
