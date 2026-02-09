Attribute VB_Name = "modRules"
Option Explicit

Public Sub ImportRules()
    Dim settings As Object
    Set settings = GetSettings()

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim tbl As ListObject
    Set tbl = GetTable("Rules", "rules")

    Dim payload As String
    payload = "{""rules"":[" 

    Dim i As Long
    For i = 1 To tbl.ListRows.Count
        Dim row As Range
        Set row = tbl.ListRows(i).Range

        Dim ruleId As String
        ruleId = CStr(row.Cells(1, 1).Value)
        If ruleId = "" Then
            GoTo continueLoop
        End If

        Dim enabledVal As String
        enabledVal = CStr(row.Cells(1, 3).Value)
        Dim enabled As String
        If LCase$(enabledVal) = "true" Or enabledVal = "1" Or enabledVal = "yes" Then
            enabled = "true"
        Else
            enabled = "false"
        End If

        Dim priority As String
        priority = CStr(row.Cells(1, 2).Value)
        If priority = "" Then priority = "0"

        payload = payload & "{" & _
            """rule_id"":""" & JsonEscape(ruleId) & """," & _
            """priority"":" & priority & "," & _
            """enabled"":" & enabled & "," & _
            """match_field"":""" & JsonEscape(CStr(row.Cells(1, 4).Value)) & """," & _
            """match_type"":""" & JsonEscape(CStr(row.Cells(1, 5).Value)) & """," & _
            """match_value"":""" & JsonEscape(CStr(row.Cells(1, 6).Value)) & """," & _
            """category"":""" & JsonEscape(CStr(row.Cells(1, 7).Value)) & """," & _
            """subcategory"":""" & JsonEscape(CStr(row.Cells(1, 8).Value)) & """," & _
            """notes"":""" & JsonEscape(CStr(row.Cells(1, 9).Value)) & """}"

        If i < tbl.ListRows.Count Then
            payload = payload & ","
        End If
continueLoop:
    Next i

    payload = payload & "]}"

    Call HttpPostJson(serviceUrl & "/v1/rules/import", payload)
End Sub

Public Sub ApplyRules(Optional force As Boolean = False)
    Dim settings As Object
    Set settings = GetSettings()

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim body As String
    If force Then
        body = "{""force"":true}"
    Else
        body = "{""force"":false}"
    End If

    Call HttpPostJson(serviceUrl & "/v1/rules/apply", body)
End Sub
