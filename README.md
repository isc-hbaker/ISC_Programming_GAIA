# Gaia Challenge

InterSystems Employee Programming Challenge #1: High-performance variable star detection using Gaia DR3 photometry data.

This repository implements three independent processors for identifying stars with >100% brightness variability:
- **ObjectScript**: Pure IRIS native implementation using globals
- **Rust**: High-performance compiled implementation
- **APL**: Code golf implementation in Dyalog APL

## Structure

- `src/iris/cls/Gaia/` — ObjectScript processor classes
  - `Service.cls` — Public API entrypoint
  - `Engine.cls` — Processor dispatcher
  - `Config.cls` — Configuration
  - `ObjectScriptProcessor.cls` — Pure IRIS implementation
  - `RustProcessor.cls` — Rust processor bridge
  - `APLProcessor.cls` — APL processor bridge (stub)
- `src/iris/REST/` — REST API class (stub)
- `src/iris/SQL/` — SQL schema for results
- `src/rust/` — Rust implementation source
- `src/apl/` — APL implementation source
- `src/RunScript.mac` — **JUDGES: Run this to execute benchmarks**
- `build/rust/` — Build artifacts (gaia-engine executable)
- `data/in/` — Input CSV files for processing
- `data/out/` — Output results directory
- `benchmarks/` — Benchmark test runners
- `tests/` — Test data and expected outputs
- `docs/` — Design documentation

## Quick Start for Judges

### Prerequisites
```bash
# Clone repository
git clone <repo-url>
cd isc-gaia

# Verify Docker and IRIS are available
docker --version
docker compose --version

# For Rust testing: ensure Rust is installed (optional)
rustc --version
```

### Build and Start Container
```bash
# Build Docker image
docker compose build

# Start IRIS container
docker compose up -d

# Verify container is running
docker compose ps
```

### Compile ObjectScript Classes
```bash
# Enter IRIS session
docker compose exec iris iris session iris

# In IRIS terminal (USER>):
do $SYSTEM.OBJ.ImportDir("/opt/gaia/src/iris/cls", "ck")
```

### Run ObjectScript Processor
```objectscript
# In IRIS terminal:

# Run single file with threshold 100%
do ##class(Gaia.ObjectScriptProcessor).Run("/data/in/sample.csv", 100)

# Or via Service API:
do ##class(Gaia.Service).Process("objectscript", "/data/in/sample.csv", 100)

# Query results:
select * from ^Gaia.DataD
```

### Run Rust Processor
```bash
# Build Rust binary (requires Rust toolchain)
cd src/rust
cargo build --release
cp target/release/gaia_engine ../../build/rust/

# Run from IRIS (once built):
do ##class(Gaia.RustProcessor).Run("/data/in/sample.csv", 100)

# Or manually:
./build/rust/gaia_engine /data/in/sample.csv 100
```

### Run APL Processor
```bash
# Requires Dyalog APL installed

# Direct execution:
dyalogscript src/apl/gaia.apl /data/in/sample.csv /data/out/results.csv 100

# Or via IRIS (calls external):
do ##class(Gaia.Service).Process("apl", "/data/in/sample.csv", 100)
```

### Using RunScript.mac (Recommended)
```bash
# Enter container
docker compose exec iris iris session iris

# In IRIS terminal:
do ^RunScript
```

The RunScript includes three options:
1. `Run()` — Runs ObjectScript processor (default)
2. Edit RunScript to uncomment `Do RunRust(...)` to benchmark Rust
3. Edit RunScript to uncomment `Do RunAPL(...)` to benchmark APL

## Data Format

**Input CSV:**
```
source_id,ra,dec,bp_flux,rp_flux
123,10.1,-20.2,"[12.4; 15.1; NaN; 30.2]","[11.2; 14.8; NaN; 29.1]"
456,11.2,-21.3,"[20.5; NaN; 25.3]","[19.8; 22.1; NaN]"
```

**Output:**
- **Globals**: `^Gaia.DataD(sourceId)` contains $ListBuild(sourceId, ra, dec, bpMin, bpMax, rpMin, rpMax, percentChange)
- **Index**: `^Gaia.DataI("Change", percentChange, sourceId)` for sorting by variability

**Selection Criteria:**
- max(bpChange, rpChange) ≥ threshold (default 100%)
- Skips rows where all flux values are NaN/invalid/≤0

## Architecture

```
Gaia.Service.Process(engine, inputFile, threshold)
    ↓
Gaia.Engine.Run(engine, inputFile, threshold)
    ↓
    ├─→ Gaia.ObjectScriptProcessor.Run(inputFile, threshold)
    ├─→ Gaia.RustProcessor.Run(inputFile, threshold)
    └─→ Gaia.APLProcessor.Run(inputFile, threshold)
```

All processors implement identical interface:
```objectscript
ClassMethod Run(inputFile As %String, threshold As %Numeric = 100) As %Status
```

## Performance Characteristics

| Engine | Language | Speed | Memory | Notes |
|--------|----------|-------|--------|-------|
| ObjectScript | Native IRIS | Medium | Low | Pure IRIS, no dependencies |
| Rust | Compiled | ⚡ Fast | Very Low | Must build binary first |
| APL | Interpreted | Slow | High | Code golf; educational |

## Testing

### Smoke Test (All Engines)
```objectscript
// Verify classes compile
do ##class(Gaia.Service).Process("objectscript", "/data/in/test.csv", 100)
```

### Benchmark
```bash
cd benchmarks
bash run-iris.sh
bash run-rust.sh
bash run-apl.sh
```

## Troubleshooting

**Classes won't compile:**
```objectscript
do $SYSTEM.OBJ.ImportDir("/opt/gaia/src/iris/cls", "c")
```

**Rust processor fails:**
```bash
# Ensure executable is built:
cd src/rust && cargo build --release
cp target/release/gaia_engine ../../build/rust/gaia-engine
```

**Permission denied on files:**
```bash
docker compose exec iris chown -R irisowner:irisgroup /data
```

**Clear results between tests:**
```objectscript
Kill ^Gaia.DataD, ^Gaia.DataI
```

## References

- [Challenge Announcement](https://community.intersystems.com/post/intersystems-employee-programming-challenge-1)
- [Open Exchange Contest](https://openexchange.intersystems.com/contest/47)
- [Example Implementation (GitHub)](https://github.com/isc-nmitchko/ISC-Programming-Challenge-GAIA)

## License

[See LICENSE file]
