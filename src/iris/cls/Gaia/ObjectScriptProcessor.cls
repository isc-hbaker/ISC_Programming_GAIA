/// Gaia DR3 variable star detector - pure ObjectScript implementation.
///
/// Working with ObjectScript for this challenge was a genuinely good fit. The global
/// storage model (^Gaia.DataD, ^Gaia.DataI) maps naturally to the problem: fast writes
/// during the scan, then a single ordered read to produce the CSV. No ORM, no schema
/// migrations, just direct key-value persistence with a free index global for sorting.
///
/// The main challenge was parsing the ECSV format: 48 columns, quoted fields containing
/// comma-separated arrays, with # comment lines before the header. The Rust engine handles
/// the heavy parsing work with parallel processing; this class provides the pure-IRIS
/// fallback and the final CSV output step.
Class Gaia.ObjectScriptProcessor Extends %RegisteredObject
{

/// Processes a single .csv or .csv.gz file using pure ObjectScript.
/// Set pClearFirst=0 when calling in a batch to preserve prior results.
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
        Set actualFile = pInputFile
        Set tmpFile = ""
        If ($ZCONVERT($Extract(pInputFile, *-2, *), "L") = ".gz") {
            Set tmpFile = "/tmp/gaia_" _ $Job _ ".csv"
            Set q = $Char(34)
            Set rc = $ZF(-1, "gunzip -c " _ q _ pInputFile _ q _ " > " _ q _ tmpFile _ q)
            If rc '= 0 {
                Set tSC = $$$ERROR($$$GeneralError, "gunzip failed: " _ pInputFile)
                Quit
            }
            Set actualFile = tmpFile
        }

        Set stream = ##class(%Stream.FileCharacter).%New()
        Set tSC = stream.LinkToFile(actualFile)
        If $$$ISERR(tSC) Quit

        // Skip ECSV # comment lines, then skip the header row
        While 'stream.AtEnd {
            Set line = stream.ReadLine()
            If $Extract(line, 1) '= "#" Quit
        }

        Set recordCount = 0
        Set outputCount = 0

        While 'stream.AtEnd {
            Set line = stream.ReadLine()
            If line = "" Continue
            Set recordCount = recordCount + 1

            // source_id=col 2, bp_flux=col 12, rp_flux=col 17
            Set sourceId = ..GetField(line, 2)
            If sourceId = "" Continue

            Set bpRaw = ..GetField(line, 12)
            Set rpRaw = ..GetField(line, 17)

            Do ..ExtractMinMax(bpRaw, .bpMin, .bpMax)
            Do ..ExtractMinMax(rpRaw, .rpMin, .rpMax)

            If (bpMin = 0) && (bpMax = 0) Continue
            If (rpMin = 0) && (rpMax = 0) Continue

            Set bpChange = 0
            Set rpChange = 0
            If bpMin > 0 Set bpChange = ((bpMax - bpMin) / bpMin) * 100
            If rpMin > 0 Set rpChange = ((rpMax - rpMin) / rpMin) * 100

            Set maxPct = $Select(bpChange > rpChange: bpChange, 1: rpChange)

            If maxPct >= pThreshold {
                Set outputCount = outputCount + 1
                Set ^Gaia.DataD(sourceId) = $ListBuild(sourceId, bpMin, bpMax, rpMin, rpMax, maxPct)
                Set ^Gaia.DataI("Change", maxPct, sourceId) = ""
            }
        }

    } Catch ex {
        Set tSC = ex.AsStatus()
    }

    If tmpFile '= "" Do ##class(%File).Delete(tmpFile)

    Write !,"  ObjectScript: ", outputCount, " matches / ", recordCount, " records (", $FNumber($ZH - startTime, "F", 2), "s)"
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

    Set key = ""
    For {
        Set key = $Order(^Gaia.DataD(key))
        If key = "" Quit
        Set row = ^Gaia.DataD(key)
        Do stream.WriteLine(
            $ListGet(row, 1) _ "," _
            $ListGet(row, 2) _ "," _
            $ListGet(row, 3) _ "," _
            $ListGet(row, 4) _ "," _
            $ListGet(row, 5) _ "," _
            $ListGet(row, 6))
    }

    Quit stream.%Save()
}

/// Extracts the Nth field (1-based) from a quoted CSV line.
ClassMethod GetField(line As %String, n As %Integer) As %String [ Private ]
{
    Set fieldNum = 0, inQuote = 0, start = 1, result = ""
    Set len = $Length(line)
    Set dq = $Char(34)
    For i = 1:1:len {
        Set ch = $Extract(line, i)
        If ch = dq {
            Set inQuote = 'inQuote
            Continue
        }
        If ch '= "," Continue
        If inQuote Continue
        Set fieldNum = fieldNum + 1
        If fieldNum = n {
            Set result = $Extract(line, start, i - 1)
            Quit
        }
        Set start = i + 1
    }
    If (result = "") && (fieldNum + 1 = n) {
        Set result = $Extract(line, start, len)
    }
    If $Extract(result, 1) = dq {
        Set result = $Extract(result, 2, $Length(result) - 1)
    }
    Quit result
}

/// Parses "[v,v,NaN,...]" returning valid min/max. Returns (0,0) if all invalid.
ClassMethod ExtractMinMax(pRaw As %String, Output pMin As %Float, Output pMax As %Float) [ Private ]
{
    Set pMin = 999999999999
    Set pMax = -999999999999
    Set clean = $Translate(pRaw, "[]", "")
    Set pieces = $Length(clean, ",")
    For i = 1:1:pieces {
        Set val = $ZStrip($Piece(clean, ",", i), "<>W")
        If val = "" Continue
        If val = "NaN" Continue
        If '$IsValidNum(val) Continue
        If val <= 0 Continue
        If val < pMin Set pMin = val
        If val > pMax Set pMax = val
    }
    If pMin = 999999999999 Set pMin = 0
    If pMax = -999999999999 Set pMax = 0
}

}