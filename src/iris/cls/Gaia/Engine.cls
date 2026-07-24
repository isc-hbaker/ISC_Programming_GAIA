Class Gaia.Engine Extends %RegisteredObject
{

/// Dispatcher: routes requests to appropriate processor engine
/// All processors must implement: Run(inputFile As %String, threshold As %Numeric) As %Status
ClassMethod Run(
    engine As %String,
    inputFile As %String,
    threshold As %Numeric = 100
) As %Status
{
    Set engine = $ZCONVERT(engine, "L")

    If engine = "rust" {
        Quit ##class(Gaia.RustProcessor).Run(
            inputFile,
            threshold
        )
    }

    If engine = "objectscript" {
        Quit ##class(Gaia.ObjectScriptProcessor).Run(
            inputFile,
            threshold
        )
    }

    If engine = "apl" {
        Quit ##class(Gaia.APLProcessor).Run(
            inputFile,
            threshold
        )
    }

    Throw ##class(%Exception.General).%New(
        "Unknown Gaia engine: " _ engine
    )
}

}