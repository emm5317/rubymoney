Attribute VB_Name = "modService"
Option Explicit

Public Function GetSettings() As Object
    Dim dict As Object
    Set dict = CreateObject("Scripting.Dictionary")

    Dim tbl As ListObject
    On Error Resume Next
    Set tbl = GetTable("Config", "settings")
    On Error GoTo 0
    If tbl Is Nothing Then
        Set GetSettings = dict
        Exit Function
    End If

    Dim r As ListRow
    For Each r In tbl.ListRows
        Dim key As String
        Dim value As String
        key = Trim$(CStr(r.Range.Cells(1, 1).Value))
        value = CStr(r.Range.Cells(1, 2).Value)
        If key <> "" Then
            dict(key) = value
        End If
    Next r

    Set GetSettings = dict
End Function

Public Function GetSetting(settings As Object, key As String, Optional defaultValue As String = "") As String
    If settings Is Nothing Then
        GetSetting = defaultValue
        Exit Function
    End If
    If settings.Exists(key) Then
        GetSetting = CStr(settings(key))
    Else
        GetSetting = defaultValue
    End If
End Function

Public Function GetTable(sheetName As String, tableName As String) As ListObject
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    If ws Is Nothing Then
        MsgBox "Missing sheet: " & sheetName, vbExclamation, "BudgetExcel"
        Set GetTable = Nothing
        Exit Function
    End If

    Dim tbl As ListObject
    On Error Resume Next
    Set tbl = ws.ListObjects(tableName)
    On Error GoTo 0
    If tbl Is Nothing Then
        MsgBox "Missing table: " & tableName & " on sheet: " & sheetName, vbExclamation, "BudgetExcel"
        Set GetTable = Nothing
        Exit Function
    End If

    Set GetTable = tbl
End Function

Public Function EnsureServiceRunning(settings As Object) As Boolean
    Dim serviceUrl As String
    serviceUrl = GetSetting(settings, "service_url", "http://127.0.0.1:8787")

    If ServiceHealthy(serviceUrl) Then
        EnsureServiceRunning = True
        Exit Function
    End If

    Dim exePath As String
    exePath = GetSetting(settings, "service_exe_path", "")
    If exePath = "" Then
        exePath = TryFindServiceExe()
    End If

    If exePath <> "" Then
        Shell """" & exePath & """", vbHide
    End If

    Dim i As Integer
    For i = 1 To 20
        If ServiceHealthy(serviceUrl) Then
            EnsureServiceRunning = True
            Exit Function
        End If
        Application.Wait Now + TimeValue("0:00:01")
    Next i

    EnsureServiceRunning = False
End Function

Private Function TryFindServiceExe() As String
    Dim candidate As String

    candidate = Environ$("LOCALAPPDATA") & "\BudgetApp\budgetd.exe"
    If FileExists(candidate) Then
        TryFindServiceExe = candidate
        Exit Function
    End If

    candidate = Environ$("ProgramFiles") & "\BudgetApp\budgetd.exe"
    If FileExists(candidate) Then
        TryFindServiceExe = candidate
        Exit Function
    End If

    candidate = ThisWorkbook.Path & "\budgetd.exe"
    If FileExists(candidate) Then
        TryFindServiceExe = candidate
        Exit Function
    End If

    TryFindServiceExe = ""
End Function

Private Function FileExists(path As String) As Boolean
    On Error Resume Next
    FileExists = (Dir(path) <> "")
    On Error GoTo 0
End Function

Private Function ServiceHealthy(serviceUrl As String) As Boolean
    On Error GoTo fail
    Dim resp As String
    resp = HttpGetJson(serviceUrl & "/v1/health")
    ServiceHealthy = (InStr(1, resp, "version", vbTextCompare) > 0)
    Exit Function
fail:
    ServiceHealthy = False
End Function

