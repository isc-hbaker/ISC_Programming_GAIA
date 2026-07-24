# Gaia Challenge - Execution Flows

## Flow 1: ObjectScript Processor (Recommended for Judges)

```
┌─────────────────────────────────────────────────────────┐
│ $ docker compose exec iris iris session iris            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│ USER> do ^RunScript                                      │
│                                                          │
│ ========================================================  │
│  Gaia Challenge - Benchmark Runner                      │
│ ========================================================  │
│                                                          │
│ Input: /data/in/sample.csv                              │
│ Threshold: 100%                                         │
│                                                          │
│ Starting ObjectScript Processor...                      │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
      ┌──────────────────────────────┐
      │ RunScript.Run()              │
      │ ├─ Do RunObjectScript()      │
      └────────────────┬─────────────┘
                       │
                       ▼
      ┌─────────────────────────────────────────┐
      │ Gaia.ObjectScriptProcessor.Run()        │
      │ ├─ Open file stream                    │
      │ ├─ Read line-by-line                   │
      │ ├─ Extract BP/RP flux arrays          │
      │ ├─ Skip NaN rows                       │
      │ ├─ Calculate min/max per band          │
      │ ├─ Calculate % change                  │
      │ ├─ Filter by threshold                 │
      │ └─ Store in ^Gaia.DataD               │
      └────────────────┬────────────────────────┘
                       │
                       ▼
      ┌──────────────────────────────────────────┐
      │ Global Storage:                         │
      │ ^Gaia.DataD(sourceId)                   │
      │  = $ListBuild(id,ra,dec,bpMin,bpMax,   │
      │              rpMin,rpMax,change)       │
      │                                        │
      │ ^Gaia.DataI("Change",change,sourceId)  │
      │  = ""                                   │
      └────────────────┬───────────────────────┘
                       │
                       ▼
      ┌──────────────────────────────────────────┐
      │ USER> select * from ^Gaia.DataD         │
      │ (Results displayed)                     │
      └──────────────────────────────────────────┘
```

---

## Flow 2: Rust Processor (High Performance)

```
┌──────────────────────────────────────────────────┐
│ $ cd src/rust                                    │
│ $ cargo build --release                          │
│ $ cp target/release/gaia_engine /opt/gaia/      │
│   build/rust/                                    │
└─────────────────────┬──────────────────────────┘
                      │
                      ▼
         ┌─────────────────────────────┐
         │ Binary compiled to:         │
         │ build/rust/gaia-engine      │
         │ ~2-5MB executable           │
         └─────────────────┬───────────┘
                           │
                           ▼
         ┌──────────────────────────────────────┐
         │ $ docker compose exec iris iris      │
         │   session iris                       │
         │ USER> do ^RunScript                  │
         │ (with RunRust() uncommented)         │
         └──────────────────┬───────────────────┘
                            │
                            ▼
         ┌──────────────────────────────────────────┐
         │ Gaia.RustProcessor.Run()                │
         │ ├─ Locate build/rust/gaia-engine       │
         │ ├─ Execute: gaia-engine file threshold │
         │ ├─ Consume CSV output                  │
         │ └─ Store in ^Gaia.DataD               │
         └──────────────────┬─────────────────────┘
                            │
                            ▼
         ┌──────────────────────────────────────────┐
         │ Results in globals (same format)        │
         │ Typically 5-10x faster than ObjectScript│
         └──────────────────────────────────────────┘
```

---

## Flow 3: APL Processor (Code Golf)

```
┌──────────────────────────────────────────────────────┐
│ $ dyalogscript src/apl/gaia.apl input.csv output.csv│
│   100                                                │
└─────────────────────┬────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────────────────┐
         │ gaia.apl (128 chars, pure APL)     │
         │ ├─ Parse CSV                       │
         │ ├─ Group by source_id              │
         │ ├─ Calculate min/max per group     │
         │ ├─ Calculate % change              │
         │ ├─ Filter by threshold             │
         │ └─ Write CSV output                │
         └────────────────┬───────────────────┘
                          │
                          ▼
         ┌────────────────────────────────────┐
         │ CSV Output File:                   │
         │ /data/out/results.csv              │
         │                                    │
         │ source_id,ra,dec,min,max,change    │
         │ 123,10.1,-20.2,12.4,30.2,144.32    │
         │ ...                                │
         └────────────────────────────────────┘
```

---

## Flow 4: Service API (Dispatcher Pattern)

```
Gaia.Service.Process(engine, file, threshold)
         │
         ├─────────────────┬─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
Gaia.Engine.Run() dispatcher routes to:
         │
         ├─ "objectscript" ──→ Gaia.ObjectScriptProcessor.Run()
         │
         ├─ "rust" ──────────→ Gaia.RustProcessor.Run()
         │
         └─ "apl" ───────────→ Gaia.APLProcessor.Run()

All processors implement same interface:
  ClassMethod Run(inputFile As %String, threshold As %Numeric)
```

