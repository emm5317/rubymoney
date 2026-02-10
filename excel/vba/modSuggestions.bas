Attribute VB_Name = "modSuggestions"
Option Explicit

Public Sub AddSuggestionButtons()
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("Transactions")
    On Error GoTo 0
    If ws Is Nothing Then
        MsgBox "Missing sheet: Transactions", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Call RemoveShapeIfExists(ws, "btn_suggest_blanks")
    Call RemoveShapeIfExists(ws, "btn_refresh_suggestions")
    Call RemoveShapeIfExists(ws, "btn_apply_suggestions")
    Call RemoveShapeIfExists(ws, "btn_reject_suggestion")

    Dim btnSuggest As Shape
    Set btnSuggest = ws.Shapes.AddShape(msoShapeRoundedRectangle, 10, 10, 200, 28)
    btnSuggest.Name = "btn_suggest_blanks"
    btnSuggest.TextFrame.Characters.Text = "Suggest Categories (Blanks)"
    btnSuggest.OnAction = "SuggestCategoriesForBlanks"

    Dim btnRefresh As Shape
    Set btnRefresh = ws.Shapes.AddShape(msoShapeRoundedRectangle, 220, 10, 160, 28)
    btnRefresh.Name = "btn_refresh_suggestions"
    btnRefresh.TextFrame.Characters.Text = "Refresh Suggestions"
    btnRefresh.OnAction = "RefreshSuggestions"

    Dim btnApply As Shape
    Set btnApply = ws.Shapes.AddShape(msoShapeRoundedRectangle, 390, 10, 170, 28)
    btnApply.Name = "btn_apply_suggestions"
    btnApply.TextFrame.Characters.Text = "Apply Suggestions"
    btnApply.OnAction = "ApplySuggestionsSelected"

    Dim btnReject As Shape
    Set btnReject = ws.Shapes.AddShape(msoShapeRoundedRectangle, 570, 10, 150, 28)
    btnReject.Name = "btn_reject_suggestion"
    btnReject.TextFrame.Characters.Text = "Reject Suggestion"
    btnReject.OnAction = "RejectSuggestionSelected"
End Sub

Public Sub SuggestCategoriesForBlanks()
    Dim settings As Object
    Set settings = GetSettings()

    If Not EnsureServiceRunning(settings) Then
        MsgBox "Service did not start or is unreachable.", vbExclamation
        Exit Sub
    End If

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim tbl As ListObject
    Set tbl = GetTable("Transactions", "transactions")
    If tbl Is Nothing Then Exit Sub

    Dim txnIDsJson As String
    txnIDsJson = BuildTxnIdsJsonForBlanks(tbl)
    If txnIDsJson = "" Then
        MsgBox "No uncategorized transactions found.", vbInformation, "BudgetExcel"
        Exit Sub
    End If

    Dim categoriesJson As String
    categoriesJson = BuildCategoriesJson()
    If categoriesJson = "" Then
        MsgBox "No categories available in plan_annual.", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Dim body As String
    body = "{""txn_ids"":" & txnIDsJson & "," & _
        """mode"":""async""," & _
        """categories"":" & categoriesJson & "}"

    Call HttpPostJson(serviceUrl & "/v1/categories/suggest", body)
    MsgBox "Suggestions queued.", vbInformation, "BudgetExcel"
End Sub

Public Sub RefreshSuggestions()
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

    Dim txJson As String
    txJson = HttpGetJson(serviceUrl & "/v1/transactions?since=" & sinceStr & "&include_suggestions=true")
    Call WriteTransactionsFromJson(txJson)
End Sub

Public Sub ApplySuggestionsSelected()
    Dim settings As Object
    Set settings = GetSettings()

    If Not EnsureServiceRunning(settings) Then
        MsgBox "Service did not start or is unreachable.", vbExclamation
        Exit Sub
    End If

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim tbl As ListObject
    Set tbl = GetTable("Transactions", "transactions")
    If tbl Is Nothing Then Exit Sub

    Dim selected As Collection
    Set selected = SelectedTransactionRows(tbl)
    If selected.Count = 0 Then
        MsgBox "Select one or more rows in the transactions table.", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Dim i As Long
    For i = 1 To selected.Count
        Dim row As Range
        Set row = selected(i)

        Dim category As String
        Dim subcategory As String
        category = CStr(row.Cells(1, tbl.ListColumns("category").Index).Value)
        subcategory = CStr(row.Cells(1, tbl.ListColumns("subcategory").Index).Value)
        If Trim$(category) <> "" Or Trim$(subcategory) <> "" Then
            GoTo continueLoop
        End If

        Dim txnId As String
        txnId = CStr(row.Cells(1, tbl.ListColumns("txn_id").Index).Value)
        If txnId = "" Then GoTo continueLoop

        Call HttpPostJson(serviceUrl & "/v1/transactions/" & txnId & "/suggestion/accept", "{}")
continueLoop:
    Next i

    Call RefreshSuggestions
End Sub

