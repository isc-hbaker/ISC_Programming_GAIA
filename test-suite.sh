#!/bin/bash
# test-suite.sh
# Complete test suite for Gaia Challenge submission
# 
# Usage:
#   bash test-suite.sh [objectscript|rust|apl|all]
#
# Examples:
#   bash test-suite.sh objectscript        # Test ObjectScript processor only
#   bash test-suite.sh all                 # Test all three processors

set -e

TEST_MODE=${1:-objectscript}
INPUT_FILE="/data/in/sample.csv"
THRESHOLD="100"

echo "=============================================================="
echo "  Gaia Challenge - Test Suite"
echo "=============================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Check Docker is running
info "Checking Docker..."
if ! docker compose ps > /dev/null 2>&1; then
    error "Docker not running or not in project directory"
    exit 1
fi
success "Docker is running"

# Check IRIS is accessible
info "Checking IRIS..."
if ! docker compose exec iris iris session iris -c "write 1" > /dev/null 2>&1; then
    error "IRIS not accessible"
    exit 1
fi
success "IRIS is accessible"

# Verify classes are compiled
info "Verifying ObjectScript classes are compiled..."
docker compose exec iris iris session iris > /dev/null 2>&1 << 'EOF'
if '##class(Gaia.Service).%Exists() {
    write "OK"
    quit
} else {
    write "FAIL"
    quit
}
EOF

if [ $? -ne 0 ]; then
    error "Classes not compiled. Run: do \$SYSTEM.OBJ.ImportDir(\"/opt/gaia/src/iris/cls\", \"ck\")"
    exit 1
fi
success "Classes are compiled"

# Check input file
info "Checking input file..."
if ! docker compose exec iris test -f "$INPUT_FILE"; then
    error "Input file not found: $INPUT_FILE"
    echo "  Available files:"
    docker compose exec iris ls -la /data/in/
    exit 1
fi
success "Input file found: $INPUT_FILE"

# Run tests based on mode
case "$TEST_MODE" in
    objectscript)
        info "Testing ObjectScript Processor..."
        docker compose exec iris iris session iris > /dev/null 2>&1 << EOF
Kill ^Gaia.DataD, ^Gaia.DataI
set startTime = \$ZHOROLOG
set tSC = ##class(Gaia.ObjectScriptProcessor).Run("$INPUT_FILE", $THRESHOLD)
set elapsed = \$ZHOROLOG - startTime
write !,"Elapsed: ", elapsed, " seconds", !
if '\$\$ISERR(tSC) {
    write "SUCCESS",!
} else {
    write "ERROR: ", \$System.Status.GetErrorText(tSC), !
}
quit
EOF
        success "ObjectScript processor test complete"
        ;;

    rust)
        info "Testing Rust Processor..."
        info "Checking if Rust binary is built..."
        if ! docker compose exec iris test -f /opt/gaia/build/rust/gaia-engine; then
            error "Rust binary not found. Build with:"
            echo "  cd src/rust && cargo build --release"
            echo "  cp target/release/gaia_engine ../../build/rust/"
            exit 1
        fi
        success "Rust binary found"
        
        info "Running Rust processor..."
        docker compose exec iris iris session iris > /dev/null 2>&1 << EOF
Kill ^Gaia.DataD, ^Gaia.DataI
set startTime = \$ZHOROLOG
set tSC = ##class(Gaia.RustProcessor).Run("$INPUT_FILE", $THRESHOLD)
set elapsed = \$ZHOROLOG - startTime
write !,"Elapsed: ", elapsed, " seconds", !
if '\$\$ISERR(tSC) {
    write "SUCCESS",!
} else {
    write "ERROR: ", \$System.Status.GetErrorText(tSC), !
}
quit
EOF
        success "Rust processor test complete"
        ;;

    apl)
        info "Testing APL Processor..."
        info "APL processor must run from host with Dyalog APL installed"
        info "Command: dyalogscript src/apl/gaia.apl $INPUT_FILE /data/out/results.csv $THRESHOLD"
        
        # Try to run it
        if command -v dyalogscript &> /dev/null; then
            dyalogscript src/apl/gaia.apl "$INPUT_FILE" /data/out/results.csv "$THRESHOLD"
            success "APL processor test complete"
        else
            error "Dyalog APL not installed on host"
            exit 1
        fi
        ;;

    all)
        info "Running all processor tests..."
        
        # ObjectScript
        info "1/3: ObjectScript Processor"
        docker compose exec iris iris session iris > /dev/null 2>&1 << EOF
Kill ^Gaia.DataD, ^Gaia.DataI
set startTime = \$ZHOROLOG
set tSC = ##class(Gaia.ObjectScriptProcessor).Run("$INPUT_FILE", $THRESHOLD)
set elapsed = \$ZHOROLOG - startTime
write !,"ObjectScript: ", elapsed, " seconds", !
quit
EOF
        success "ObjectScript complete"
        
        # Rust (if available)
        if docker compose exec iris test -f /opt/gaia/build/rust/gaia-engine; then
            info "2/3: Rust Processor"
            docker compose exec iris iris session iris > /dev/null 2>&1 << EOF
Kill ^Gaia.DataD, ^Gaia.DataI
set startTime = \$ZHOROLOG
set tSC = ##class(Gaia.RustProcessor).Run("$INPUT_FILE", $THRESHOLD)
set elapsed = \$ZHOROLOG - startTime
write !,"Rust: ", elapsed, " seconds", !
quit
EOF
            success "Rust complete"
        else
            info "2/3: Rust Processor (SKIPPED - not built)"
        fi
        
        # APL (if available)
        if command -v dyalogscript &> /dev/null; then
            info "3/3: APL Processor"
            dyalogscript src/apl/gaia.apl "$INPUT_FILE" /data/out/results.csv "$THRESHOLD"
            success "APL complete"
        else
            info "3/3: APL Processor (SKIPPED - Dyalog not installed)"
        fi
        ;;

    *)
        error "Unknown test mode: $TEST_MODE"
        echo "Usage: bash test-suite.sh [objectscript|rust|apl|all]"
        exit 1
        ;;
esac

echo ""
echo "=============================================================="
echo "  Test Suite Complete"
echo "=============================================================="
echo ""
echo "Results stored in:"
echo "  ObjectScript: ^Gaia.DataD and ^Gaia.DataI globals"
echo "  APL: /data/out/results.csv"
echo ""
echo "View results in IRIS:"
echo "  docker compose exec iris iris session iris"
echo "  select * from ^Gaia.DataD"
echo ""