Usage:
```objectscript
do ##class(Gaia.Service).Process("objectscript", "/data/in/sample.csv", 100)
do ##class(Gaia.Service).Process("rust", "/data/in/sample.csv", 100)
do ##class(Gaia.Service).Process("apl", "/data/in/sample.csv", 100)
```

---

## Flow 5: Complete Test Suite

```
┌────────────────────────────────────────┐
│ bash test-suite.sh [mode]              │
│ Modes: objectscript|rust|apl|all       │
└──────────────┬─────────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
    ▼          ▼          ▼
objectscript  rust       apl
    │          │          │
    ├──────────┤          │
    │          │          │
    ▼          ▼          ▼
[Runs Each]  [Builds]   [Shell Call]
    │          │          │
    ├──────────┼──────────┤
    │          │          │
    ▼          ▼          ▼
[Times]    [Times]    [Times]
    │          │          │
    └──────────┴──────────┘
             │
             ▼
   [Compare Performance]
   [View Results]
```

---

## Data Flow: Input to Output

```
CSV Input File
│
│ source_id,ra,dec,bp_flux,rp_flux
│ 123,10.1,-20.2,"[12.4;15.1;...","[11.2;14.8;...]"
│
├─────────────────────────────────┐
│ Processor (ObjectScript/Rust)   │
│ ├─ Parse row                    │
│ ├─ Extract flux arrays          │
│ ├─ Find min/max of each         │
│ ├─ Skip if NaN                  │
│ ├─ Calculate % change           │
│ └─ Filter by threshold          │
└─────────┬───────────────────────┘
          │
          ├─ Match: 123, 10.1, -20.2, 12.4, 30.2, 11.2, 29.1, 144.32
          │
          ▼
Global Storage:
│
├─ ^Gaia.DataD("123") = $ListBuild("123", 10.1, -20.2, 12.4, 30.2, 11.2, 29.1, 144.32)
├─ ^Gaia.DataI("Change", 144.32, "123") = ""
│
└─ Indexed for sorting by variability %

Query Results:
│
├─ select * from ^Gaia.DataD
├─ select * where ^Gaia.DataI("Change",...) for sorting
├─ Export to CSV output file
│
└─ ✓ Complete
```

---

## Files Read by Each Processor

### ObjectScript
```
Input:
  /data/in/sample.csv

Output:
  ^Gaia.DataD global
  ^Gaia.DataI index

No disk output (results in memory/storage)
```

### Rust
```
Input:
  /data/in/sample.csv

Output:
  stdout (CSV format)
  OR file (if implemented)

Typically piped/captured by caller
```

### APL
```
Input:
  /data/in/sample.csv

Output:
  /data/out/results.csv (file)

Direct file output
```

---

## Decision Tree: Which Processor to Use

```
        START
         │
         ▼
    Need fastest?
    ├─ YES ──→ Rust (compile binary first)
    └─ NO ──────┐
               │
               ▼
        Need no external tools?
        ├─ YES ──→ ObjectScript (pure IRIS)
        └─ NO ──────┐
                   │
                   ▼
           Want code golf example?
           ├─ YES ──→ APL (128 chars)
           └─ NO ──→ ObjectScript
```

---

## Benchmark Comparison Template

```
Processor      | Time (sec) | Records | Throughput    | Notes
───────────────┼────────────┼─────────┼───────────────┼──────────────
ObjectScript   | 1.2        | 10,000  | 8,333 rec/sec | No dependencies
Rust           | 0.2        | 10,000  | 50,000 rec/s  | 6x faster
APL            | 3.4        | 10,000  | 2,941 rec/sec | Educational
```

---

## Error Handling Flow

```
Processor.Run(file, threshold)
  │
  ├─ File not found?
  │  └─ Return ERROR status
  │
  ├─ Invalid CSV format?
  │  └─ Skip malformed rows
  │
  ├─ All NaN values?
  │  └─ Skip row (pMin=0, pMax=0)
  │
  ├─ Threshold parameter invalid?
  │  └─ Use default (100%)
  │
  ├─ Division by zero risk?
  │  └─ Already guarded
  │
  └─ SUCCESS
```

---

## Docker Container Layout

```
/opt/gaia/
├── src/
│   ├── iris/
│   │   ├── cls/Gaia/*.cls
│   │   ├── REST/GaiaAPI.cls
│   │   └── SQL/schema.sql
│   ├── rust/
│   │   ├── Cargo.toml
│   │   └── src/main.rs
│   ├── apl/
│   │   └── gaia.apl
│   └── RunScript.mac ← JUDGES RUN THIS
│
├── build/
│   └── rust/
│       └── gaia-engine ← COMPILED BINARY
│
├── data/
│   ├── in/ ← INPUT CSV FILES HERE
│   └── out/ ← OUTPUT FILES HERE
│
└── README.md, JUDGES.md, etc.
```

---

**All flows converge to: Results in globals or CSV files, queryable and comparable.**
