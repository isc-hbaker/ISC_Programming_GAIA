/// Gaia DR3 variable star detector - pure ObjectScript implementation.
///
/// Working with ObjectScript for this challenge was a genuinely good fit. The global
/// storage model (^Gaia.DataD, ^Gaia.DataI) maps naturally to the problem: fast writes
/// during the scan, then a single ordered read to produce the CSV. No ORM, no schema
/// migrations, just direct key-value persistence with a free index global for sorting.
///
/// The main challenge was parsing the ECSV format: quoted fields containing comma-separated
/// arrays, with #comment lines before the header. ObjectScript's $Extract loop handles the
/// quote-aware field extraction reliably, and $ZF(-1) with gunzip handles decompression.
/// For throughput on 20 files, the Rust engine is preferred; ObjectScript is the pure-IRIS fallback.
Class Gaia.ObjectScriptProcessor Extends %RegisteredObject
{

// Column indices in the Gaia DR3 epoch photometry CSV (1-based)
Parameter SOURCE_ID_COL = 2;
Parameter BP_FLUX_COL   = 12;
Parameter RP_FLUX_COL   = 17;

/// Processes a single .csv or .csv.gz input file.
/// Results accumulate in ^Gaia.DataD / ^Gaia.DataI globals.
/// Set pClearFirst=0 when calling in a batch so prior results are preserved.
ClassMethod Run(
    pInputFile As %String,
    pThreshold As %Numeric = 100,
    pClearFirst As %Boolean = 1
) As %Status
{
    Set tSC = $$$OK
    Set startTime = $ZH

    If pClearFirst Kill ^Gaia.DataD, ^Gaia.DataI

    Try {
        // Decompress .gz to temp file if needed
        Set actualFile = pInputFile, tmpFile = ""
        If ($ZCONVERT($E(pInputFile, *-2, *), "L") = ".gz") {
            Set tmpFile = "/tmp/gaia_" _ $Job _ ".csv"
            If $ZF(-1, "gunzip -c """ _ pInputFile _ """ > """ _ tmpFile _ """") '= 0 {
                Set tSC = $$$ERROR($$$GeneralError, "gunzip failed: " _ pInputFile)
                Quit
            }
            Set actualFile = tmpFile
        }

        Set stream = ##class(%Stream.FileCharacter).%New()
        Set tSC = stream.LinkToFile(actualFile)
        If $$$ISERR(tSC) Quit

        // Skip ECSV comment lines (start with #) and the header row
        Set line = ""
        While 'stream.AtEnd {
            Set line = stream.ReadLine()
            Continue:$Extract(line,1)="#"
            // First non-comment line is the header — skip it and stop
            Quit
        }

        Set recordCount = 0, outputCount = 0

        While 'stream.AtEnd {
            Set line = stream.ReadLine()
            Continue:line=""
            Set recordCount = recordCount + 1

            Set sourceId = ..GetField(line, ..#SOURCE_ID_COL)
            Continue:sourceId=""

            Set bpRaw = ..GetField(line, ..#BP_FLUX_COL)
            Set rpRaw = ..GetField(line, ..#RP_FLUX_COL)

            Do ..ExtractMinMax(bpRaw, .bpMin, .bpMax)
            Do ..ExtractMinMax(rpRaw, .rpMin, .rpMax)

            // Skip objects with no valid flux in either band
            If (bpMin = 0 && bpMax = 0) || (rpMin = 0 && rpMax = 0) Continue

            // Percentage change = ((max - min) / min) * 100
            Set bpChange = 0, rpChange = 0
            If bpMin > 0 Set bpChange = ((bpMax - bpMin) / bpMin) * 100
            If rpMin > 0 Set rpChange = ((rpMax - rpMin) / rpMin) * 100

            Set maxPctChange = $Select(bpChange > rpChange: bpChange, 1: rpChange)

            If maxPctChange >= pThreshold {
                Set outputCount = outputCount + 1
                Set ^Gaia.DataD(sourceId) = $LB(sourceId, bpMin, bpMax, rpMin, rpMax, maxPctChange)
                Set ^Gaia.DataI("Change", maxPctChange, sourceId) = ""
            }
        }

    } Catch ex {
        Set tSC = ex.AsStatus()
    }

    If tmpFile '= "" Do ##class(%File).Delete(tmpFile)

    Write !,"  ", pInputFile, " -> ", outputCount, " matches (", recordCount, " records, ", $FNumber($ZH-startTime,"F",2), "s)"
    Quit tSC
}

/// Writes accumulated globals to the required output CSV.
ClassMethod WriteCSV(pOutputFile As %String) As %Status
{
    Do ##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(pOutputFile))

    Set stream = ##class(%Stream.FileCharacter).%New()
    Set tSC = stream.LinkToFile(pOutputFile)
    If $$$ISERR(tSC) Quit tSC

    Do stream.WriteLine("source_id,bp_min_flux,bp_max_flux,rp_min_flux,rp_max_flux,percentage_change")

    Set sourceId = ""
    For {
        Set sourceId = $Order(^Gaia.DataD(sourceId))
        Quit:sourceId=""
        Set row = ^Gaia.DataD(sourceId)
        Do stream.WriteLine($LG(row,1)_","_$LG(row,2)_","_$LG(row,3)_","_$LG(row,4)_","_$LG(row,5)_","_$LG(row,6))
    }

    Quit stream.%Save()
}

/// Extracts the Nth field (1-based) from a quoted CSV line.
/// Handles quoted fields that contain commas.
ClassMethod GetField(line As %String, n As %Integer) As %String [ Private ]
{
    Set fieldNum = 0, inQuote = 0, start = 1
    Set len = $Length(line)

    For i = 1:1:len {
        Set ch = $Extract(line, i)
        If ch = """" {
            Set inQuote = 'inQuote
        } ElseIf (ch = ",") && ('inQuote) {
            Set fieldNum = fieldNum + 1
            If fieldNum = n {
                Set result = $Extract(line, start, i-1)
                If $Extract(result,1) = """" Set result = $Extract(result, 2, $Length(result)-1)
                Quit
            }
            Set start = i + 1
        }
    }

    // Last field
    If fieldNum + 1 = n {
        Set result = $Extract(line, start, len)
        If $Extract(result,1) = """" Set result = $Extract(result, 2, $Length(result)-1)
    }

    Quit $Get(result, "")
}

/// Parses "[val,val,NaN,...]" returning valid min/max.
/// Returns (0,0) if all values are invalid.
ClassMethod ExtractMinMax(pRaw As %String, Output pMin As %Float, Output pMax As %Float) [ Private ]
{
    Set pMin = 1e15, pMax = -1e15
    // Strip outer brackets
    Set clean = $Translate(pRaw, "[]", "")
    For i = 1:1:$Length(clean, ",") {
        Set val = $ZStrip($Piece(clean, ",", i), "<>W")
        Continue:(val = "") || (val = "NaN") || ('$IsValidNum(val)) || (val <= 0)
        If val < pMin Set pMin = val
        If val > pMax Set pMax = val
    }
    If pMin = 1e15  Set pMin = 0
    If pMax = -1e15 Set pMax = 0
}

}
