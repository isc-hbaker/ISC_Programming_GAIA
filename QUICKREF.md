# Quick Reference: How to Run Each Processor

## TL;DR - 60 Second Start

```bash
# Terminal 1: Build & Start
git clone <repo>
cd isc-gaia
docker compose build
docker compose up -d

# Terminal 2: Run
docker compose exec iris iris session iris

# In IRIS terminal:
do $SYSTEM.OBJ.ImportDir("/opt/gaia/src/iris/cls", "ck")
do ^RunScript
# Done! ObjectScript processor ran and stored results in globals
```

---

## Running Each Processor

### ObjectScript (IRIS Native)
**Fastest to test - no build required**

```objectscript
# In IRIS terminal:
do ##class(Gaia.ObjectScriptProcessor).Run("/data/in/sample.csv", 100)

# Or via Service API:
do ##class(Gaia.Service).Process("objectscript", "/data/in/sample.csv", 100)
```

### Rust (High Performance)
**Requires build, then call from IRIS**

```bash
# Terminal A: Build the binary
docker compose exec iris bash
cd /opt/gaia/src/rust
cargo build --release
mkdir -p /opt/gaia/build/rust
cp target/release/gaia_engine /opt/gaia/build/rust/gaia-engine
exit

# Terminal B: Test from IRIS
docker compose exec iris iris session iris

# In IRIS terminal:
do ##class(Gaia.RustProcessor).Run("/data/in/sample.csv", 100)

# Or via Service API:
do ##class(Gaia.Service).Process("rust", "/data/in/sample.csv", 100)
```

### APL (Code Golf)
**Requires Dyalog APL installed on host**

```bash
# Direct execution (host terminal, not in Docker):
dyalogscript src/apl/gaia.apl /data/in/sample.csv /data/out/results.csv 100

# Or via Service API (IRIS terminal):
do ##class(Gaia.Service).Process("apl", "/data/in/sample.csv", 100)
```

---

## View Results

```objectscript
# In IRIS terminal, after running any processor:

# All matches:
select * from ^Gaia.DataD

# Check count:
set x = $order(^Gaia.DataI("Change",""),-1)
write "Max variability: ", x, "%"

# Clear for next test:
Kill ^Gaia.DataD, ^Gaia.DataI
```

---

## Edit RunScript.mac to Test Each

**File:** `src/RunScript.mac`

```objectscript
# Default (ObjectScript):
Do RunObjectScript(inputFile, threshold)

# Change to test Rust:
#; Do RunObjectScript(inputFile, threshold)
Do RunRust(inputFile, threshold)

# Change to test APL:
#; Do RunObjectScript(inputFile, threshold)
Do RunAPL(inputFile, threshold)
```

Then in IRIS: `do ^RunScript`

---

## All Processors Implement Same Contract

```objectscript
ClassMethod Run(inputFile As %String, threshold As %Numeric = 100) As %Status
```

So you can swap them in RunScript or call directly:

```objectscript
# Same interface:
do ##class(Gaia.ObjectScriptProcessor).Run(file, threshold)
do ##class(Gaia.RustProcessor).Run(file, threshold)
do ##class(Gaia.APLProcessor).Run(file, threshold)

# Or via dispatcher:
do ##class(Gaia.Service).Process("objectscript", file, threshold)
do ##class(Gaia.Service).Process("rust", file, threshold)
do ##class(Gaia.Service).Process("apl", file, threshold)
```

---

## Timing Comparison

```objectscript
# ObjectScript
set t=$ZHOROLOG
do ##class(Gaia.ObjectScriptProcessor).Run("/data/in/sample.csv", 100)
write ($ZHOROLOG - t), " seconds"

Kill ^Gaia.DataD, ^Gaia.DataI

# Rust
set t=$ZHOROLOG
do ##class(Gaia.RustProcessor).Run("/data/in/sample.csv", 100)
write ($ZHOROLOG - t), " seconds"
```

---

## Gotchas

- **No input file?** → Copy test data to `/data/in/` in container
- **Classes won't compile?** → `do $SYSTEM.OBJ.ImportDir("/opt/gaia/src/iris/cls", "cv")`
- **Rust not found?** → Ensure `cargo build --release` completed
- **APL won't run?** → Install Dyalog APL on host, run from host not container
- **Results persist?** → `Kill ^Gaia.DataD, ^Gaia.DataI` between tests

---

## File Locations in Container

| Path | Purpose |
|------|---------|
| `/opt/gaia/src/iris/cls/Gaia/*.cls` | ObjectScript classes |
| `/opt/gaia/src/RunScript.mac` | Benchmark runner |
| `/opt/gaia/src/rust/src/main.rs` | Rust implementation |
| `/opt/gaia/src/apl/gaia.apl` | APL implementation |
| `/data/in/` | Input CSV files |
| `/data/out/` | Output files |
| `/opt/gaia/build/rust/gaia-engine` | Compiled Rust binary |

---

**Q: How do judges test this?**
A: Part A: `docker compose up`, Part B: compile classes, Part C: `do ^RunScript` ✓

**Q: Can I test all three at once?**
A: Yes - edit RunScript.mac and call all three subroutines, or clear globals between runs.

**Q: What's the performance difference?**
A: Rust >> ObjectScript >> APL (in speed); ObjectScript = no external deps.
