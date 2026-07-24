# gaia-engine (Rust Performance Engine)

**High-throughput Gaia DR3 epoch-photometry variability detector** for the InterSystems Gaia Challenge.

## Overview
This Rust binary processes large Gaia DR3 epoch photometry CSV files to identify sources with significant brightness variability.

For each `source_id`:
- Tracks RA, Dec, min/max brightness across epochs
- Computes percentage change: `((max - min) / |min|) * 100`
- Outputs only sources where change >= threshold

## Build Instructions
```bash
cd gaia-challenge/src/rust
cargo build --release
```

**Output binary**: `target/release/gaia-engine`

**Copy to IRIS build location**:
```bash
cp target/release/gaia-engine ../../build/rust/gaia-engine
chmod +x ../../build/rust/gaia-engine
```

## Usage
```bash
gaia-engine <input-file> <threshold> [OPTIONS]
```

**Example**:
```bash
gaia-engine data/epoch_photometry.csv 10.0 --format csv
```

### Command Line Options
- `<input-file>`: Path to Gaia DR3 epoch photometry CSV
- `<threshold>`: Minimum % brightness change (e.g. 10.0)
- `--source-col <N>`: 0-based column for `source_id` [default: 0]
- `--ra-col <N>`: 0-based column for RA [default: 1]
- `--dec-col <N>`: 0-based column for Dec [default: 2]
- `--mag-col <N>`: 0-based column for brightness/magnitude [default: 3]
- `--header <BOOL>`: Skip first line as header [default: true]
- `--format <FORMAT>`: `jsonl` (default) or `csv`
- `--threads <N>`: Override Rayon thread count

**Column layout is fully configurable** — match your specific Gaia export (e.g., `g_transit_mag` or similar).

## Output
**CSV**:
```csv
source_id,ra,dec,min_brightness,max_brightness,pct_change
1000000041,242.819503,-23.665825,15.9568,17.7024,10.939537
```

**JSONL** (default):
```json
{"source_id":1000000041,"ra":242.819503,"dec":-23.665825,"min_brightness":15.9568,"max_brightness":17.7024,"pct_change":10.939537}
```

- Results written to **stdout** (IRIS consumes this)
- Progress / stats on **stderr**

## Benchmarks
```bash
cd benchmarks
./bench.sh
```

Includes synthetic data generator and performance reporting.

## Performance Architecture
- Memory-mapped file (`memmap2`)
- Parallel processing with `rayon` (line-aligned chunks)
- Zero-copy parsing + custom fast parsers
- `hashbrown` + `ahash` for per-source aggregation
- Memory scales with unique sources only (not total rows)
- Malformed rows are skipped gracefully

**Expected**: Millions of rows per second on multi-core hardware.

## Dependencies & Notes
See `Cargo.toml` (pinned for compatibility with Rust 1.75).

## IRIS Integration
- Invoked by `Gaia.RustProcessor.cls`
- No changes to other classes needed
- Follows the exact repository contract

---

**Ready for submission to the Gaia Challenge!**