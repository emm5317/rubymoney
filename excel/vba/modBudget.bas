Attribute VB_Name = "modBudget"
Option Explicit

Public Sub SetupBudgetDashboard()
    Dim wsPlan As Worksheet
    Dim wsEnv As Worksheet
    Dim wsRealloc As Worksheet

    Set wsPlan = EnsureSheet("Plan")
    Set wsEnv = EnsureSheet("Envelopes")
    Set wsRealloc = EnsureSheet("Reallocations")

    Dim planHeaders As Variant
    planHeaders = Array("category", "subcategory", "type", "rollover", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec", "annual_total", "notes", "key")
    Dim planTbl As ListObject
    Set planTbl = EnsureTable(wsPlan, "plan_annual", planHeaders)
    Call EnsureTableColumns(planTbl, planHeaders)
    Call ApplyPlanFormulas(planTbl)

    Dim reallocHeaders As Variant
    reallocHeaders = Array("date", "month", "from_category", "from_subcategory", "to_category", "to_subcategory", "amount", "note")
    Dim reallocTbl As ListObject
    Set reallocTbl = EnsureTable(wsRealloc, "reallocations", reallocHeaders)
    Call EnsureTableColumns(reallocTbl, reallocHeaders)
    Call ApplyReallocationFormulas(reallocTbl)

    Dim envHeaders As Variant
    envHeaders = Array("month", "category", "subcategory", "budgeted", "realloc_in", "realloc_out", "spent", "rollover_in", "available", "remaining", "rollover_out")
    Dim envTbl As ListObject
    Set envTbl = EnsureTable(wsEnv, "envelopes", envHeaders)
    Call EnsureTableColumns(envTbl, envHeaders)
    Call ApplyEnvelopeFormulas(envTbl)

    Call SetupDashboardOnly

    Call RebuildEnvelopesForYear(Year(Date))
    Call RefreshBudgetDashboard
End Sub

Public Sub SetupDashboardOnly()
    Dim wsDash As Worksheet
    Set wsDash = EnsureSheet("Dashboard")

    Dim paramsHeaders As Variant
    paramsHeaders = Array("key", "value")
    Dim paramsTbl As ListObject
    Set paramsTbl = EnsureTable(wsDash, "dashboard_params", paramsHeaders)
    Call EnsureTableColumns(paramsTbl, paramsHeaders)
    Call SeedDashboardParams(paramsTbl)

    Dim summaryHeaders As Variant
    summaryHeaders = Array("metric", "value")
    Dim summaryTbl As ListObject
    Set summaryTbl = EnsureTable(wsDash, "dashboard_summary", summaryHeaders)
    Call EnsureTableColumns(summaryTbl, summaryHeaders)
    Call SeedDashboardSummary(summaryTbl)

    Dim overspentHeaders As Variant
    overspentHeaders = Array("category", "subcategory", "remaining")
    Dim overspentTbl As ListObject
    Set overspentTbl = EnsureTable(wsDash, "dashboard_overspent", overspentHeaders)
    Call EnsureTableColumns(overspentTbl, overspentHeaders)
    Call SeedDashboardOverspent(overspentTbl)

    Dim ytdHeaders As Variant
    ytdHeaders = Array("category", "subcategory", "budgeted_ytd", "spent_ytd", "variance")
    Dim ytdTbl As ListObject
    Set ytdTbl = EnsureTable(wsDash, "dashboard_ytd", ytdHeaders)
    Call EnsureTableColumns(ytdTbl, ytdHeaders)
    Call SeedDashboardYtd(ytdTbl)
End Sub

Public Sub RebuildEnvelopesForYear(Optional yearValue As Long = 0)
    If yearValue = 0 Then yearValue = Year(Date)

    Dim planTbl As ListObject
    Set planTbl = GetTable("Plan", "plan_annual")
    If planTbl Is Nothing Then Exit Sub

    Dim envTbl As ListObject
    Set envTbl = GetTable("Envelopes", "envelopes")
    If envTbl Is Nothing Then Exit Sub

    Dim planRows As Long
    planRows = planTbl.ListRows.Count
    If planRows = 0 Then Exit Sub

    Dim i As Long
    Dim m As Long
    Dim outRows As Long
    outRows = 0

    Dim data() As Variant
    ReDim data(1 To planRows * 12, 1 To 3)

    For i = 1 To planRows
        Dim row As Range
        Set row = planTbl.ListRows(i).Range

        Dim category As String
        category = CStr(row.Cells(1, 1).Value)
        Dim subcategory As String
        subcategory = CStr(row.Cells(1, 2).Value)
        Dim planType As String
        planType = LCase$(CStr(row.Cells(1, 3).Value))

        If category = "" Then GoTo continueLoop
        If planType = "income" Then GoTo continueLoop

        For m = 1 To 12
            outRows = outRows + 1
            data(outRows, 1) = DateSerial(yearValue, m, 1)
            data(outRows, 2) = category
            data(outRows, 3) = subcategory
        Next m
continueLoop:
    Next i

    If outRows = 0 Then
        If Not envTbl.DataBodyRange Is Nothing Then
            envTbl.DataBodyRange.Delete
        End If
        Exit Sub
    End If

    If envTbl.DataBodyRange Is Nothing Then
        envTbl.ListRows.Add
    End If

    envTbl.DataBodyRange.Delete
    envTbl.Range.Resize(outRows + 1).Rows(2).Resize(outRows, 3).Value = data
    envTbl.ListColumns("month").DataBodyRange.NumberFormat = "yyyy-mm"
    Call ApplyEnvelopeFormulas(envTbl)
End Sub

Public Sub RefreshBudgetDashboard()
    Call EnsureDashboardParams
    Application.Calculate
End Sub

Private Function EnsureSheet(sheetName As String) As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
        ws.Name = sheetName
    End If
    Set EnsureSheet = ws
End Function

Private Function EnsureTable(ws As Worksheet, tableName As String, headers As Variant) As ListObject
    Dim tbl As ListObject
    On Error Resume Next
    Set tbl = ws.ListObjects(tableName)
    On Error GoTo 0
    If Not tbl Is Nothing Then
        Set EnsureTable = tbl
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
    Set EnsureTable = tbl
End Function

Private Sub EnsureTableColumns(tbl As ListObject, headers As Variant)
    Dim i As Long
    For i = LBound(headers) To UBound(headers)
        Dim name As String
        name = CStr(headers(i))
        If Not TableHasColumn(tbl, name) Then
            tbl.ListColumns.Add.Name = name
        End If
    Next i
End Sub

Private Function TableHasColumn(tbl As ListObject, columnName As String) As Boolean
    Dim col As ListColumn
    For Each col In tbl.ListColumns
        If LCase$(col.Name) = LCase$(columnName) Then
            TableHasColumn = True
            Exit Function
        End If
    Next col
    TableHasColumn = False
End Function

Private Sub ApplyPlanFormulas(tbl As ListObject)
    If tbl.DataBodyRange Is Nothing Then Exit Sub
    tbl.ListColumns("annual_total").DataBodyRange.Formula = "=SUM([@[jan]]:[@[dec]])"
    tbl.ListColumns("key").DataBodyRange.Formula = "=[@category]&""|""&[@subcategory]"
End Sub

Private Sub ApplyReallocationFormulas(tbl As ListObject)
    If tbl.DataBodyRange Is Nothing Then Exit Sub
    tbl.ListColumns("month").DataBodyRange.Formula = "=DATE(YEAR([@date]),MONTH([@date]),1)"
End Sub

Private Sub ApplyEnvelopeFormulas(tbl As ListObject)
    If tbl.DataBodyRange Is Nothing Then Exit Sub

    Dim q As String
    q = Chr$(34)

    tbl.ListColumns("budgeted").DataBodyRange.Formula = "=IFERROR(XLOOKUP([@category]&" & q & "|" & q & "&[@subcategory],plan_annual[key],CHOOSE(MONTH([@month]),plan_annual[jan],plan_annual[feb],plan_annual[mar],plan_annual[apr],plan_annual[may],plan_annual[jun],plan_annual[jul],plan_annual[aug],plan_annual[sep],plan_annual[oct],plan_annual[nov],plan_annual[dec]),0),0)"

    tbl.ListColumns("realloc_in").DataBodyRange.Formula = "=SUMIFS(reallocations[amount],reallocations[month],[@month],reallocations[to_category],[@category],reallocations[to_subcategory],[@subcategory])"

    tbl.ListColumns("realloc_out").DataBodyRange.Formula = "=SUMIFS(reallocations[amount],reallocations[month],[@month],reallocations[from_category],[@category],reallocations[from_subcategory],[@subcategory])"

    tbl.ListColumns("spent").DataBodyRange.Formula = "=-SUMIFS(transactions[amount],transactions[category],[@category],transactions[subcategory],[@subcategory],transactions[posted_date]," & q & ">=" & q & "&[@month],transactions[posted_date]," & q & "<" & q & "&EDATE([@month],1))"

    tbl.ListColumns("rollover_in").DataBodyRange.Formula = "=SUMIFS(envelopes[rollover_out],envelopes[category],[@category],envelopes[subcategory],[@subcategory],envelopes[month],EDATE([@month],-1))"

    tbl.ListColumns("available").DataBodyRange.Formula = "=[@budgeted]+[@realloc_in]-[@realloc_out]+[@rollover_in]"

    tbl.ListColumns("remaining").DataBodyRange.Formula = "=[@available]-[@spent]"

    tbl.ListColumns("rollover_out").DataBodyRange.Formula = "=IF(LOWER(XLOOKUP([@category]&" & q & "|" & q & "&[@subcategory],plan_annual[key],plan_annual[rollover]," & q & "yes" & q & "))=" & q & "yes" & q & ",MAX(0,[@remaining]),0)"
End Sub

Private Sub SeedDashboardParams(tbl As ListObject)
    If tbl.ListRows.Count = 0 Then
        tbl.ListRows.Add
        tbl.ListRows.Add
    End If

    tbl.ListRows(1).Range.Cells(1, 1).Value = "current_month"
    tbl.ListRows(1).Range.Cells(1, 2).Formula = "=DATE(YEAR(TODAY()),MONTH(TODAY()),1)"

    tbl.ListRows(2).Range.Cells(1, 1).Value = "current_year"
    tbl.ListRows(2).Range.Cells(1, 2).Formula = "=YEAR(TODAY())"
End Sub

Private Sub EnsureDashboardParams()
    Dim paramsTbl As ListObject
    Set paramsTbl = GetTable("Dashboard", "dashboard_params")
    If paramsTbl Is Nothing Then Exit Sub
    Call SeedDashboardParams(paramsTbl)
End Sub

Private Sub SeedDashboardSummary(tbl As ListObject)
    Dim labels As Variant
    labels = Array( _
        "Total Income (Month)", _
        "Total Expenses (Month)", _
        "Net (Month)", _
        "Envelope Remaining (Month)", _
        "Overspent Envelopes (Count)", _
        "YTD Net" _
    )

    Dim i As Long
    For i = 1 To UBound(labels) + 1
        If tbl.ListRows.Count < i Then tbl.ListRows.Add
        tbl.ListRows(i).Range.Cells(1, 1).Value = labels(i - 1)
    Next i

    Dim q As String
    q = Chr$(34)

    Dim dashMonth As String
    dashMonth = "XLOOKUP(" & q & "current_month" & q & ",dashboard_params[key],dashboard_params[value],TODAY())"
    Dim dashYear As String
    dashYear = "XLOOKUP(" & q & "current_year" & q & ",dashboard_params[key],dashboard_params[value],YEAR(TODAY()))"

    tbl.ListRows(1).Range.Cells(1, 2).Formula = "=LET(m," & dashMonth & ",SUMIFS(transactions[amount],transactions[posted_date]," & q & ">=" & q & "&m,transactions[posted_date]," & q & "<" & q & "&EDATE(m,1),transactions[amount]," & q & ">0" & q & "))"
    tbl.ListRows(2).Range.Cells(1, 2).Formula = "=LET(m," & dashMonth & ",-SUMIFS(transactions[amount],transactions[posted_date]," & q & ">=" & q & "&m,transactions[posted_date]," & q & "<" & q & "&EDATE(m,1),transactions[amount]," & q & "<0" & q & "))"
    tbl.ListRows(3).Range.Cells(1, 2).Formula = "=LET(m," & dashMonth & ",inc,SUMIFS(transactions[amount],transactions[posted_date]," & q & ">=" & q & "&m,transactions[posted_date]," & q & "<" & q & "&EDATE(m,1),transactions[amount]," & q & ">0" & q & "),exp,-SUMIFS(transactions[amount],transactions[posted_date]," & q & ">=" & q & "&m,transactions[posted_date]," & q & "<" & q & "&EDATE(m,1),transactions[amount]," & q & "<0" & q & "),inc-exp)"
    tbl.ListRows(4).Range.Cells(1, 2).Formula = "=LET(m," & dashMonth & ",SUMIFS(envelopes[remaining],envelopes[month],m))"
    tbl.ListRows(5).Range.Cells(1, 2).Formula = "=LET(m," & dashMonth & ",COUNTIFS(envelopes[month],m,envelopes[remaining]," & q & "<0" & q & "))"
    tbl.ListRows(6).Range.Cells(1, 2).Formula = "=LET(y," & dashYear & ",SUMIFS(transactions[amount],transactions[posted_date]," & q & ">=" & q & "&DATE(y,1,1),transactions[posted_date]," & q & "<" & q & "&DATE(y+1,1,1)))"
End Sub

Private Sub SeedDashboardOverspent(tbl As ListObject)
    Dim i As Long
    For i = 1 To 5
        If tbl.ListRows.Count < i Then tbl.ListRows.Add
    Next i

    Dim q As String
    q = Chr$(34)

    Dim dashMonth As String
    dashMonth = "XLOOKUP(" & q & "current_month" & q & ",dashboard_params[key],dashboard_params[value],TODAY())"

    Dim base As String
    base = "LET(m," & dashMonth & ",cats,FILTER(envelopes[category],(envelopes[month]=m)*(envelopes[remaining]<0)),subs,FILTER(envelopes[subcategory],(envelopes[month]=m)*(envelopes[remaining]<0)),rems,FILTER(envelopes[remaining],(envelopes[month]=m)*(envelopes[remaining]<0)),idx,ROW()-ROW(dashboard_overspent[#Headers]),sortedCats,SORTBY(cats,rems,1),sortedSubs,SORTBY(subs,rems,1),sortedRems,SORTBY(rems,rems,1),"

    tbl.ListColumns("category").DataBodyRange.Formula = "=" & base & "IFERROR(INDEX(sortedCats,idx),""""))"
    tbl.ListColumns("subcategory").DataBodyRange.Formula = "=" & base & "IFERROR(INDEX(sortedSubs,idx),""""))"
    tbl.ListColumns("remaining").DataBodyRange.Formula = "=" & base & "IFERROR(INDEX(sortedRems,idx),""""))"
End Sub

Private Sub SeedDashboardYtd(tbl As ListObject)
    Dim i As Long
    For i = 1 To 50
        If tbl.ListRows.Count < i Then tbl.ListRows.Add
    Next i

    If tbl.DataBodyRange Is Nothing Then Exit Sub

    Dim q As String
    q = Chr$(34)

    Dim catsFormula As String
    catsFormula = "LET(cats,FILTER(plan_annual[category],plan_annual[type]=" & q & "expense" & q & "),idx,ROW()-ROW(dashboard_ytd[#Headers]),IFERROR(INDEX(cats,idx)," & q & q & "))"
    Dim subsFormula As String
    subsFormula = "LET(subs,FILTER(plan_annual[subcategory],plan_annual[type]=" & q & "expense" & q & "),idx,ROW()-ROW(dashboard_ytd[#Headers]),IFERROR(INDEX(subs,idx)," & q & q & "))"

    tbl.ListColumns("category").DataBodyRange.Formula = "=" & catsFormula
    tbl.ListColumns("subcategory").DataBodyRange.Formula = "=" & subsFormula

    Dim dashMonth As String
    dashMonth = "XLOOKUP(" & q & "current_month" & q & ",dashboard_params[key],dashboard_params[value],TODAY())"
    Dim dashYear As String
    dashYear = "XLOOKUP(" & q & "current_year" & q & ",dashboard_params[key],dashboard_params[value],YEAR(TODAY()))"

    tbl.ListColumns("budgeted_ytd").DataBodyRange.Formula = "=IF([@category]=" & q & q & "," & q & q & ",LET(m," & dashMonth & ",y," & dashYear & ",SUMIFS(envelopes[budgeted],envelopes[category],[@category],envelopes[subcategory],[@subcategory],envelopes[month]," & q & ">=" & q & "&DATE(y,1,1),envelopes[month]," & q & "<=" & q & "&m)))"
    tbl.ListColumns("spent_ytd").DataBodyRange.Formula = "=IF([@category]=" & q & q & "," & q & q & ",LET(m," & dashMonth & ",y," & dashYear & ",SUMIFS(envelopes[spent],envelopes[category],[@category],envelopes[subcategory],[@subcategory],envelopes[month]," & q & ">=" & q & "&DATE(y,1,1),envelopes[month]," & q & "<=" & q & "&m)))"
    tbl.ListColumns("variance").DataBodyRange.FormulaR1C1 = "=IF(RC1="""","""",RC3-RC4)"
End Sub
