try
{
    // ========== VALIDATE ==========
    if (inboundFile == null || inboundFile.Length == 0)
        return Json(new { success = false, message = "Vui lòng chọn file ZMV029." });

    if (vendorConfirmFile == null || vendorConfirmFile.Length == 0)
        return Json(new { success = false, message = "Vui lòng chọn file ZMV132." });

    var extension = Path.GetExtension(vendorConfirmFile.FileName).ToLower();
    if (extension != ".csv")
        return Json(new { success = false, message = "File ZMV132 phải là định dạng .csv" });

    // ========== XỬ LÝ ZMV029 (Excel) ==========
    using var stream = new MemoryStream();
    await inboundFile.CopyToAsync(stream);
    using var workbook = new XLWorkbook(stream);
    var ws = workbook.Worksheet(1);
    var rows = ws.RangeUsed().RowsUsed().Skip(1);

    var data = new List<(string Plant, string Vendor, string DelivDate, string Material, string InboundQty)>();
    foreach (var row in rows)
    {
        var plant = row.Cell(1).GetString().Trim();
        var vendor = row.Cell(2).GetString().Trim();
        var delivDate = row.Cell(6).GetString().Trim();
        var material = row.Cell(8).GetString().Trim();
        var inboundQty = row.Cell(9).GetString().Trim();

        if (string.IsNullOrEmpty(plant) || string.IsNullOrEmpty(material))
            continue;

        data.Add((plant, vendor, delivDate, material, inboundQty));
    }

    if (!data.Any())
        return Json(new { success = false, message = "Không có dữ liệu hợp lệ trong file ZMV029." });

    // ========== XỬ LÝ ZMV132 (CSV - BULK INSERT) ==========
    var fileName = $"{Guid.NewGuid()}_{Path.GetFileName(vendorConfirmFile.FileName)}";
    tempFilePath = Path.Combine(_uploadPath, fileName);

    await using (var fileStream = new FileStream(tempFilePath, FileMode.Create))
    {
        await vendorConfirmFile.CopyToAsync(fileStream);
    }

    // ========== EXECUTE ==========
    await using var connection = new SqlConnection(_connectionString);
    await connection.OpenAsync();
    using var transaction = connection.BeginTransaction();

    try
    {
        // Xóa ZMV029_STG và insert mới
        await using (var cmd = new SqlCommand("DELETE FROM ZMV029_STG", connection, transaction))
            await cmd.ExecuteNonQueryAsync();

        var insertSql = new StringBuilder();
        insertSql.AppendLine("INSERT INTO ZMV029_STG (Plant, DelivDate, Material, InboundQty, Vendor) VALUES");
        var values = data.Select(d =>
            $"(N'{d.Plant}', " +
            $"{(string.IsNullOrEmpty(d.DelivDate) ? "NULL" : $"'{d.DelivDate}'")}, " +
            $"N'{d.Material}', " +
            $"{(string.IsNullOrEmpty(d.InboundQty) ? "NULL" : d.InboundQty.Replace(",", ""))}, " +
            $"N'{d.Vendor})"
        );
        insertSql.AppendLine(string.Join(",\n", values));

        await using (var cmd = new SqlCommand(insertSql.ToString(), connection, transaction))
            await cmd.ExecuteNonQueryAsync();

        // Truncate ZMV132_STG và BULK INSERT
        await using (var cmd = new SqlCommand("TRUNCATE TABLE ZMV132_STG", connection, transaction))
            await cmd.ExecuteNonQueryAsync();

        var fmtPath = Path.Combine(_formatPath, "zmv132.fmt");
        var bulkSql = $@"
    BULK INSERT ZMV132_STG
    FROM '{tempFilePath}'
    WITH (
        FORMATFILE = '{fmtPath}',
        FIRSTROW = 3,
        CODEPAGE = '65001'
    )";

        await using (var cmd = new SqlCommand(bulkSql, connection, transaction))
        {
            cmd.CommandTimeout = 300;
            await cmd.ExecuteNonQueryAsync();
        }

        // Đếm số dòng ZMV132
        int zmv132Count = 0;
        await using (var cmd = new SqlCommand("SELECT COUNT(*) FROM ZMV132_STG", connection, transaction))
            zmv132Count = (int)(await cmd.ExecuteScalarAsync() ?? 0);

        // Recalculate
        await using (var cmd = new SqlCommand("sp_RecalculateAfterZMV029_ZMV132Upload", connection, transaction))
        {
            cmd.CommandType = CommandType.StoredProcedure;
            cmd.CommandTimeout = 600;
            await cmd.ExecuteNonQueryAsync();
        }

        // Log action
        _context.ActionHistories.Add(new ActionHistory
        {
            Username = User.Identity?.Name ?? "Anonymous",
            ActionName = "UpdateInbound",
            FileName = $"{inboundFile.FileName} | {vendorConfirmFile.FileName}"
        });
        await _context.SaveChangesAsync();

        await transaction.CommitAsync();

        return Json(new
        {
            success = true,
            message = $"Upload thành công: ZMV029 ({data.Count} dòng), ZMV132 ({zmv132Count:N0} dòng)."
        });
    }
    catch
    {
        await transaction.RollbackAsync();
        throw;
    }
}
catch (Exception ex)
{
    return Json(new { success = false, message = $"Có lỗi xảy ra: {ex.Message}" });
}
finally
{
    if (!string.IsNullOrEmpty(tempFilePath) && System.IO.File.Exists(tempFilePath))
    {
        try { System.IO.File.Delete(tempFilePath); } catch { }
    }
}


