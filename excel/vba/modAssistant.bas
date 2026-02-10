Attribute VB_Name = "modAssistant"
Option Explicit

Public Sub SetupRemindersAssistant()
    Dim wsRem As Worksheet
    Dim wsAssist As Worksheet

    Set wsRem = EnsureSheetAssistant("Reminders")
    Set wsAssist = EnsureSheetAssistant("Import Assistant")

    Call EnsureAccountsColumnsAssistant

    Dim remHeaders As Variant
    remHeaders = Array("account_id", "display_name", "institution", "cadence", "last_import_date", "next_due_date", "days_overdue", "status")
    Dim remTbl As ListObject
    Set remTbl = EnsureTableAssistant(wsRem, "reminders", remHeaders)
    Call EnsureTableColumnsAssistant(remTbl, remHeaders)
    Call EnsureRows(remTbl, GetAccountsRowCount())
    Call ApplyReminderFormulas(remTbl)
    Call ApplyCadenceValidation(remTbl)
    Call AddReminderButton(wsRem)

    Dim assistHeaders As Variant
    assistHeaders = Array("account_id", "display_name", "institution", "expected_csv", "last_imported_at", "last_file", "file_path", "import_status")
    Dim assistTbl As ListObject
    Set assistTbl = EnsureTableAssistant(wsAssist, "import_assistant", assistHeaders)
    Call EnsureTableColumnsAssistant(assistTbl, assistHeaders)
    Call EnsureRows(assistTbl, GetAccountsRowCount())
    Call ApplyAssistantFormulas(assistTbl)
    Call AddAssistantButtons(wsAssist)
End Sub

Public Sub CheckReminders()
    Dim tbl As ListObject
    Set tbl = GetTable("Reminders", "reminders")
    If tbl Is Nothing Then Exit Sub

    Dim dueList As String
    dueList = ""

    Dim i As Long
    For i = 1 To tbl.ListRows.Count
        Dim row As Range
        Set row = tbl.ListRows(i).Range

        Dim accountId As String
        accountId = CStr(row.Cells(1, tbl.ListColumns("account_id").Index).Value)
        If accountId = "" Then GoTo continueLoop

        Dim statusVal As String
        statusVal = LCase$(CStr(row.Cells(1, tbl.ListColumns("status").Index).Value))
        If statusVal = "due" Then
            Dim dueDate As String
            dueDate = CStr(row.Cells(1, tbl.ListColumns("next_due_date").Index).Text)
            dueList = dueList & accountId & " (due " & dueDate & ")" & vbCrLf
        End If
continueLoop:
    Next i

    If dueList = "" Then
        MsgBox "No imports due.", vbInformation, "BudgetExcel"
    Else
        MsgBox "Imports due:" & vbCrLf & dueList, vbExclamation, "BudgetExcel"
    End If
End Sub

Public Sub PickCsvForSelected()
    Dim tbl As ListObject
    Set tbl = GetTable("Import Assistant", "import_assistant")
    If tbl Is Nothing Then Exit Sub

    Dim row As ListRow
    Set row = FindRowFromSelection(tbl)
    If row Is Nothing Then
        MsgBox "Select a row in the Import Assistant table first.", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Dim csvPath As String
    csvPath = PromptForCsv()
    If csvPath = "" Then Exit Sub

    row.Range.Cells(1, tbl.ListColumns("file_path").Index).Value = csvPath
End Sub

Public Sub ImportSelectedCsv()
    Dim tbl As ListObject
    Set tbl = GetTable("Import Assistant", "import_assistant")
    If tbl Is Nothing Then Exit Sub

    Dim row As ListRow
    Set row = FindRowFromSelection(tbl)
    If row Is Nothing Then
        MsgBox "Select a row in the Import Assistant table first.", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Dim accountId As String
    accountId = CStr(row.Range.Cells(1, tbl.ListColumns("account_id").Index).Value)
    If accountId = "" Then
        MsgBox "Missing account_id in selected row.", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Dim csvPath As String
    csvPath = CStr(row.Range.Cells(1, tbl.ListColumns("file_path").Index).Value)
    If csvPath = "" Then
        csvPath = PromptForCsv()
        If csvPath = "" Then Exit Sub
        row.Range.Cells(1, tbl.ListColumns("file_path").Index).Value = csvPath
    End If

    Call ImportCsvForAccount(accountId, csvPath)
