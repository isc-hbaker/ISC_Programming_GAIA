Class Gaia.APLProcessor Extends %RegisteredObject
{

/// APL (Dyalog) code-golf processor. Shells out to dyalogscript, reads CSV
/// output, and persists results to ^Gaia.DataD / ^Gaia.DataI globals.
/// Requires dyalogscript on PATH inside the container.
ClassMethod Run(
    inputFile As %String,
    threshold As %Numeric = 100
) As %Status
{
    Set tSC = $$$OK
    Set startTime = $ZH

    Write !,"========================================================="
    Write !," Starting APL Code-Golf Gaia Processor"
    Write !," Input: ", inputFile
    Write !," Threshold: ", threshold, "%"
    Write !,"========================================================="

    Set aplScript = "/app/src/apl/gaia.apl"
    If '##class(%File).Exists(aplScript) {
        Set aplScript = "/ISC_Programming_GAIA/src/apl/gaia.apl"
    }
    If '##class(%File).Exists(aplScript) {
        Quit $$$ERROR($$$GeneralError, "gaia.apl not found at: " _ aplScript)
    }

    Set outputFile = "/tmp/gaia_apl_out_" _ $Job _ ".csv"

    Try {
        Set cmd = "dyalogscript """ _ aplScript _ """ """
                  _ inputFile _ """ """ _ outputFile _ """ " _ threshold
        Set rc = $ZF(-1, cmd)
        If rc '= 0 {
            Set tSC = $$$ERROR($$$GeneralError, "dyalogscript exited with code: " _ rc)
            Quit
        }

        If '##class(%File).Exists(outputFile) {
            Set tSC = $$$ERROR($$$GeneralError, "APL processor produced no output file")
            Quit
        }

        Kill ^Gaia.DataD, ^Gaia.DataI

        Set stream = ##class(%Stream.FileCharacter).%New()
        Set tSC = stream.LinkToFile(outputFile)
        If $$$ISERR(tSC) Quit

        Set outputCount = 0
        While 'stream.AtEnd {
            Set line = stream.ReadLine()
            Continue:line=""

            // APL output columns: source_id,ra,dec,min,max,pct_change
            Set sourceId    = $Piece(line, ",", 1)
            Set ra          = $Piece(line, ",", 2)
            Set dec         = $Piece(line, ",", 3)
            Set fluxMin     = $Piece(line, ",", 4)
            Set fluxMax     = $Piece(line, ",", 5)
            Set variability = $Piece(line, ",", 6)

            Continue:sourceId=""

            Set outputCount = outputCount + 1
            Set ^Gaia.DataD(sourceId) = $ListBuild(sourceId, ra, dec, fluxMin, fluxMax, "", "", variability)
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