Lỗi: Microsoft.Data.SqlClient.SqlException
  HResult=0x80131904
  Message=Incorrect syntax near 'VR01'.
Incorrect syntax near 'VR01'.
Incorrect syntax near 'VR01'.
  Source=Core Microsoft SqlClient Data Provider
  StackTrace:
   at Microsoft.Data.SqlClient.SqlConnection.OnError(SqlException exception, Boolean breakConnection, Action`1 wrapCloseInAction)
   at Microsoft.Data.SqlClient.TdsParser.ThrowExceptionAndWarning(TdsParserStateObject stateObj, Boolean callerHasConnectionLock, Boolean asyncClose)
   at Microsoft.Data.SqlClient.TdsParser.TryRun(RunBehavior runBehavior, SqlCommand cmdHandler, SqlDataReader dataStream, BulkCopySimpleResultSet bulkCopyHandler, TdsParserStateObject stateObj, Boolean& dataReady)
   at Microsoft.Data.SqlClient.SqlCommand.InternalEndExecuteNonQuery(IAsyncResult asyncResult, Boolean isInternal, String endMethod)
   at Microsoft.Data.SqlClient.SqlCommand.EndExecuteNonQueryInternal(IAsyncResult asyncResult)
   at Microsoft.Data.SqlClient.SqlCommand.EndExecuteNonQueryAsync(IAsyncResult asyncResult)
   at System.Threading.Tasks.TaskFactory`1.FromAsyncCoreLogic(IAsyncResult iar, Func`2 endFunction, Action`1 endAction, Task`1 promise, Boolean requiresSynchronization)
--- End of stack trace from previous location ---
   at CriticalListReport.Controllers.UploadTCodeController.<UpdateInbound>d__12.MoveNext() in D:\1.SVN_Trung\CriticalList Application\CriticalList\CriticalListReport\CriticalListReport\Controllers\UploadTCodeController.cs:line 445
   at CriticalListReport.Controllers.UploadTCodeController.<UpdateInbound>d__12.MoveNext() in D:\1.SVN_Trung\CriticalList Application\CriticalList\CriticalListReport\CriticalListReport\Controllers\UploadTCodeController.cs:line 445

  This exception was originally thrown at this call stack:
    [External Code]
    CriticalListReport.Controllers.UploadTCodeController.UpdateInbound(Microsoft.AspNetCore.Http.IFormFile, Microsoft.AspNetCore.Http.IFormFile) in UploadTCodeController.cs
    CriticalListReport.Controllers.UploadTCodeController.UpdateInbound(Microsoft.AspNetCore.Http.IFormFile, Microsoft.AspNetCore.Http.IFormFile) in UploadTCodeController.cs