End Sub

Public Sub ImportCsvForAccount(accountId As String, csvPath As String)
    Dim settings As Object
    Set settings = GetSettings()

    If Not EnsureServiceRunning(settings) Then
        MsgBox "Service did not start or is unreachable.", vbExclamation
        Exit Sub
    End If

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim sinceDays As Long
    sinceDays = CLng(GetSetting(settings, "sync_since_days", "180"))
    Dim sinceDate As Date
    sinceDate = Date - sinceDays
    Dim sinceStr As String
    sinceStr = Format$(sinceDate, "yyyy-mm-dd")

    Dim body As String
    body = "{""since"":""" & sinceStr & """," & _
        """account_ids"": [""" & JsonEscape(accountId) & """]," & _
        """connector_options"": {""" & "csv_path" & """:""" & JsonEscape(csvPath) & """}}"
    Call HttpPostJson(serviceUrl & "/v1/sync", body)

    Call MarkCsvImported(accountId, csvPath)

    Dim txJson As String
    txJson = HttpGetJson(serviceUrl & "/v1/transactions?since=" & sinceStr)
    Call WriteTransactionsFromJson(txJson)
    Call SnapshotTransactions
    Call RefreshPivots
    Call ShowDiagnostics
    Call RefreshBudgetDashboard
End Sub

Public Function GetAssistantCsvPath(accountId As String) As String
    Dim tbl As ListObject
    Set tbl = GetTable("Import Assistant", "import_assistant")
    If tbl Is Nothing Then Exit Function

    Dim row As ListRow
    Set row = FindRowByAccount(tbl, accountId)
    If row Is Nothing Then Exit Function

    GetAssistantCsvPath = CStr(row.Range.Cells(1, tbl.ListColumns("file_path").Index).Value)
End Function

Public Sub MarkCsvImported(accountId As String, csvPath As String)
    Call UpdateAssistantRow(accountId, csvPath)
    Call UpdateReminderRow(accountId)
End Sub

Private Sub UpdateAssistantRow(accountId As String, csvPath As String)
    Dim tbl As ListObject
    Set tbl = GetTable("Import Assistant", "import_assistant")
    If tbl Is Nothing Then Exit Sub

    Dim row As ListRow
    Set row = FindRowByAccount(tbl, accountId)
    If row Is Nothing Then Exit Sub

    Dim fso As Object
    Set fso = CreateObject("Scripting.FileSystemObject")

    row.Range.Cells(1, tbl.ListColumns("last_imported_at").Index).Value = Now
    row.Range.Cells(1, tbl.ListColumns("last_file").Index).Value = fso.GetFileName(csvPath)
    row.Range.Cells(1, tbl.ListColumns("file_path").Index).Value = csvPath
End Sub

Private Sub UpdateReminderRow(accountId As String)
    Dim tbl As ListObject
    Set tbl = GetTable("Reminders", "reminders")
    If tbl Is Nothing Then Exit Sub

    Dim row As ListRow
    Set row = FindRowByAccount(tbl, accountId)
    If row Is Nothing Then Exit Sub

    row.Range.Cells(1, tbl.ListColumns("last_import_date").Index).Value = Date
End Sub

Private Function FindRowFromSelection(tbl As ListObject) As ListRow
    Dim rng As Range
    On Error Resume Next
    Set rng = Application.Intersect(ActiveCell, tbl.DataBodyRange)
    On Error GoTo 0
    If rng Is Nothing Then Exit Function

    Dim rowIndex As Long
    rowIndex = rng.Row - tbl.DataBodyRange.Row + 1
    If rowIndex < 1 Or rowIndex > tbl.ListRows.Count Then Exit Function

    Set FindRowFromSelection = tbl.ListRows(rowIndex)
End Function

Private Function FindRowByAccount(tbl As ListObject, accountId As String) As ListRow
    Dim i As Long
    For i = 1 To tbl.ListRows.Count
        Dim row As Range
        Set row = tbl.ListRows(i).Range
        If LCase$(CStr(row.Cells(1, tbl.ListColumns("account_id").Index).Value)) = LCase$(accountId) Then
            Set FindRowByAccount = tbl.ListRows(i)
            Exit Function
        End If
    Next i
End Function

Private Function PromptForCsv() As String
    Dim selected As Variant
    selected = Application.GetOpenFilename("CSV Files (*.csv), *.csv")
    If VarType(selected) = vbBoolean Then
        PromptForCsv = ""
        Exit Function
    End If
    PromptForCsv = CStr(selected)
End Function

Private Sub ApplyReminderFormulas(tbl As ListObject)
    Call EnsureRows(tbl, GetAccountsRowCount())
    If tbl.DataBodyRange Is Nothing Then Exit Sub

    Call ApplyReminderValues(tbl)

    tbl.ListColumns("last_import_date").DataBodyRange.NumberFormat = "yyyy-mm-dd"
    tbl.ListColumns("next_due_date").DataBodyRange.NumberFormat = "yyyy-mm-dd"
End Sub

Private Sub ApplyAssistantFormulas(tbl As ListObject)
    Call EnsureRows(tbl, GetAccountsRowCount())
    If tbl.DataBodyRange Is Nothing Then Exit Sub

    Call ApplyAssistantValues(tbl)

    tbl.ListColumns("last_imported_at").DataBodyRange.NumberFormat = "yyyy-mm-dd"
End Sub

Private Sub ApplyCadenceValidation(tbl As ListObject)
    Dim col As ListColumn
    Set col = tbl.ListColumns("cadence")
    If col Is Nothing Then Exit Sub

    Dim rng As Range
    Set rng = col.DataBodyRange
    If rng Is Nothing Then Exit Sub

    On Error Resume Next
    rng.Validation.Delete
    On Error GoTo 0
    rng.Validation.Add Type:=xlValidateList, AlertStyle:=xlValidAlertStop, Formula1:="weekly,monthly,quarterly"
    rng.Validation.IgnoreBlank = True
End Sub

Private Sub AddReminderButton(ws As Worksheet)
    Call RemoveShapeIfExists(ws, "btn_check_reminders")
    Dim btn As Shape
    Set btn = ws.Shapes.AddShape(msoShapeRoundedRectangle, 10, 10, 160, 30)
    btn.Name = "btn_check_reminders"
    btn.TextFrame.Characters.Text = "Check Reminders"
    btn.OnAction = "CheckReminders"
End Sub

Private Sub AddAssistantButtons(ws As Worksheet)
    Call RemoveShapeIfExists(ws, "btn_pick_csv")
    Call RemoveShapeIfExists(ws, "btn_import_csv")

    Dim btnPick As Shape
    Set btnPick = ws.Shapes.AddShape(msoShapeRoundedRectangle, 10, 10, 140, 30)
    btnPick.Name = "btn_pick_csv"
    btnPick.TextFrame.Characters.Text = "Pick CSV"
    btnPick.OnAction = "PickCsvForSelected"

    Dim btnImport As Shape
    Set btnImport = ws.Shapes.AddShape(msoShapeRoundedRectangle, 160, 10, 160, 30)
    btnImport.Name = "btn_import_csv"
    btnImport.TextFrame.Characters.Text = "Import Selected"
    btnImport.OnAction = "ImportSelectedCsv"
End Sub

Private Sub RemoveShapeIfExists(ws As Worksheet, shapeName As String)
    Dim shp As Shape
    For Each shp In ws.Shapes
        If shp.Name = shapeName Then
            shp.Delete
            Exit For
        End If
    Next shp
End Sub

Private Function EnsureSheetAssistant(sheetName As String) As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
        ws.Name = sheetName
    End If
    Set EnsureSheetAssistant = ws
End Function

Private Function EnsureTableAssistant(ws As Worksheet, tableName As String, headers As Variant) As ListObject
    Dim tbl As ListObject
    On Error Resume Next
    Set tbl = ws.ListObjects(tableName)
    On Error GoTo 0
    If Not tbl Is Nothing Then
        Set EnsureTableAssistant = tbl
        Exit Function
    End If

    Dim colCount As Long
    colCount = UBound(headers) - LBound(headers) + 1

    Dim startRow As Long
    Dim startCol As Long
    startCol = 1
    If Application.WorksheetFunction.CountA(ws.Cells) = 0 Then
        startRow = 1
    Else
        Dim lastRow As Long
        lastRow = ws.UsedRange.Row + ws.UsedRange.Rows.Count - 1
        startRow = lastRow + 2
    End If

    Dim headerRange As Range
    Set headerRange = ws.Cells(startRow, startCol).Resize(1, colCount)

    Dim i As Long
    For i = 1 To colCount
        headerRange.Cells(1, i).Value = headers(LBound(headers) + i - 1)
    Next i

    Set tbl = ws.ListObjects.Add(xlSrcRange, headerRange, , xlYes)
    tbl.Name = tableName
    Set EnsureTableAssistant = tbl
End Function

Private Sub EnsureTableColumnsAssistant(tbl As ListObject, headers As Variant)
    Dim i As Long
    For i = LBound(headers) To UBound(headers)
        Dim name As String
        name = CStr(headers(i))
        If Not TableHasColumnAssistant(tbl, name) Then
            tbl.ListColumns.Add.Name = name
        End If
    Next i
End Sub

Private Function TableHasColumnAssistant(tbl As ListObject, columnName As String) As Boolean
    Dim col As ListColumn
    For Each col In tbl.ListColumns
        If LCase$(col.Name) = LCase$(columnName) Then
            TableHasColumnAssistant = True
            Exit Function
        End If
    Next col
    TableHasColumnAssistant = False
End Function

Private Sub EnsureRows(tbl As ListObject, minRows As Long)
    If minRows < 5 Then minRows = 5
    Dim current As Long
    current = tbl.ListRows.Count
    Dim i As Long
    For i = current + 1 To minRows
        tbl.ListRows.Add
    Next i
End Sub

Private Function GetAccountsRowCount() As Long
    Dim tbl As ListObject
    Set tbl = GetTable("Accounts", "accounts")
    If tbl Is Nothing Then
        GetAccountsRowCount = 5
        Exit Function
    End If
    GetAccountsRowCount = tbl.ListRows.Count
End Function

Private Sub EnsureAccountsColumnsAssistant()
    Dim tbl As ListObject
    Set tbl = GetTable("Accounts", "accounts")
    If tbl Is Nothing Then Exit Sub

    If Not TableHasColumnAssistant(tbl, "display_name") Then
        tbl.ListColumns.Add.Name = "display_name"
    End If
    If Not TableHasColumnAssistant(tbl, "institution") Then
        tbl.ListColumns.Add.Name = "institution"
    End If
End Sub

Private Function ListSep() As String
    On Error Resume Next
    ListSep = Application.International(xlListSeparator)
    If ListSep = "" Then ListSep = ","
    On Error GoTo 0
End Function

Private Sub ApplyReminderValues(tbl As ListObject)
    Dim data As Variant
    data = tbl.DataBodyRange.Value

    Dim idxAccount As Long
    Dim idxDisplay As Long
    Dim idxInstitution As Long
    Dim idxCadence As Long
    Dim idxLast As Long
    Dim idxNext As Long
    Dim idxOverdue As Long
    Dim idxStatus As Long

    idxAccount = tbl.ListColumns("account_id").Index
    idxDisplay = tbl.ListColumns("display_name").Index
    idxInstitution = tbl.ListColumns("institution").Index
    idxCadence = tbl.ListColumns("cadence").Index
    idxLast = tbl.ListColumns("last_import_date").Index
    idxNext = tbl.ListColumns("next_due_date").Index
    idxOverdue = tbl.ListColumns("days_overdue").Index
    idxStatus = tbl.ListColumns("status").Index

    Dim accountIds As Variant
    Dim displayNames As Variant
    Dim institutions As Variant
    Call ReadAccountsArrays(accountIds, displayNames, institutions)

    Dim r As Long
    For r = 1 To UBound(data, 1)
        Dim accountId As String
        accountId = GetAccountValue(accountIds, r)
        data(r, idxAccount) = accountId
        data(r, idxDisplay) = GetArrayValue(displayNames, r)
        data(r, idxInstitution) = GetArrayValue(institutions, r)

        Dim lastImport As Variant
        lastImport = data(r, idxLast)

        Dim cadence As String
        cadence = LCase$(CStr(data(r, idxCadence)))

        If IsDate(lastImport) Then
            Dim nextDue As Date
            If cadence = "weekly" Then
                nextDue = CDate(lastImport) + 7
            ElseIf cadence = "monthly" Then
                nextDue = DateAdd("m", 1, CDate(lastImport))
            ElseIf cadence = "quarterly" Then
                nextDue = DateAdd("m", 3, CDate(lastImport))
            Else
                nextDue = DateAdd("m", 1, CDate(lastImport))
            End If
            data(r, idxNext) = nextDue
            data(r, idxOverdue) = Date - nextDue
            If nextDue <= Date Then
                data(r, idxStatus) = "due"
            Else
                data(r, idxStatus) = "ok"
            End If
        Else
            data(r, idxNext) = ""
            data(r, idxOverdue) = ""
            data(r, idxStatus) = ""
        End If
    Next r

    tbl.DataBodyRange.Value = data
End Sub

Private Sub ApplyAssistantValues(tbl As ListObject)
    Dim data As Variant
    data = tbl.DataBodyRange.Value

    Dim idxAccount As Long
    Dim idxDisplay As Long
    Dim idxInstitution As Long
    Dim idxExpected As Long
    Dim idxLastImported As Long
    Dim idxFile As Long
    Dim idxStatus As Long

    idxAccount = tbl.ListColumns("account_id").Index
    idxDisplay = tbl.ListColumns("display_name").Index
    idxInstitution = tbl.ListColumns("institution").Index
    idxExpected = tbl.ListColumns("expected_csv").Index
    idxLastImported = tbl.ListColumns("last_imported_at").Index
    idxFile = tbl.ListColumns("file_path").Index
    idxStatus = tbl.ListColumns("import_status").Index

    Dim accountIds As Variant
    Dim displayNames As Variant
    Dim institutions As Variant
    Call ReadAccountsArrays(accountIds, displayNames, institutions)

    Dim r As Long
    For r = 1 To UBound(data, 1)
        Dim accountId As String
        accountId = GetAccountValue(accountIds, r)
        data(r, idxAccount) = accountId
        data(r, idxDisplay) = GetArrayValue(displayNames, r)
        data(r, idxInstitution) = GetArrayValue(institutions, r)

        If accountId <> "" Then
            data(r, idxExpected) = CStr(data(r, idxInstitution)) & " - " & accountId & ".csv"
        Else
            data(r, idxExpected) = ""
        End If

        If CStr(data(r, idxFile)) = "" Then
            data(r, idxStatus) = ""
        ElseIf CStr(data(r, idxLastImported)) = "" Then
            data(r, idxStatus) = "ready"
        Else
            data(r, idxStatus) = "imported"
        End If
    Next r

    tbl.DataBodyRange.Value = data
End Sub

Private Sub ReadAccountsArrays(ByRef accountIds As Variant, ByRef displayNames As Variant, ByRef institutions As Variant)
    Dim acctTbl As ListObject
    Set acctTbl = GetTable("Accounts", "accounts")
    If acctTbl Is Nothing Or acctTbl.DataBodyRange Is Nothing Then
        accountIds = Array()
        displayNames = Array()
        institutions = Array()
        Exit Sub
    End If

    accountIds = acctTbl.ListColumns("account_id").DataBodyRange.Value
    displayNames = acctTbl.ListColumns("display_name").DataBodyRange.Value
    institutions = acctTbl.ListColumns("institution").DataBodyRange.Value
End Sub

Private Function GetAccountValue(values As Variant, rowIndex As Long) As String
    GetAccountValue = GetArrayValue(values, rowIndex)
End Function

Private Function GetArrayValue(values As Variant, rowIndex As Long) As String
    On Error Resume Next
    If IsArray(values) Then
        If UBound(values, 1) >= rowIndex Then
            GetArrayValue = CStr(values(rowIndex, 1))
            Exit Function
        End If
    End If
    GetArrayValue = ""
    On Error GoTo 0
End Function
