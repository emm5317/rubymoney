Attribute VB_Name = "modSync"
Option Explicit

Public Sub SyncAll()
    Dim settings As Object
    Set settings = GetSettings()

    If Not EnsureServiceRunning(settings) Then
        MsgBox "Service did not start or is unreachable.", vbExclamation
        Exit Sub
    End If

    Call ImportRules

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim sinceDays As Long
    sinceDays = CLng(GetSetting(settings, "sync_since_days", "180"))
    Dim sinceDate As Date
    sinceDate = Date - sinceDays
    Dim sinceStr As String
    sinceStr = Format$(sinceDate, "yyyy-mm-dd")

    Call SyncCsvAccounts(settings, serviceUrl, sinceStr)

    Dim txJson As String
    txJson = HttpGetJson(serviceUrl & "/v1/transactions?since=" & sinceStr)
    Call WriteTransactionsFromJson(txJson)
    Call SnapshotTransactions
    Call RefreshPivots
    Call ShowDiagnostics
End Sub

Private Sub SyncCsvAccounts(settings As Object, serviceUrl As String, sinceStr As String)
    Dim tbl As ListObject
    Set tbl = GetTable("Accounts", "accounts")

    Dim csvFolder As String
    csvFolder = GetSetting(settings, "csv_import_folder", Environ$("USERPROFILE") & "\Downloads\BudgetImports")

    Dim i As Long
    For i = 1 To tbl.ListRows.Count
        Dim row As Range
        Set row = tbl.ListRows(i).Range

        Dim accountId As String
        accountId = GetRowValue(row, 1)
        If accountId = "" Then GoTo continueLoop

        Dim connectorType As String
        connectorType = LCase$(GetRowValue(row, 5))

        If connectorType = "csv" And accountId <> "" Then
            Dim csvPath As String
            csvPath = FindNewestCsv(csvFolder)
            If csvPath <> "" Then
                Dim body As String
                body = "{""since"":""" & sinceStr & """," & _
                    """account_ids"":[""" & JsonEscape(accountId) & """]," & _
                    """connector_options"":{""csv_path"":""" & JsonEscape(csvPath) & """}}"
                Call HttpPostJson(serviceUrl & "/v1/sync", body)
            End If
        End If
continueLoop:
    Next i
End Sub

Private Function GetRowValue(row As Range, columnIndex As Long) As String
    If row Is Nothing Then Exit Function
    If columnIndex <= 0 Then Exit Function
    If columnIndex > row.Columns.Count Then Exit Function
    GetRowValue = CStr(row.Cells(1, columnIndex).Value)
End Function

Private Function FindNewestCsv(folderPath As String) As String
    Dim fso As Object
    Set fso = CreateObject("Scripting.FileSystemObject")

    If Not fso.FolderExists(folderPath) Then
        FindNewestCsv = ""
        Exit Function
    End If

    Dim folder As Object
    Set folder = fso.GetFolder(folderPath)

    Dim file As Object
    Dim newest As Object
    For Each file In folder.Files
        If LCase$(fso.GetExtensionName(file.Name)) = "csv" Then
            If newest Is Nothing Then
                Set newest = file
            ElseIf file.DateLastModified > newest.DateLastModified Then
                Set newest = file
            End If
        End If
    Next file

    If Not newest Is Nothing Then
        FindNewestCsv = newest.Path
    Else
        FindNewestCsv = ""
    End If
End Function

Private Sub WriteTransactionsFromJson(json As String)
    Dim tbl As ListObject
    Set tbl = GetTable("Transactions", "transactions")
    If tbl Is Nothing Then
        MsgBox "Missing table: transactions on sheet: Transactions", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Dim objects As Collection
    Set objects = JsonObjectsArray(json, "transactions")

    Dim headers As Object
    Set headers = CreateObject("Scripting.Dictionary")

    Dim c As Long
    For c = 1 To tbl.ListColumns.Count
        headers(LCase$(CStr(tbl.ListColumns(c).Name))) = c
    Next c

    If objects.Count = 0 Then
        If Not tbl.DataBodyRange Is Nothing Then
            tbl.DataBodyRange.Delete
        End If
        Exit Sub
    End If

    Dim rows() As Variant
    ReDim rows(1 To objects.Count, 1 To tbl.ListColumns.Count)

    Dim i As Long
    For i = 1 To objects.Count
        Dim obj As String
        obj = objects(i)

        rows(i, headers("txn_id")) = JsonValue(obj, "txn_id")
        rows(i, headers("external_txn_id")) = JsonValue(obj, "external_txn_id")
        rows(i, headers("account_id")) = JsonValue(obj, "account_id")
        rows(i, headers("posted_date")) = JsonValue(obj, "posted_date")
        rows(i, headers("amount")) = CDbl(Val(JsonValue(obj, "amount")))
        rows(i, headers("payee")) = JsonValue(obj, "payee")
        rows(i, headers("memo")) = JsonValue(obj, "memo")
        rows(i, headers("category")) = JsonValue(obj, "category")
        rows(i, headers("subcategory")) = JsonValue(obj, "subcategory")
        rows(i, headers("category_source")) = JsonValue(obj, "category_source")
        rows(i, headers("pending")) = (LCase$(JsonValue(obj, "pending")) = "true")
        rows(i, headers("fingerprint")) = JsonValue(obj, "fingerprint")
        rows(i, headers("imported_at")) = JsonValue(obj, "imported_at")
        rows(i, headers("raw_ref")) = JsonValue(obj, "raw_ref")
    Next i

    If tbl.DataBodyRange Is Nothing Then
        tbl.ListRows.Add
    End If

    tbl.DataBodyRange.Delete
    tbl.Range.Resize(objects.Count + 1).Rows(2).Resize(objects.Count, tbl.ListColumns.Count).Value = rows
End Sub

Private Sub RefreshPivots()
    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Worksheets
        Dim pvt As PivotTable
        For Each pvt In ws.PivotTables
            pvt.RefreshTable
        Next pvt
    Next ws
End Sub
