# Local Testing Setup - Pick Up Tomorrow

## What You Need to Install

### For ObjectScript Testing
- **IRIS Community Edition** (free)
- Download: https://www.intersystems.com/iris-community-edition/
- Time: ~30 min setup + ~5 min test

### For Rust Testing  
- **Rust toolchain** (free)
- Download: https://rustup.rs/
- Time: ~10 min setup + ~5 min build + ~2 min test

### For APL Testing
- **Dyalog APL** (free community version)
- Download: https://www.dyalog.com/
- Time: ~10 min setup + ~2 min test

---

## IRIS Setup (ObjectScript Testing)

### Installation
1. Download IRIS Community Edition from https://www.intersystems.com/iris-community-edition/
2. Install to default location
3. Start IRIS (check Windows Services or System Tray)

### Test ObjectScript Locally
```bash
# Open PowerShell or Command Prompt

# Start IRIS session
iris session iris

# In IRIS terminal (USER>):
do $SYSTEM.OBJ.ImportDir("c:\Users\ToO_BakerHM22\isc-gaia\src\iris\cls", "ck")

# Clear any previous results
Kill ^Gaia.DataD, ^Gaia.DataI

# Create test data first (see "Create Test Data" section below)

# Run ObjectScript processor
do ##class(Gaia.ObjectScriptProcessor).Run("c:\Users\ToO_BakerHM22\isc-gaia\tests\sample-data\test.csv", 100)

# View results
select * from ^Gaia.DataD

# Done!
quit
```

---

## Rust Setup (Rust Testing)

### Installation
1. Download from https://rustup.rs/
2. Run installer (accepts all defaults)
3. Restart PowerShell/Terminal
4. Verify: `rustc --version`

### Build Rust Binary
```bash
cd c:\Users\ToO_BakerHM22\isc-gaia\src\rust
cargo build --release

# Binary will be at:
# .\target\release\gaia_engine.exe
```

### Test Rust Locally (No IRIS needed)
```bash
# After build:
cd c:\Users\ToO_BakerHM22\isc-gaia

# Run binary directly:
.\build\rust\gaia_engine.exe tests\sample-data\test.csv 100

# Should output: CSV results to console
```

### OR Test via IRIS
```bash
# In IRIS terminal:
do ##class(Gaia.RustProcessor).Run("c:\Users\ToO_BakerHM22\isc-gaia\tests\sample-data\test.csv", 100)
```

---

## APL Setup (APL Testing)

### Installation
1. Download from https://www.dyalog.com/
2. Select free community version
3. Install to default location
4. Verify: `dyalogscript --version` in PowerShell

### Test APL Locally
```bash
cd c:\Users\ToO_BakerHM22\isc-gaia

dyalogscript src\apl\gaia.apl tests\sample-data\test.csv output.csv 100

# Should output: CSV file with results
# Check: type output.csv
```

---

## Create Test Data First

Before testing, create a small test CSV file:

**File**: `c:\Users\ToO_BakerHM22\isc-gaia\tests\sample-data\test.csv`

```csv
source_id,ra,dec,bp_flux,rp_flux
123,10.1,-20.2,"[12.4; 15.1; NaN; 30.2]","[11.2; 14.8; NaN; 29.1]"
456,11.2,-21.3,"[20.5; NaN; 25.3]","[19.8; 22.1; NaN]"
789,12.3,-22.4,"[100.0; 200.0; 150.0]","[95.0; 190.0; 140.0]"
```

**Expected results** (sources with ≥100% variability):
- `123`: 10.1, -20.2, min=12.4, max=30.2, change=144.32% ✓
- `789`: 12.3, -22.4, min=95.0, max=200.0, change=110.53% ✓

So you should see 2 results for threshold=100.

---

## Testing Order

### Day 1: ObjectScript
1. Install IRIS
2. Create test CSV
3. Import classes
4. Run processor
5. Verify 2 results

