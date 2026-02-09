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

    MsgBox msg, vbInformation, "Diagnostics"
End Sub
