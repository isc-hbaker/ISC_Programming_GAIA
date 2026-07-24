Class Gaia.RustProcessor Extends %RegisteredObject
{

/// Shells out to the gaia_engine binary for a single input file.
/// Results accumulate in ^Gaia.DataD / ^Gaia.DataI globals.
/// Set pClearFirst=0 when calling in a batch so prior results are preserved.
ClassMethod Run(
    inputFile As %String,
    threshold As %Numeric = 100,
    pClearFirst As %Boolean = 1
) As %Status
{
    Set tSC = $$$OK, startTime = $ZH

    Set binary = ""
    For candidate = "/home/irisowner/dev/build/rust/gaia_engine",
                    "/opt/gaia/build/rust/gaia_engine" {
        If ##class(%File).Exists(candidate) { Set binary = candidate  Quit }
    }
    If binary = "" Quit $$$ERROR($$$GeneralError, "gaia_engine not found. Build: cd src/rust && cargo build --release")

    Set outputFile = "/tmp/gaia_rust_" _ $Job _ ".csv"

    Try {
        Set rc = $ZF(-1, binary _ " """ _ inputFile _ """ " _ threshold _ " """ _ outputFile _ """")
        If rc '= 0 {
            Set tSC = $$$ERROR($$$GeneralError, "gaia_engine exited: " _ rc)
            Quit
        }
        If '##class(%File).Exists(outputFile) {
            Set tSC = $$$ERROR($$$GeneralError, "gaia_engine produced no output")
            Quit
        }

        If pClearFirst Kill ^Gaia.DataD, ^Gaia.DataI

        Set stream = ##class(%Stream.FileCharacter).%New()
        Set tSC = stream.LinkToFile(outputFile)
        If $$$ISERR(tSC) Quit
        Do stream.ReadLine()  // skip header

        Set outputCount = 0
        While 'stream.AtEnd {
            Set line = stream.ReadLine()  Continue:line=""
            // Rust outputs 6 columns: source_id,bp_min,bp_max,rp_min,rp_max,variability_percent
            Set sourceId = $Piece(line, ",", 1)  Continue:sourceId=""
            Set outputCount = outputCount + 1
            Set ^Gaia.DataD(sourceId) = $LB(sourceId, $P(line,",",2), $P(line,",",3), $P(line,",",4), $P(line,",",5), $P(line,",",6))
            Set ^Gaia.DataI("Change", $P(line,",",6), sourceId) = ""
        }

    } Catch ex {
        Set tSC = ex.AsStatus()
    }

    Do ##class(%File).Delete(outputFile)
    Write !,"  ", inputFile, " -> Rust complete (", $FNumber($ZH-startTime,"F",2), "s)"
    Quit tSC
}

}