### Day 2: Rust
1. Install Rust
2. Build binary
3. Run binary with test data
4. Verify CSV output

### Day 3: APL
1. Install Dyalog APL
2. Run APL script
3. Verify output.csv

---

## Troubleshooting Tomorrow

### ObjectScript Issues

**Error: Class not found**
```objectscript
# Reimport classes:
do $SYSTEM.OBJ.ImportDir("c:\Users\ToO_BakerHM22\isc-gaia\src\iris\cls", "cv")
```

**Error: File not found**
- Verify test.csv exists: `dir c:\Users\ToO_BakerHM22\isc-gaia\tests\sample-data\`

**Clear results between tests:**
```objectscript
Kill ^Gaia.DataD, ^Gaia.DataI
```

### Rust Issues

**Error: cargo not found**
- Restart PowerShell after installing Rust
- Verify: `cargo --version`

**Error: Build fails**
```bash
cd src\rust
cargo build --release 2>&1 | tee build.log
# Check build.log for errors
```

**Error: Binary not found**
```bash
# Ensure build completed:
dir .\target\release\gaia_engine.exe
```

### APL Issues

**Error: dyalogscript not found**
- Install Dyalog APL
- Restart PowerShell
- Verify: `dyalogscript --version`

**Error: Wrong output format**
- Check output.csv was created
- View: `type output.csv`

---

## Quick Checklist Tomorrow

### Setup Phase
- [ ] Install IRIS
- [ ] Install Rust  
- [ ] Install Dyalog APL
- [ ] Create test.csv

### Testing Phase
- [ ] Test ObjectScript → 2 results
- [ ] Test Rust → CSV output
- [ ] Test APL → CSV file created

### Verification
- [ ] All three run without errors
- [ ] ObjectScript: 2 matches in globals
- [ ] Rust: CSV output to console
- [ ] APL: CSV file created

---

## Key Paths Tomorrow

```
Project: c:\Users\ToO_BakerHM22\isc-gaia\

Classes: c:\Users\ToO_BakerHM22\isc-gaia\src\iris\cls\Gaia\
- Service.cls
- Engine.cls  
- Config.cls
- ObjectScriptProcessor.cls
- RustProcessor.cls

Scripts:
- src\RunScript.mac (IRIS benchmark runner)
- src\apl\gaia.apl (APL implementation)
- src\rust\src\main.rs (Rust implementation)

Test Data:
- tests\sample-data\test.csv (create this first)

Rust Binary (after build):
- .\target\release\gaia_engine.exe
```

---

## Tomorrow's Timeline

| Step | Tool | Time | Status |
|------|------|------|--------|
| Install IRIS | IRIS Community | 30 min | [ ] |
| Import classes | IRIS | 1 min | [ ] |
| Create test CSV | Text editor | 2 min | [ ] |
| Test ObjectScript | IRIS | 5 min | [ ] |
| Install Rust | rustup | 10 min | [ ] |
| Build Rust | cargo | 5 min | [ ] |
| Test Rust binary | PowerShell | 2 min | [ ] |
| Install Dyalog | Dyalog | 10 min | [ ] |
| Test APL | dyalogscript | 2 min | [ ] |
| **Total** | | **67 min** | |

---

## Notes

1. **ObjectScript** is the safest test - it's pure IRIS
2. **Rust** build will take a while the first time (it compiles dependencies)
3. **APL** is the quickest test once installed
4. All three should produce consistent results on same test data
5. You can test them in any order

---

## When You Finish Tomorrow

You'll be able to run all three locally:

```bash
# ObjectScript
iris session iris << 'EOF'
do ##class(Gaia.ObjectScriptProcessor).Run("test.csv", 100)
quit
EOF

# Rust
gaia_engine.exe test.csv 100

# APL
dyalogscript src\apl\gaia.apl test.csv output.csv 100
```

Then you can submit 3 separate contest entries, one for each.

---

**Come back when you're ready to install and test. I'll be here to help debug if anything breaks.**
