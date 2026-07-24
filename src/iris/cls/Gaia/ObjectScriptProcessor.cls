Class Gaia.ObjectScriptProcessor Extends %RegisteredObject
{

/// Pure ObjectScript processor matching Engine.Run() contract
/// Processes single input CSV file and persists results to globals
ClassMethod Run(
    pInputFile As %String,
    pThreshold As %Numeric = 100
) As %Status
{
    Set tSC = $$$OK
    Set startTime = $ZH

    Write !,"========================================================="
    Write !," Starting Pure ObjectScript Native Gaia Processor"
    Write !," Input: ", pInputFile
    Write !," Threshold: ", pThreshold, "%"
    Write !,"========================================================="

    // Clear previous results
    Kill ^Gaia.DataD, ^Gaia.DataI

    Try {
        // Decompress .gz input to a temp file if needed
        Set actualFile = pInputFile
        Set tmpFile = ""
        If ($ZCONVERT($E(pInputFile, *-2, *), "L") = ".gz") {
            Set tmpFile = "/tmp/gaia_input_" _ $Job _ ".csv"
            Set cmd = "gunzip -c """ _ pInputFile _ """ > """ _ tmpFile _ """"
            Set rc = $ZF(-1, cmd)
            If rc '= 0 {
                Set tSC = $$$ERROR($$$GeneralError, "gunzip failed for: " _ pInputFile)
                Quit
            }
            Set actualFile = tmpFile
        }

        Set stream = ##class(%Stream.FileCharacter).%New()
        Set tSC = stream.LinkToFile(actualFile)
        If $$$ISERR(tSC) Quit

        // Skip CSV header line
        Set header = stream.ReadLine()

        Set recordCount = 0
        Set outputCount = 0

        While 'stream.AtEnd {
            Set line = stream.ReadLine()
            Continue:line=""

            Set recordCount = recordCount + 1

            // Extract standard Gaia DR3 columns:
            // Piece 1: source_id, Piece 2: ra, Piece 3: dec, Piece 4: bp_flux array, Piece 5: rp_flux array
            Set sourceId = $Piece(line, ",", 1)
            Continue:sourceId=""

            Set ra = $Piece(line, ",", 2)
            Set dec = $Piece(line, ",", 3)
            Set bpRaw = $Piece(line, ",", 4)
            Set rpRaw = $Piece(line, ",", 5)

            // Calculate min/max for BP and RP bands
            Do ..ExtractMinMax(bpRaw, .bpMin, .bpMax)
            Do ..ExtractMinMax(rpRaw, .rpMin, .rpMax)

            // Skip rows where all flux values are NaN/invalid
            If (bpMin = 0 && bpMax = 0) || (rpMin = 0 && rpMax = 0) {
                Continue
            }

            // Percentage change formula: ((max - min) / min) * 100
            Set bpChange = 0, rpChange = 0
            If (bpMin > 0) && (bpMax > bpMin) {
                Set bpChange = ((bpMax - bpMin) / bpMin) * 100
            }
            If (rpMin > 0) && (rpMax > rpMin) {
                Set rpChange = ((rpMax - rpMin) / rpMin) * 100
            }

            // Determine maximum variability between BP and RP bands
            Set maxPctChange = $Select(bpChange > rpChange: bpChange, 1: rpChange)

            // Keep and store only variable objects meeting threshold
            If maxPctChange >= pThreshold {
                Set outputCount = outputCount + 1
                // Direct Global Persistence for maximum throughput
                Set ^Gaia.DataD(sourceId) = $ListBuild(sourceId, ra, dec, bpMin, bpMax, rpMin, rpMax, maxPctChange)
                Set ^Gaia.DataI("Change", maxPctChange, sourceId) = ""
            }
        }

    } Catch ex {
        Set tSC = ex.AsStatus()
    }

    // Clean up temp decompressed file
    If tmpFile '= "" {
        Do ##class(%File).Delete(tmpFile)
    }

    Set elapsed = $ZH - startTime
    Write !,"========================================================="
    Write !," Complete. Processed ", recordCount, " records, ", outputCount, " matched."
    Write !," Time: ", $FNumber(elapsed, "F", 3), " seconds."
    Write !,"========================================================="

    Quit tSC
}


/// Helper: parse array strings like "[12.4; 15.1; NaN; 30.2]"
/// Ignores NaN, empty, null, and non-positive (<= 0) flux values
/// Returns (0, 0) if all values invalid - caller skips rows with both 0
ClassMethod ExtractMinMax(pRawArray As %String, Output pMin As %Float, Output pMax As %Float) [ Private ]
{
    Set pMin = 999999999999, pMax = -999999999999
    
    // Strip brackets, quotes, and spaces
    Set clean = $Translate(pRawArray, "[]"" ", "")
    Set len = $Length(clean, ";")

    For i = 1:1:len {
        Set val = $Piece(clean, ";", i)
        
        // Skip missing, null, NaN, or non-positive flux values
        Continue:(val = "") || (val = "NaN") || ('$IsValidNum(val)) || (val <= 0)

        If val < pMin Set pMin = val
        If val > pMax Set pMax = val
    }

    // Return 0 for both min/max if all values were invalid (will be skipped by caller)
    If pMin = 999999999999 Set pMin = 0
    If pMax = -999999999999 Set pMax = 0
}

}