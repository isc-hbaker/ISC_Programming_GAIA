# Judge Instructions for Gaia Challenge Submission

## Overview

This submission implements three independent processors for identifying variable stars in Gaia DR3 photometry data:

1. **ObjectScript Processor** — Pure IRIS native implementation using globals
2. **Rust Processor** — High-performance compiled implementation  
3. **APL Processor** — Code golf implementation in Dyalog APL

All processors identify stars with ≥100% brightness variability (max-min)/min * 100.

---

## Part A: Initial Setup

### Prerequisites
- Docker and Docker Compose installed
- InterSystems IRIS Community Edition access
- Optional: Rust toolchain for Rust processor testing

### Clone and Build
```bash
# Clone repository
git clone <contest-url>
cd isc-gaia

# Build Docker image
docker compose build

# Start IRIS container
docker compose up -d

# Verify container is running
docker compose ps
```

### Verify IRIS Access
```bash
# Enter IRIS session in container
docker compose exec iris iris session iris

# In IRIS terminal (USER>), verify namespace and classes:
zn "USER"
set x = ##class(Gaia.Service)
write $classname(x)
# Expected output: Gaia.Service
quit
```

---

## Part B: Compile ObjectScript Classes

```bash
# From host terminal:
docker compose exec iris iris session iris

# In IRIS terminal:
do $SYSTEM.OBJ.ImportDir("/opt/gaia/src/iris/cls", "ck")
```

Expected output:
```
Gaia.APLProcessor
Gaia.Config
Gaia.Engine
Gaia.ObjectScriptProcessor
Gaia.RustProcessor
Gaia.Service
```

---

## Part C: Run the Benchmark

### Option 1: Use RunScript.mac (Recommended)

```bash
# From host terminal:
docker compose exec iris iris session iris

# In IRIS terminal:
do ^RunScript
```

This will:
1. Load input file from `/data/in/sample.csv`
2. Run ObjectScript processor with 100% threshold
3. Display elapsed time
4. Store results in globals

#### To Test Different Engines

Edit `src/RunScript.mac` and uncomment the desired processor:

**For Rust:**
```objectscript
#; Uncomment this line:
Do RunRust(inputFile, threshold)
```

**For APL:**
```objectscript
#; Uncomment this line:
Do RunAPL(inputFile, threshold)
```

### Option 2: Direct ObjectScript Calls

```objectscript
# Clear previous results
Kill ^Gaia.DataD, ^Gaia.DataI

# Run with default 100% threshold
do ##class(Gaia.ObjectScriptProcessor).Run("/data/in/sample.csv", 100)

# Or with custom threshold
do ##class(Gaia.ObjectScriptProcessor).Run("/data/in/sample.csv", 50)

# Or via Service API (dispatcher)
do ##class(Gaia.Service).Process("objectscript", "/data/in/sample.csv", 100)
```

### Option 3: Via Service API (All Engines)

```objectscript
# ObjectScript processor
do ##class(Gaia.Service).Process("objectscript", "/data/in/sample.csv", 100)

# Rust processor (requires build - see Part D)
do ##class(Gaia.Service).Process("rust", "/data/in/sample.csv", 100)

# APL processor (requires Dyalog APL - see Part E)
do ##class(Gaia.Service).Process("apl", "/data/in/sample.csv", 100)
```

---

## Part D: Build and Test Rust Processor

### Build Rust Binary

```bash
# From host, inside container:
docker compose exec iris bash

# Inside container bash:
cd /opt/gaia/src/rust
cargo build --release

# Copy binary to expected location:
mkdir -p /opt/gaia/build/rust
cp target/release/gaia_engine /opt/gaia/build/rust/gaia-engine

# Verify binary exists and runs:
/opt/gaia/build/rust/gaia-engine --help
```

### Test Rust Processor

```bash
# Option 1: Via IRIS
docker compose exec iris iris session iris

# In IRIS terminal:
do ##class(Gaia.RustProcessor).Run("/data/in/sample.csv", 100)

# Option 2: Run binary directly (from host)
docker compose exec iris /opt/gaia/build/rust/gaia-engine /data/in/sample.csv 100
```

Expected: CSV output with results written to stdout or file.

---

## Part E: Test APL Processor

### Prerequisites
Dyalog APL must be installed separately (not in Docker).

### Run APL Directly

```bash
# From host (not in container), with Dyalog APL installed:
dyalogscript src/apl/gaia.apl \
  /data/in/sample.csv \
  /data/out/results.csv \
  100
```

### Run via IRIS

```bash
# First, ensure APL processor bridge is implemented
docker compose exec iris iris session iris

# In IRIS terminal:
do ##class(Gaia.Service).Process("apl", "/data/in/sample.csv", 100)
```

Note: APL processor requires shell integration to invoke dyalogscript.

---

## Part F: Query Results

### View Results in IRIS

```objectscript
# After running any processor, results are stored in globals:

# List all matching sources:
select * from ^Gaia.DataD

# View raw global data:
zwrite ^Gaia.DataD

# View index (sorted by variability):
zwrite ^Gaia.DataI

# Count matches:
set count = $order(^Gaia.DataD(""), -1)
write "Total matches: ", count, !

# Get highest variability source:
set highestVar = $order(^Gaia.DataI("Change", ""), -1)
write "Highest variability: ", highestVar, "%", !
```

### Export Results to CSV

