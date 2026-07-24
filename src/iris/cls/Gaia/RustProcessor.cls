Class Gaia.RustProcessor Extends %RegisteredObject
{

/// High-performance Rust processor. Shells out to the gaia_engine binary,
/// reads its CSV output, and persists results to ^Gaia.DataD / ^Gaia.DataI.
ClassMethod Run(
    inputFile As %String,
    threshold As %Numeric = 100
) As %Status
{
    Set tSC = $$$OK
    Set startTime = $ZH

    Write !,"========================================================="
    Write !," Starting High-Performance Rust Gaia Processor"
    Write !," Input: ", inputFile
    Write !," Threshold: ", threshold, "%"
    Write !,"========================================================="

    // Locate binary - check build path then compiled target path
    Set binary = ""
    For candidate = "/home/irisowner/dev/build/rust/gaia_engine",
                    "/opt/gaia/build/rust/gaia_engine",
                    "/opt/gaia/src/rust/target/release/gaia_engine" {
        If ##class(%File).Exists(candidate) {
            Set binary = candidate
            Quit
        }
    }
    If binary = "" {
        Quit $$$ERROR($$$GeneralError,
            "gaia_engine binary not found. Run: cd src/rust && cargo build --release")
    }

    Set outputFile = "/tmp/gaia_rust_out_" _ $Job _ ".csv"

    Try {
        Set cmd = binary _ " """ _ inputFile _ """ " _ threshold _ " """ _ outputFile _ """"
        Set rc = $ZF(-1, cmd)
        If rc '= 0 {
            Set tSC = $$$ERROR($$$GeneralError, "gaia_engine exited with code: " _ rc)
            Quit
        }

        If '##class(%File).Exists(outputFile) {
            Set tSC = $$$ERROR($$$GeneralError, "gaia_engine produced no output file")
            Quit
        }

        // Clear previous results
        Kill ^Gaia.DataD, ^Gaia.DataI

        Set stream = ##class(%Stream.FileCharacter).%New()
        Set tSC = stream.LinkToFile(outputFile)
        If $$$ISERR(tSC) Quit

        // Skip CSV header
        Do stream.ReadLine()

        Set outputCount = 0
        While 'stream.AtEnd {
            Set line = stream.ReadLine()
            Continue:line=""

            // CSV columns: source_id,ra,dec,bp_min,bp_max,rp_min,rp_max,variability_percent
            Set sourceId    = $Piece(line, ",", 1)
            Set ra          = $Piece(line, ",", 2)
            Set dec         = $Piece(line, ",", 3)
            Set bpMin       = $Piece(line, ",", 4)
            Set bpMax       = $Piece(line, ",", 5)
            Set rpMin       = $Piece(line, ",", 6)
            Set rpMax       = $Piece(line, ",", 7)
            Set variability = $Piece(line, ",", 8)

            Continue:sourceId=""

            Set outputCount = outputCount + 1
            Set ^Gaia.DataD(sourceId) = $ListBuild(sourceId, ra, dec, bpMin, bpMax, rpMin, rpMax, variability)
            Set ^Gaia.DataI("Change", variability, sourceId) = ""
        }

    } Catch ex {
        Set tSC = ex.AsStatus()
    }

    Do ##class(%File).Delete(outputFile)

    Set elapsed = $ZH - startTime
    Write !,"========================================================="
    Write !," Complete. ", outputCount, " results persisted to globals."
    Write !," Time: ", $FNumber(elapsed, "F", 3), " seconds."
    Write !,"========================================================="

    Quit tSC
}

}