Public Sub RejectSuggestionSelected()
    Dim settings As Object
    Set settings = GetSettings()

    If Not EnsureServiceRunning(settings) Then
        MsgBox "Service did not start or is unreachable.", vbExclamation
        Exit Sub
    End If

    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    Dim tbl As ListObject
    Set tbl = GetTable("Transactions", "transactions")
    If tbl Is Nothing Then Exit Sub

    Dim selected As Collection
    Set selected = SelectedTransactionRows(tbl)
    If selected.Count = 0 Then
        MsgBox "Select one or more rows in the transactions table.", vbExclamation, "BudgetExcel"
        Exit Sub
    End If

    Dim i As Long
    For i = 1 To selected.Count
        Dim row As Range
        Set row = selected(i)
        Dim txnId As String
        txnId = CStr(row.Cells(1, tbl.ListColumns("txn_id").Index).Value)
        If txnId <> "" Then
            Call HttpPostJson(serviceUrl & "/v1/transactions/" & txnId & "/suggestion/reject", "{}")
        End If
    Next i

    Call RefreshSuggestions
End Sub

Private Function BuildTxnIdsJsonForBlanks(tbl As ListObject) As String
    Dim dict As Object
    Set dict = CreateObject("Scripting.Dictionary")

    Dim i As Long
    For i = 1 To tbl.ListRows.Count
        Dim row As Range
        Set row = tbl.ListRows(i).Range

        Dim txnId As String
        txnId = CStr(row.Cells(1, tbl.ListColumns("txn_id").Index).Value)
        If txnId = "" Then GoTo continueLoop

        Dim category As String
        Dim subcategory As String
        category = CStr(row.Cells(1, tbl.ListColumns("category").Index).Value)
        subcategory = CStr(row.Cells(1, tbl.ListColumns("subcategory").Index).Value)

        If Trim$(category) = "" And Trim$(subcategory) = "" Then
            dict(txnId) = True
        End If
continueLoop:
    Next i

    If dict.Count = 0 Then
        BuildTxnIdsJsonForBlanks = ""
        Exit Function
    End If

    Dim json As String
    json = "["

    Dim key As Variant
    Dim first As Boolean
    first = True
    For Each key In dict.Keys
        If Not first Then
            json = json & ","
        End If
        first = False
        json = json & """" & JsonEscape(CStr(key)) & """"
    Next key
    json = json & "]"
    BuildTxnIdsJsonForBlanks = json
End Function

Private Function BuildCategoriesJson() As String
    Dim tbl As ListObject
    Set tbl = GetTable("Plan", "plan_annual")
    If tbl Is Nothing Then Exit Function

    Dim cats As Object
    Set cats = CreateObject("Scripting.Dictionary")

    Dim i As Long
    For i = 1 To tbl.ListRows.Count
        Dim row As Range
        Set row = tbl.ListRows(i).Range

        Dim category As String
        Dim subcategory As String
        category = Trim$(CStr(row.Cells(1, tbl.ListColumns("category").Index).Value))
        subcategory = Trim$(CStr(row.Cells(1, tbl.ListColumns("subcategory").Index).Value))
        If category = "" Or subcategory = "" Then GoTo continueLoop

        If Not cats.Exists(category) Then
            cats(category) = CreateObject("Scripting.Dictionary")
        End If
        Dim subs As Object
        Set subs = cats(category)
        subs(subcategory) = True
continueLoop:
    Next i

    If cats.Count = 0 Then
        BuildCategoriesJson = ""
        Exit Function
    End If

    Dim json As String
    json = "["
    Dim firstCat As Boolean
    firstCat = True

    Dim catKey As Variant
    For Each catKey In cats.Keys
        If Not firstCat Then
            json = json & ","
        End If
        firstCat = False

        Dim subs As Object
        Set subs = cats(catKey)

        json = json & "{""name"":""" & JsonEscape(CStr(catKey)) & """,""subcategories"":["

        Dim firstSub As Boolean
        firstSub = True
        Dim subKey As Variant
        For Each subKey In subs.Keys
            If Not firstSub Then
                json = json & ","
            End If
            firstSub = False
            json = json & """" & JsonEscape(CStr(subKey)) & """"
        Next subKey
        json = json & "]}"
    Next catKey

    json = json & "]"
    BuildCategoriesJson = json
End Function

Private Function SelectedTransactionRows(tbl As ListObject) As Collection
    Dim results As New Collection
    Dim dict As Object
    Set dict = CreateObject("Scripting.Dictionary")

    If tbl.DataBodyRange Is Nothing Then
        Set SelectedTransactionRows = results
        Exit Function
    End If

    Dim sel As Range
    On Error Resume Next
    Set sel = Application.Intersect(Selection, tbl.DataBodyRange)
    On Error GoTo 0
    If sel Is Nothing Then
        Set SelectedTransactionRows = results
        Exit Function
    End If

    Dim cell As Range
    For Each cell In sel.Cells
        Dim rowIndex As Long
        rowIndex = cell.Row - tbl.DataBodyRange.Row + 1
        If rowIndex < 1 Or rowIndex > tbl.ListRows.Count Then GoTo continueLoop
        If Not dict.Exists(rowIndex) Then
            dict(rowIndex) = True
            results.Add tbl.ListRows(rowIndex).Range
        End If
continueLoop:
    Next cell

    Set SelectedTransactionRows = results
End Function

Private Sub RemoveShapeIfExists(ws As Worksheet, shapeName As String)
    Dim shp As Shape
    For Each shp In ws.Shapes
        If shp.Name = shapeName Then
            shp.Delete
            Exit For
        End If
    Next shp
End Sub
