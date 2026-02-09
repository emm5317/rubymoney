Attribute VB_Name = "modDiagnostics"
Option Explicit

Public Sub ShowDiagnostics()
    Dim settings As Object
    Set settings = GetSettings()

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim json As String
    json = HttpGetJson(serviceUrl & "/v1/diagnostics")

    Dim lastSync As String
    Dim status As String
    Dim summary As String

    lastSync = JsonValue(json, "last_sync_at")
    status = JsonValue(json, "status")
    summary = JsonValue(json, "summary_json")

    Dim msg As String
    msg = "Last Sync: " & lastSync & vbCrLf & _
          "Status: " & status & vbCrLf & _
          "Summary: " & summary

    Call WriteDiagnosticsOutput(lastSync, status, summary)
    MsgBox msg, vbInformation, "Diagnostics"
End Sub

Private Sub WriteDiagnosticsOutput(lastSync As String, status As String, summary As String)
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("Diagnostics")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
        ws.Name = "Diagnostics"
    End If

    ws.Range("A1").Value = "Last Sync"
    ws.Range("B1").Value = lastSync
    ws.Range("A2").Value = "Status"
    ws.Range("B2").Value = status
    ws.Range("A3").Value = "Summary"
    ws.Range("B3").Value = summary
    ws.Range("A4").Value = "Updated At"
    ws.Range("B4").Value = Format$(Now, "yyyy-mm-dd hh:nn:ss")
End Sub