Public Function HttpGetJson(url As String) As String
    Dim http As Object
    Set http = CreateObject("MSXML2.XMLHTTP")
    http.Open "GET", url, False
    http.setRequestHeader "Accept", "application/json"
    http.send
    HttpGetJson = CStr(http.responseText)
End Function

Public Function HttpPostJson(url As String, body As String) As String
    Dim http As Object
    Set http = CreateObject("MSXML2.XMLHTTP")
    http.Open "POST", url, False
    http.setRequestHeader "Content-Type", "application/json"
    http.setRequestHeader "Accept", "application/json"
    http.send body
    HttpPostJson = CStr(http.responseText)
End Function

Public Function JsonEscape(value As String) As String
    Dim s As String
    s = value
    Dim quote As String
    quote = """"
    Dim slash As String
    slash = "\"
    s = Replace(s, slash, slash & slash)
    s = Replace(s, quote, slash & quote)
    s = Replace(s, vbCrLf, "\n")
    s = Replace(s, vbCr, "\n")
    s = Replace(s, vbLf, "\n")
    JsonEscape = s
End Function

Public Function JsonValue(obj As String, field As String) As String
    Dim re As Object
    Set re = CreateObject("VBScript.RegExp")
    re.Pattern = """" & field & """" & "\s*:\s*(""([^""]*)""|(-?\d+(?:\.\d+)?)|(true|false|null))"
    re.IgnoreCase = True
    re.Global = False

    Dim matches As Object
    If re.Test(obj) Then
        Set matches = re.Execute(obj)
        Dim m As Object
        Set m = matches(0)
        Dim value As String
        If m.SubMatches(1) <> "" Then
            value = m.SubMatches(1)
        ElseIf m.SubMatches(2) <> "" Then
            value = m.SubMatches(2)
        Else
            value = m.SubMatches(3)
        End If
        JsonValue = JsonUnescape(value)
    Else
        JsonValue = ""
    End If
End Function

Public Function JsonUnescape(value As String) As String
    Dim s As String
    s = value
    Dim quote As String
    quote = """"
    Dim slash As String
    slash = "\"
    s = Replace(s, slash & slash, slash)
    s = Replace(s, slash & quote, quote)
    s = Replace(s, "\n", vbLf)
    JsonUnescape = s
End Function

Public Function JsonObjectsArray(json As String, arrayName As String) As Collection
    Dim results As New Collection
    Dim pos As Long
    pos = InStr(1, json, """" & arrayName & """", vbTextCompare)
    If pos = 0 Then
        Set JsonObjectsArray = results
        Exit Function
    End If

    pos = InStr(pos, json, "[")
    If pos = 0 Then
        Set JsonObjectsArray = results
        Exit Function
    End If

    Dim i As Long
    Dim depth As Long
    Dim startPos As Long
    Dim inString As Boolean
    Dim c As String

    For i = pos + 1 To Len(json)
        c = Mid$(json, i, 1)
        If c = """" Then
            If Not IsEscapedQuote(json, i) Then
                inString = Not inString
            End If
        End If
        If inString Then
            GoTo continueLoop
        End If
        If c = "{" Then
            If depth = 0 Then
                startPos = i
            End If
            depth = depth + 1
        ElseIf c = "}" Then
            depth = depth - 1
            If depth = 0 And startPos > 0 Then
                results.Add Mid$(json, startPos, i - startPos + 1)
                startPos = 0
            End If
        ElseIf c = "]" And depth = 0 Then
            Exit For
        End If
continueLoop:
    Next i

    Set JsonObjectsArray = results
End Function

Private Function IsEscapedQuote(text As String, pos As Long) As Boolean
    Dim i As Long
    Dim count As Long
    i = pos - 1
    Do While i >= 1 And Mid$(text, i, 1) = "\"
        count = count + 1
        i = i - 1
    Loop
    IsEscapedQuote = (count Mod 2 = 1)
End Function

Public Function UtcNowIso() As String
    UtcNowIso = Format$(Now, "yyyy-mm-dd\Thh:nn:ss") & "Z"
End Function
