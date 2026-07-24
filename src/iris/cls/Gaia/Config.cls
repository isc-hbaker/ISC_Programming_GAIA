Class Gaia.Config Extends %Persistent
{

/// Default processing engine: rust, objectscript, or apl
Property DefaultEngine As %String [ InitialExpression = "rust" ];

/// Default variability threshold (%) for filtering results
Property DefaultThreshold As %Numeric [ InitialExpression = 100 ];

/// Input data directory
Property DataDirectory As %String [ InitialExpression = "/data/in/" ];

/// Output results directory
Property OutputDirectory As %String [ InitialExpression = "/data/out/" ];

}
