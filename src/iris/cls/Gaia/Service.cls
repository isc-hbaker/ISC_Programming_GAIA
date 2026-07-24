Class Gaia.Service Extends %RegisteredObject
{

/// Public API entrypoint for Gaia processing
/// - engine: "rust", "objectscript", or "apl"
/// - inputFile: path to input CSV
/// - threshold: minimum % variability to include in output (default 100%)
ClassMethod Process(
    engine As %String = "rust",
    inputFile As %String,
    threshold As %Numeric = 100
) As %Status
{
    Quit ##class(Gaia.Engine).Run(
        engine,
        inputFile,
        threshold
    )
}

}