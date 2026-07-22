Class Gaia.REST.GaiaAPI Extends %CSP.REST
{

Parameter UseSession As Integer = 1;


<Route Url="/process" Method="POST">
ClassMethod Process() As %Status
{
    Set engine=$GET(%request.Data("engine"),"rust")
    Set inputFile=$GET(%request.Data("inputFile"))

    Set threshold=$GET(
        %request.Data("threshold"),
        100
    )

    Quit ##class(Gaia.Service).Process(
        engine,
        inputFile,
        threshold
    )
}

}