```objectscript
# Save results to file
set file = ##class(%File).%New("/data/out/results.csv")
set stream = ##class(%Stream.FileCharacter).%New()
set tSC = stream.LinkToFile("/data/out/results.csv")

# Iterate and write
set sourceId = $order(^Gaia.DataD(""))
while sourceId'="" {
    set record = ^Gaia.DataD(sourceId)
    write $listget(record,1), ",", $listget(record,2), ",", $listget(record,3), ",", 
          $listget(record,4), ",", $listget(record,5), ",", $listget(record,6), ",", 
          $listget(record,7), ",", $listget(record,8), !
    set sourceId = $order(^Gaia.DataD(sourceId))
}
```

---

## Part G: Performance Benchmarking

### Compare All Three Engines

```bash
# From host:
docker compose exec iris iris session iris

# In IRIS terminal, run with timing:

# ObjectScript
do ^RunScript
# Note the elapsed time

# Clear results
Kill ^Gaia.DataD, ^Gaia.DataI

# Edit RunScript.mac to test Rust or APL
# Then run again and compare times
```

### Manual Benchmark

```objectscript
# ObjectScript
set startTime = $ZHOROLOG
do ##class(Gaia.ObjectScriptProcessor).Run("/data/in/sample.csv", 100)
set endTime = $ZHOROLOG
write "ObjectScript: ", (endTime - startTime), " seconds", !

Kill ^Gaia.DataD, ^Gaia.DataI

# Rust (if built)
set startTime = $ZHOROLOG
do ##class(Gaia.RustProcessor).Run("/data/in/sample.csv", 100)
set endTime = $ZHOROLOG
write "Rust: ", (endTime - startTime), " seconds", !
```

---

## Part H: Data Format Reference

### Input CSV
```
source_id,ra,dec,bp_flux,rp_flux
123,10.1,-20.2,"[12.4; 15.1; NaN; 30.2]","[11.2; 14.8; NaN; 29.1]"
456,11.2,-21.3,"[20.5; NaN; 25.3]","[19.8; 22.1; NaN]"
789,12.3,-22.4,"[100.0; 200.0; 150.0]","[95.0; 190.0; 140.0]"
```

### Output Format
**Global: `^Gaia.DataD(sourceId)`**
```
$ListBuild(sourceId, ra, dec, bpMin, bpMax, rpMin, rpMax, percentChange)
```

Example:
```
^Gaia.DataD("123") = $ListBuild("123", 10.1, -20.2, 12.4, 30.2, 11.2, 29.1, 144.32)
```

**Index: `^Gaia.DataI("Change", percentChange, sourceId)`**
Enables sorting by variability:
```
^Gaia.DataI("Change", 144.32, "123") = ""
```

### Selection Criteria
- **Include**: max(bpChange%, rpChange%) ≥ threshold
- **Exclude**: Rows with all-NaN, all-zero, or non-positive flux values
- **Default threshold**: 100%

### Calculation
```
percentChange = ((max - min) / min) * 100
```

---

## Part I: Verification Checklist

- [ ] Docker container builds successfully
- [ ] IRIS starts without errors
- [ ] ObjectScript classes compile
- [ ] ObjectScript processor runs and produces results
- [ ] Results stored in `^Gaia.DataD` and `^Gaia.DataI` globals
- [ ] Threshold parameter is respected (not hardcoded)
- [ ] NaN rows are skipped (no division by zero)
- [ ] Rust processor builds (if testing)
- [ ] APL processor runs (if Dyalog available)
- [ ] RunScript.mac executes without errors
- [ ] Output can be queried and exported

---

## Part J: Troubleshooting

### Issue: Classes won't compile
```objectscript
# Try with verbose mode:
do $SYSTEM.OBJ.ImportDir("/opt/gaia/src/iris/cls", "cv")

# Check for syntax errors:
do ##class(%Studio.SourceControl).ShowStatus("/opt/gaia/src/iris/cls/Gaia/ObjectScriptProcessor.cls")
```

### Issue: File not found errors
```bash
# Verify input file exists:
docker compose exec iris ls -la /data/in/

# Check permissions:
docker compose exec iris stat /data/in/sample.csv
```

### Issue: Rust processor not found
```bash
# Ensure binary is built:
docker compose exec iris cargo build --release --manifest-path /opt/gaia/src/rust/Cargo.toml

# Verify binary location:
docker compose exec iris ls -la /opt/gaia/build/rust/
```

### Issue: Clear results between tests
```objectscript
Kill ^Gaia.DataD, ^Gaia.DataI
```

### Issue: Container won't start
```bash
# Check Docker logs:
docker compose logs iris

# Reset Docker (be careful!):
docker compose down
docker system prune -a
docker compose build --no-cache
docker compose up -d
```

---

## Part K: Contact & References

- **Challenge**: [InterSystems Employee Programming Challenge #1](https://community.intersystems.com/post/intersystems-employee-programming-challenge-1)
- **Contest**: [Open Exchange - Gaia Challenge](https://openexchange.intersystems.com/contest/47)
- **Example**: [Reference Implementation (GitHub)](https://github.com/isc-nmitchko/ISC-Programming-Challenge-GAIA)

---

## Summary

| Task | Command | Location |
|------|---------|----------|
| Build | `docker compose build` | Project root |
| Start | `docker compose up -d` | Project root |
| Compile | `do $SYSTEM.OBJ.ImportDir(...)` | Inside IRIS |
| Run benchmark | `do ^RunScript` | Inside IRIS |
| Run ObjectScript | `do ##class(Gaia.ObjectScriptProcessor).Run(...)` | Inside IRIS |
| Run Rust | Build: `cargo build --release` | In container bash |
| Run APL | `dyalogscript src/apl/gaia.apl ...` | Host shell |
| View results | `select * from ^Gaia.DataD` | Inside IRIS |

---

**Judges: All judges should follow Part A → Part B → Part C to get a working benchmark. Then choose Part D, E, or modify Part C to test specific implementations.**
