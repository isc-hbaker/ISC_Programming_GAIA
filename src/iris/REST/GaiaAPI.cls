Class Gaia.REST.GaiaAPI Extends %CSP.REST
{

Parameter UseSession As Integer = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/process" Method="POST" Call="Process"/>
</Routes>
}

ClassMethod Process() As %Status
{
    Set engine = $GET(%request.Data("engine", 1), "rust")
    Set inputFile = $GET(%request.Data("inputFile", 1))
    Set threshold = $GET(%request.Data("threshold", 1), 100)

    Set tSC = ##class(Gaia.Service).Process(engine, inputFile, threshold)

    If $$$ISERR(tSC) {
        Set %response.Status = "500 Internal Server Error"
        Write $System.Status.GetErrorText(tSC)
        Quit tSC
    }

    Set %response.ContentType = "application/json"
    Write "{""status"":""ok""}"
    Quit $$$OK
}

}