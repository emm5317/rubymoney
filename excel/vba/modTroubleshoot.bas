Attribute VB_Name = "modTroubleshoot"
Option Explicit

Public Sub FixTransactionsTableHeaders()
    Dim ws As Worksheet
    Dim tbl As ListObject
    Dim topLeft As Range

    Set ws = ThisWorkbook.Worksheets("Transactions")
    Set tbl = ws.ListObjects("transactions")
    Set topLeft = tbl.Range.Cells(1, 1)

    tbl.Resize topLeft.Resize(2, 20)
    tbl.HeaderRowRange.Resize(1, 20).Value = Array("txn_id", "external_txn_id", "account_id", "posted_date", "amount", "payee", "memo", "category", "subcategory", "category_source", "pending", "fingerprint", "imported_at", "raw_ref", "suggested_category", "suggested_subcategory", "suggested_confidence", "suggested_status", "suggested_model_id", "suggested_reason_code")

    If Not tbl.DataBodyRange Is Nothing Then
        tbl.DataBodyRange.Delete
    End If
End Sub
