Attribute VB_Name = "modOverrides"
Option Explicit

Public Sub CommitOverrides()
    Dim settings As Object
    Set settings = GetSettings()

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim current As Object
    Set current = CurrentOverridesMap()

    Dim previous As Object
    Set previous = SnapshotOverridesMap()

    Dim payload As String
    payload = "{""overrides"":["

    Dim key As Variant
    Dim first As Boolean
    first = True

    For Each key In current.Keys
        Dim currentVal As String
        currentVal = CStr(current(key))

        Dim prevVal As String
        If previous.Exists(key) Then
            prevVal = CStr(previous(key))
        Else
            prevVal = ""
        End If

        If currentVal <> prevVal Then
            Dim parts() As String
            parts = Split(currentVal, "|")
            Dim category As String
            Dim subcategory As String
            category = ""
            subcategory = ""
            If UBound(parts) >= 0 Then category = parts(0)
            If UBound(parts) >= 1 Then subcategory = parts(1)

            If Not first Then
                payload = payload & ","
            End If
            first = False

            payload = payload & "{" & _
                """txn_id"":""" & JsonEscape(CStr(key)) & """," & _
                """category"":""" & JsonEscape(category) & """," & _
                """subcategory"":""" & JsonEscape(subcategory) & """," & _
                """updated_at"":""" & JsonEscape(UtcNowIso()) & """}"
        End If
    Next key

    payload = payload & "]}"

    If payload <> "{""overrides"":[]}" Then
        Call HttpPostJson(serviceUrl & "/v1/overrides/import", payload)
    End If

    Call SnapshotTransactions
End Sub

Public Sub SnapshotTransactions()
    Dim current As Object
    Set current = CurrentOverridesMap()

    Dim ws As Worksheet
    Set ws = EnsureSnapshotSheet()

    ws.Cells.ClearContents
    ws.Range("A1").Value = "txn_id"
    ws.Range("B1").Value = "category"
    ws.Range("C1").Value = "subcategory"

    Dim rowIndex As Long
    rowIndex = 2

    Dim key As Variant
    For Each key In current.Keys
        Dim parts() As String
        parts = Split(CStr(current(key)), "|")
        ws.Cells(rowIndex, 1).Value = CStr(key)
        ws.Cells(rowIndex, 2).Value = parts(0)
        If UBound(parts) >= 1 Then
            ws.Cells(rowIndex, 3).Value = parts(1)
        End If
        rowIndex = rowIndex + 1
    Next key
End Sub

Private Function CurrentOverridesMap() As Object
    Dim dict As Object
    Set dict = CreateObject("Scripting.Dictionary")

    Dim tbl As ListObject
    Set tbl = GetTable("Transactions", "transactions")

    Dim i As Long
    For i = 1 To tbl.ListRows.Count
        Dim row As Range
        Set row = tbl.ListRows(i).Range

        Dim txnId As String
        txnId = CStr(row.Cells(1, 1).Value)
        If txnId <> "" Then
            Dim category As String
            Dim subcategory As String
            category = CStr(row.Cells(1, 8).Value)
            subcategory = CStr(row.Cells(1, 9).Value)
            dict(txnId) = category & "|" & subcategory
        End If
    Next i

    Set CurrentOverridesMap = dict
End Function

Private Function SnapshotOverridesMap() As Object
    Dim dict As Object
    Set dict = CreateObject("Scripting.Dictionary")

    Dim ws As Worksheet
    Set ws = EnsureSnapshotSheet()

    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row

    Dim i As Long
    For i = 2 To lastRow
        Dim txnId As String
        txnId = CStr(ws.Cells(i, 1).Value)
        If txnId <> "" Then
            Dim category As String
            Dim subcategory As String
            category = CStr(ws.Cells(i, 2).Value)
            subcategory = CStr(ws.Cells(i, 3).Value)
            dict(txnId) = category & "|" & subcategory
        End If
    Next i

    Set SnapshotOverridesMap = dict
End Function

Private Function EnsureSnapshotSheet() As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("TransactionsSnapshot")
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
        ws.Name = "TransactionsSnapshot"
        ws.Visible = xlSheetVeryHidden
    End If
    Set EnsureSnapshotSheet = ws
End Function
