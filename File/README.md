/* =====================================================================
   return_back_merge_schema.sql
   Mục 2c — GỘP "đề nghị nhận lại hàng" VÀO LUÔN chỉ thị back hàng.

   CHẠY SAU return_instruction_schema.sql → return_receiving_schema.sql →
   return_actual_schema.sql.
   Chạy được dù trước đó đã chạy return_back_request_schema.sql /
   return_back_v2_schema.sql hay chưa. Chạy lại nhiều lần không sao.

   ---------------------------------------------------------------------
   QUYẾT ĐỊNH 09/11: MỘT PHIẾU = MỘT LUỒNG BACK

   Hàng về nhiều đợt thì mỗi đợt một chỉ thị, nên không có chuyện một
   phiếu nhận nhiều đợt — do đó không cần bảng đề nghị riêng.

     B1  FA đề nghị nhận lại hàng       back_status = fa_requested
         (không gửi mail)
     B2  Quản lý FA xác nhận             back_status = fa_approved
         -> mail TO SCS Office, CC FA
         SCS Office tự thông báo SCS WH (ngoài hệ thống)
     B3  SCS WH quét Pallet ID giao hàng back_status = delivered
         -> mail TO FA, CC SCS

   ---------------------------------------------------------------------
   HAI THỨ BỊ BỎ, VÀ VÌ SAO

   1. Bảng wms.return_back_request_lines — BỎ HẲN.
      Từ lúc chốt "lấy là lấy hết", bảng này không giữ thông tin nào của
      riêng nó: nó chỉ là ẢNH CHỤP của một phép suy ra từ sổ serial.

      Ảnh chụp đó đã sinh ra một lỗi im lặng: FA đề nghị khi phiếu có 100
      con (total_qty = 100), WH nhận thêm 50 con vào phiếu, rồi WH quét
      giao. Điều kiện đóng đề nghị đếm theo PHIẾU nên 150 con đi hết và
      đề nghị đóng, trong khi total_qty vẫn là 100 — mail gửi FA ghi
      "đã giao 150 con trên tổng 100 con".

      Gộp xong thì không còn tổng nào được lưu: mọi con số đọc trực tiếp
      từ wms.return_instruction_serials, nên không có gì để lệch.

   2. Cột current_step / back_step — BỎ HẲN.
      Với ba bước thì bước-đang-chờ SUY ĐƯỢC từ back_status một-đối-một:
        fa_requested -> đang chờ quản lý FA
        fa_approved  -> đang chờ SCS WH giao
        delivered    -> xong
        cancelled    -> xong
      Hai cột nói cùng một việc là hai cột sớm muộn lệch nhau.

   ---------------------------------------------------------------------
   ĐẾM SỐ THẾ NÀO SAU KHI GỘP (không cột tổng nào được lưu)

     còn ở kho chưa giao  = COUNT(status = 'received')
     đã từng giao FA      = COUNT(sent_fa_at IS NOT NULL)
     đang ở FA            = COUNT(status = 'at_fa')
     FA đã trả về         = COUNT(status = 'returned')

   "Đã từng giao" bám sent_fa_at chứ không bám status = 'at_fa': hàng
   giao rồi FA trả lại hết (mục 3) thì status về 'returned', mà lượt giao
   đó vẫn đã xảy ra.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* 1 = chỉ xem sẽ làm gì, không ghi. */
DECLARE @WhatIf bit = 0;

/* ---------- 0. Tiền đề ---------- */
IF OBJECT_ID(N'wms.return_instructions', N'U') IS NULL
BEGIN
    RAISERROR(N'Khong tim thay wms.return_instructions — chay return_instruction_schema.sql truoc.', 16, 1);
    RETURN;
END

IF OBJECT_ID(N'wms.return_instruction_serials', N'U') IS NULL
BEGIN
    RAISERROR(N'Khong tim thay wms.return_instruction_serials — chay return_receiving_schema.sql truoc.', 16, 1);
    RETURN;
END

DECLARE @had_req   bit = IIF(OBJECT_ID(N'wms.return_back_requests',   N'U') IS NULL, 0, 1);
DECLARE @had_lines bit = IIF(OBJECT_ID(N'wms.return_back_request_lines', N'U') IS NULL, 0, 1);
DECLARE @had_deliv bit = IIF(OBJECT_ID(N'wms.return_back_deliveries', N'U') IS NULL, 0, 1);

DECLARE @n_req int = 0;
IF @had_req = 1
    SET @n_req = (SELECT COUNT(*) FROM wms.return_back_requests WHERE is_deleted = 0);

/* Một phiếu có nhiều hơn một đề nghị thì gộp sẽ MẤT dữ liệu — phải dừng
   lại cho người ta xem, không được tự chọn giữ cái nào. */
DECLARE @n_multi int = 0;
IF @had_req = 1
    SET @n_multi = (SELECT COUNT(*) FROM (
        SELECT doc_id FROM wms.return_back_requests
        WHERE is_deleted = 0 GROUP BY doc_id HAVING COUNT(*) > 1) x);

SELECT N'0. Hien trang' AS section;
SELECT  bang_de_nghi      = IIF(@had_req = 1, N'DA CO — se di tru roi DROP', N'chua co'),
        so_de_nghi_that   = @n_req,
        phieu_nhieu_de_nghi = @n_multi,
        bang_dong_dong    = IIF(@had_lines = 1, N'DA CO — se DROP', N'chua co'),
        bang_pallet_giao  = IIF(@had_deliv = 1, N'DA CO — se tro sang doc_id', N'se tao moi'),
        che_do            = IIF(@WhatIf = 1, N'WhatIf — chua ghi gi', N'GHI THAT');

IF @n_multi > 0
BEGIN
    SELECT N'0b. Phieu co NHIEU de nghi — xem roi quyet' AS section;
    SELECT  r.doc_id, d.doc_no, so_de_nghi = COUNT(*),
            cac_so = STRING_AGG(r.req_no, N', ')
    FROM    wms.return_back_requests r
    JOIN    wms.return_instructions d ON d.id = r.doc_id
    WHERE   r.is_deleted = 0
    GROUP BY r.doc_id, d.doc_no;

    RAISERROR(N'Co phieu mang nhieu de nghi — gop lai se mat du lieu. Xem bang tren, xoa bot roi chay lai.', 16, 1);
    RETURN;
END

IF @WhatIf = 1
BEGIN
    SELECT N'WhatIf = 1 — chua ghi gi.' AS ket_qua;
    RETURN;
END

BEGIN TRAN;

/* =====================================================================
   1. 13 cột back_* trên wms.return_instructions

   BỌC TRONG EXEC(N'…'): batch này không có GO, mà SQL Server bind TÊN CỘT
   lúc biên dịch cả batch. Thêm cột bằng ALTER rồi dùng ngay cột đó trong
   cùng batch ⇒ lỗi 207 và KHÔNG CÂU NÀO chạy. Tên BẢNG thì không sao
   (deferred name resolution), chỉ tên CỘT mới cần bọc.
   ===================================================================== */
IF COL_LENGTH(N'wms.return_instructions', N'back_status') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_status nvarchar(20) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_note') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_note nvarchar(500) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_requested_by') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_requested_by nvarchar(100) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_requested_at') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_requested_at datetime2(0) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_approved_by') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_approved_by nvarchar(100) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_approved_at') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_approved_at datetime2(0) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_fa_comment') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_fa_comment nvarchar(500) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_delivered_by') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_delivered_by nvarchar(100) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_delivered_at') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_delivered_at datetime2(0) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_scs_comment') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_scs_comment nvarchar(500) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_cancelled_by') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_cancelled_by nvarchar(100) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_cancelled_at') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_cancelled_at datetime2(0) NULL;');

IF COL_LENGTH(N'wms.return_instructions', N'back_cancel_reason') IS NULL
    EXEC(N'ALTER TABLE wms.return_instructions ADD back_cancel_reason nvarchar(500) NULL;');

PRINT N'1. Da bo sung 13 cot back_* tren wms.return_instructions';

/* Nới rộng nếu một lần chạy trước đã tạo cột ở nvarchar(50).
   COL_LENGTH trả về số BYTE: nvarchar(50) = 100, nvarchar(100) = 200.
   Mọi cột *_by khác trong solution đều NVARCHAR(100) — hẹp hơn là câu di trú
   ở mục 3 gãy với loi 8152 khi gap mot ho ten dai. */
IF COL_LENGTH(N'wms.return_instructions', N'back_requested_by') < 200
    EXEC(N'ALTER TABLE wms.return_instructions ALTER COLUMN back_requested_by nvarchar(100) NULL;');
IF COL_LENGTH(N'wms.return_instructions', N'back_approved_by') < 200
    EXEC(N'ALTER TABLE wms.return_instructions ALTER COLUMN back_approved_by nvarchar(100) NULL;');
IF COL_LENGTH(N'wms.return_instructions', N'back_delivered_by') < 200
    EXEC(N'ALTER TABLE wms.return_instructions ALTER COLUMN back_delivered_by nvarchar(100) NULL;');
IF COL_LENGTH(N'wms.return_instructions', N'back_cancelled_by') < 200
    EXEC(N'ALTER TABLE wms.return_instructions ALTER COLUMN back_cancelled_by nvarchar(100) NULL;');

IF OBJECT_ID(N'wms.return_back_deliveries', N'U') IS NOT NULL
   AND COL_LENGTH(N'wms.return_back_deliveries', N'delivered_by') < 200
    EXEC(N'ALTER TABLE wms.return_back_deliveries ALTER COLUMN delivered_by nvarchar(100) NULL;');

/* back_status NULL = FA chưa đề nghị gì. Ràng buộc phải cho phép NULL,
   nếu không thì mọi phiếu cũ vi phạm ngay. */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'ck_ri_back_status')
    EXEC(N'ALTER TABLE wms.return_instructions
             ADD CONSTRAINT ck_ri_back_status CHECK (back_status IS NULL OR back_status IN
                 (N''fa_requested'', N''fa_approved'', N''delivered'', N''cancelled''));');

PRINT N'   + ck_ri_back_status';

/* Lọc hàng đợi "phiếu đang chờ tôi" — chỉ số lọc, bỏ hẳn phiếu chưa đề nghị
   (phần lớn bảng) khỏi chỉ số. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ri_back_status')
    EXEC(N'CREATE INDEX ix_ri_back_status ON wms.return_instructions(back_status)
             INCLUDE (doc_no, goods_type) WHERE back_status IS NOT NULL;');

PRINT N'   + ix_ri_back_status';

/* =====================================================================
   2. wms.return_back_deliveries — nhật ký từng lượt quét pallet

   Đây là bảng DUY NHẤT còn lại của luồng back, và nó phải ở lại: giao
   dần nhiều lượt thì không có nó thì không ai trả lời được "đã đẩy những
   pallet nào rồi".

   KHÔNG FK sang wms.pallets: pallet có thể bị tách / gộp / xoá sau khi
   hàng đã sang FA, mà dòng nhật ký thì phải còn. Giữ lot_no dạng chữ.

   KHÔNG unique trên (doc_id, lot_no): giao dần thì MỘT pallet có thể đi
   ở hai lượt khác nhau (lượt đầu chưa chuyển hết con trên đó).
   ===================================================================== */
IF @had_deliv = 0
BEGIN
    CREATE TABLE wms.return_back_deliveries
    (
        id           bigint IDENTITY(1,1) NOT NULL,
        doc_id       bigint         NOT NULL,
        pallet_id    bigint         NULL,
        lot_no       nvarchar(30)   NOT NULL,
        serial_count int            NOT NULL CONSTRAINT df_rbd_cnt DEFAULT (0),
        delivered_at datetime2(0)   NOT NULL CONSTRAINT df_rbd_at DEFAULT (SYSDATETIME()),
        delivered_by nvarchar(100)  NULL,

        CONSTRAINT pk_return_back_deliveries PRIMARY KEY CLUSTERED (id),
        CONSTRAINT fk_rbd_doc FOREIGN KEY (doc_id)
            REFERENCES wms.return_instructions (id)
    );

    /* Đường đọc DUY NHẤT của bảng này là "nhật ký của phiếu X, mới nhất
       trước". INCLUDE đủ bốn cột câu đó select nên nó chạy gọn trong chỉ số,
       không phải lần về bảng. */
    CREATE NONCLUSTERED INDEX ix_rbd_doc
        ON wms.return_back_deliveries (doc_id, delivered_at DESC)
        INCLUDE (lot_no, serial_count, delivered_by);
    PRINT N'2. Da tao wms.return_back_deliveries (theo doc_id)';
END
ELSE IF COL_LENGTH(N'wms.return_back_deliveries', N'doc_id') IS NULL
BEGIN
    /* Bảng đã có theo request_id -> thêm doc_id, suy từ đề nghị, rồi bỏ
       request_id. Làm đúng thứ tự này để không mất dòng nhật ký nào. */
    EXEC(N'ALTER TABLE wms.return_back_deliveries ADD doc_id bigint NULL;');

    /* Suy doc_id từ đề nghị. Bảng đề nghị không còn thì không suy được —
       lúc đó mọi dòng nhật ký thành rác và bị bỏ ở câu DELETE dưới. */
    IF @had_req = 1
        EXEC(N'UPDATE d SET d.doc_id = r.doc_id
                 FROM wms.return_back_deliveries d
                 JOIN wms.return_back_requests r ON r.id = d.request_id;');

    /* Dòng không suy ra được phiếu thì bỏ — nhật ký trỏ vào một đề nghị
       không còn tồn tại thì cũng không tra được gì. */
    EXEC(N'DELETE FROM wms.return_back_deliveries WHERE doc_id IS NULL;');

    /* Dọn MỌI thứ còn bám vào cột request_id, tìm THEO CỘT chứ không theo
       tên: tên do script trước đặt (fk_rbd_req, ix_rbd_req) và đoán tên là
       sai — lần đầu tôi lọc name LIKE '%request%' nên không khớp 'fk_rbd_req',
       và ALTER DROP COLUMN gãy với lỗi 5074.

       Ba loại phụ thuộc phải dọn, đúng thứ tự này: khoá ngoại → chỉ số →
       ràng buộc mặc định. Bỏ sót loại nào thì DROP COLUMN vẫn gãy. */
    DECLARE @colid int = COLUMNPROPERTY(
        OBJECT_ID(N'wms.return_back_deliveries'), N'request_id', 'ColumnId');
    DECLARE @sql nvarchar(max) = N'';

    /* 1 — khoá ngoại tham chiếu cột này (có thể nhiều hơn một) */
    SELECT @sql = @sql + N'ALTER TABLE wms.return_back_deliveries DROP CONSTRAINT '
                       + QUOTENAME(fk.name) + N';' + CHAR(10)
    FROM   sys.foreign_keys fk
    JOIN   sys.foreign_key_columns c ON c.constraint_object_id = fk.object_id
    WHERE  fk.parent_object_id = OBJECT_ID(N'wms.return_back_deliveries')
           AND c.parent_column_id = @colid;

    /* 2 — chỉ số có cột này, dù là cột khoá hay cột INCLUDE */
    SELECT @sql = @sql + N'DROP INDEX ' + QUOTENAME(i.name)
                       + N' ON wms.return_back_deliveries;' + CHAR(10)
    FROM   sys.indexes i
    JOIN   sys.index_columns ic ON ic.object_id = i.object_id
                               AND ic.index_id = i.index_id
    WHERE  i.object_id = OBJECT_ID(N'wms.return_back_deliveries')
           AND ic.column_id = @colid
           AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
           AND i.type_desc <> N'HEAP';

    /* 3 — ràng buộc mặc định gắn vào cột */
    SELECT @sql = @sql + N'ALTER TABLE wms.return_back_deliveries DROP CONSTRAINT '
                       + QUOTENAME(d.name) + N';' + CHAR(10)
    FROM   sys.default_constraints d
    WHERE  d.parent_object_id = OBJECT_ID(N'wms.return_back_deliveries')
           AND d.parent_column_id = @colid;

    IF LEN(@sql) > 0
    BEGIN
        PRINT N'   Don phu thuoc cua cot request_id:';
        PRINT @sql;
        EXEC sp_executesql @sql;
    END

    EXEC(N'ALTER TABLE wms.return_back_deliveries DROP COLUMN request_id;');
    EXEC(N'ALTER TABLE wms.return_back_deliveries ALTER COLUMN doc_id bigint NOT NULL;');

    /* Gác theo tên: nếu một lần chạy trước đã thêm được FK rồi mới gãy ở câu
       sau thì chạy lại không được đâm vào lỗi "tên đã tồn tại". */
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'fk_rbd_doc')
        EXEC(N'ALTER TABLE wms.return_back_deliveries
                 ADD CONSTRAINT fk_rbd_doc FOREIGN KEY (doc_id)
                     REFERENCES wms.return_instructions(id);');

    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_rbd_doc'
                     AND object_id = OBJECT_ID(N'wms.return_back_deliveries'))
        EXEC(N'CREATE NONCLUSTERED INDEX ix_rbd_doc
                 ON wms.return_back_deliveries (doc_id, delivered_at DESC)
                 INCLUDE (lot_no, serial_count, delivered_by);');

    PRINT N'2. Da chuyen wms.return_back_deliveries tu request_id sang doc_id';
END
ELSE
    PRINT N'2. wms.return_back_deliveries da theo doc_id — bo qua';

/* =====================================================================
   3. Di trú dữ liệu đề nghị đang có sang cột back_* của phiếu

   Chỉ ghi vào phiếu CHƯA có back_status: chạy lại script lần hai không
   được ghi đè thứ người ta đã thao tác sau lần một.
   ===================================================================== */
IF @had_req = 1 AND @n_req > 0
BEGIN
    EXEC(N'
    UPDATE  d
    SET     d.back_status =
                CASE r.req_status
                    WHEN N''scs_instructed'' THEN N''fa_approved''   /* bản 4 bước */
                    WHEN N''scs_approved''   THEN N''delivered''     /* bản 4 bước */
                    ELSE r.req_status
                END,
            d.back_note          = r.note,
            d.back_requested_by  = r.requested_by,
            d.back_requested_at  = r.requested_at,
            d.back_approved_by   = r.fa_approved_by,
            d.back_approved_at   = r.fa_approved_at,
            d.back_fa_comment    = r.fa_comment,
            d.back_scs_comment   = r.scs_comment,
            d.back_cancelled_by  = r.cancelled_by,
            d.back_cancelled_at  = r.cancelled_at,
            d.back_cancel_reason = r.cancel_reason
    FROM    wms.return_instructions d
    JOIN    wms.return_back_requests r ON r.doc_id = d.id AND r.is_deleted = 0
    WHERE   d.back_status IS NULL;
    PRINT CONCAT(N''3. Da di tru '', @@ROWCOUNT, N'' de nghi vao cot back_* cua phieu'');');

    /* delivered_by/at chỉ có ở bản 3 bước — bản 4 bước không có cột này,
       nên phải dò rồi mới UPDATE, và bọc EXEC vì tên cột có thể không tồn tại. */
    IF COL_LENGTH(N'wms.return_back_requests', N'delivered_at') IS NOT NULL
    BEGIN
        EXEC(N'
        UPDATE  d
        SET     d.back_delivered_by = r.delivered_by,
                d.back_delivered_at = r.delivered_at
        FROM    wms.return_instructions d
        JOIN    wms.return_back_requests r ON r.doc_id = d.id AND r.is_deleted = 0
        WHERE   d.back_delivered_at IS NULL;
        PRINT CONCAT(N''   + moc giao hang cho '', @@ROWCOUNT, N'' phieu'');');
    END
END
ELSE
    PRINT N'3. Khong co de nghi nao de di tru';

/* =====================================================================
   4. Sổ serial — bỏ cột back_request_id

   Sau khi gộp thì "con này thuộc đề nghị nào" không còn nghĩa: đề nghị
   là của chính phiếu, mà doc_id đã có sẵn trên dòng serial. sent_fa_at
   mới là mốc phân biệt đã giao / chưa giao.

   Index phải DROP trước cột, không thì ALTER báo lỗi phụ thuộc.
   ===================================================================== */
IF COL_LENGTH(N'wms.return_instruction_serials', N'back_request_id') IS NOT NULL
BEGIN
    /* Cùng khuôn với mục 2: dọn theo CỘT, không theo tên. */
    DECLARE @colid2 int = COLUMNPROPERTY(
        OBJECT_ID(N'wms.return_instruction_serials'), N'back_request_id', 'ColumnId');
    DECLARE @sql2 nvarchar(max) = N'';

    SELECT @sql2 = @sql2 + N'ALTER TABLE wms.return_instruction_serials DROP CONSTRAINT '
                         + QUOTENAME(fk.name) + N';' + CHAR(10)
    FROM   sys.foreign_keys fk
    JOIN   sys.foreign_key_columns c ON c.constraint_object_id = fk.object_id
    WHERE  fk.parent_object_id = OBJECT_ID(N'wms.return_instruction_serials')
           AND c.parent_column_id = @colid2;

    SELECT @sql2 = @sql2 + N'DROP INDEX ' + QUOTENAME(i.name)
                         + N' ON wms.return_instruction_serials;' + CHAR(10)
    FROM   sys.indexes i
    JOIN   sys.index_columns ic ON ic.object_id = i.object_id
                               AND ic.index_id = i.index_id
    WHERE  i.object_id = OBJECT_ID(N'wms.return_instruction_serials')
           AND ic.column_id = @colid2
           AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
           AND i.type_desc <> N'HEAP';

    SELECT @sql2 = @sql2 + N'ALTER TABLE wms.return_instruction_serials DROP CONSTRAINT '
                         + QUOTENAME(d.name) + N';' + CHAR(10)
    FROM   sys.default_constraints d
    WHERE  d.parent_object_id = OBJECT_ID(N'wms.return_instruction_serials')
           AND d.parent_column_id = @colid2;

    IF LEN(@sql2) > 0
    BEGIN
        PRINT N'   Don phu thuoc cua cot back_request_id:';
        PRINT @sql2;
        EXEC sp_executesql @sql2;
    END

    EXEC(N'ALTER TABLE wms.return_instruction_serials DROP COLUMN back_request_id;');
    PRINT N'4. Da bo cot back_request_id khoi so serial';
END
ELSE
    PRINT N'4. So serial khong co back_request_id — bo qua';

/* sent_fa_at là mốc "đã từng giao", nên nó phải có. Bản 2c trước đã thêm,
   nhưng nếu chạy script này trên DB chưa qua 2c thì chưa có. */
IF COL_LENGTH(N'wms.return_instruction_serials', N'sent_fa_at') IS NULL
BEGIN
    EXEC(N'ALTER TABLE wms.return_instruction_serials ADD sent_fa_at datetime2(0) NULL;');
    PRINT N'   + cot sent_fa_at';
END

IF COL_LENGTH(N'wms.return_instruction_serials', N'returned_at') IS NULL
BEGIN
    EXEC(N'ALTER TABLE wms.return_instruction_serials ADD returned_at datetime2(0) NULL;');
    PRINT N'   + cot returned_at';
END

/* Chỉ số cho câu hỏi nóng nhất của màn giao hàng: "phiếu này còn con nào
   ở received". Lọc sẵn theo status để chỉ số nhỏ. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ris_pickable'
                 AND object_id = OBJECT_ID(N'wms.return_instruction_serials'))
    EXEC(N'CREATE INDEX ix_ris_pickable
             ON wms.return_instruction_serials(doc_id, pallet_id)
             INCLUDE (model) WHERE status = N''received'' AND is_deleted = 0;');

PRINT N'   + ix_ris_pickable';

/* =====================================================================
   5. DROP hai bảng của luồng cũ

   Làm CUỐI CÙNG, sau khi đã di trú xong ở mục 3 — và trong cùng
   transaction, nên lỗi ở bất kỳ mục nào cũng không để lại cảnh nửa vời.
   ===================================================================== */
IF @had_lines = 1
BEGIN
    DROP TABLE wms.return_back_request_lines;
    PRINT N'5. Da DROP wms.return_back_request_lines';
END

IF @had_req = 1
BEGIN
    DROP TABLE wms.return_back_requests;
    PRINT N'   Da DROP wms.return_back_requests';
END

IF @had_req = 0 AND @had_lines = 0
    PRINT N'5. Khong co bang cu nao de DROP';

COMMIT;

/* =====================================================================
   6. Mẫu mail — bỏ {ReqNo}, dùng {DocNo}

   Hai mã sự kiện GIỮ NGUYÊN (RETURN_BACK_FA_APPROVED,
   RETURN_BACK_DELIVERED): luồng không đổi, chỉ đổi chỗ treo dữ liệu. Giữ
   nguyên mã thì người nhận đã khai trong master.email_config không phải
   khai lại.

   Chỉ đè mẫu khi CHƯA ai sửa tay (updated_at còn NULL).
   ===================================================================== */
IF OBJECT_ID(N'master.email_events', N'U') IS NULL
BEGIN
    PRINT N'6. Khong tim thay master.email_events — chay return_back_mail_schema.sql truoc';
    RETURN;
END

DECLARE @subj_fa NVARCHAR(500) =
    N'[SWMS] FA đề nghị nhận lại hàng {GoodsType} — chỉ thị {DocNo} ({RemainQty} con)';

DECLARE @body_fa NVARCHAR(MAX) = N'Kính gửi SCS Office,

Quản lý FA đã xác nhận đề nghị nhận lại **toàn bộ** hàng của chỉ thị **{DocNo}**.
Nhờ SCS thông báo kho chuẩn bị giao.

| Thông tin | Nội dung |
|---|---|
| Chỉ thị nhận hàng | **{DocNo}** ({GoodsType}) |
| Khách hàng | {Customer} |
| Số model | {ModelCount} |
| **Số lượng cần giao** | **{RemainQty}** |
| Người đề nghị | {RequestedBy} — {RequestedAt} |
| Quản lý FA xác nhận | {ApprovedBy} — {ApprovedAt} |

**Chi tiết theo model:**
{LinesTable}
Ghi chú của FA: {BackNote}

Ý kiến quản lý FA: {FaComment}

Xem trên hệ thống: {Link}

*Mail tự động từ SWMS Finish Goods — {Now}*';

DECLARE @subj_dl NVARCHAR(500) =
    N'[SWMS] SCS đã giao {DeliveredQty} con hàng {GoodsType} cho FA — {DocNo}';

DECLARE @body_dl NVARCHAR(MAX) = N'Kính gửi FA,

SCS Warehouse vừa giao hàng của chỉ thị **{DocNo}**.

| Thông tin | Nội dung |
|---|---|
| Chỉ thị nhận hàng | **{DocNo}** ({GoodsType}) |
| Khách hàng | {Customer} |
| **Số lượng giao lượt này** | **{DeliveredQty}** |
| Số pallet giao lượt này | {PalletCount} |
| Đang ở FA | {AtFaQty} |
| Còn ở kho chưa giao | **{RemainQty}** |
| Người giao | {DeliveredBy} — {DeliveredAt} |

**Pallet đã giao lượt này:**
{PalletTable}
Ghi chú của kho: {ScsComment}

Nhờ FA nhận hàng và khi rework xong thì đóng lại Pallet ID trên PDA.

Xem trên hệ thống: {Link}

*Mail tự động từ SWMS Finish Goods — {Now}*';

BEGIN TRAN;

DECLARE @ev TABLE (code nvarchar(100), descr nvarchar(400),
                   subj nvarchar(500), body nvarchar(MAX), ord int);

INSERT INTO @ev (code, descr, subj, body, ord)
VALUES
    (N'RETURN_BACK_FA_APPROVED',
     N'Mục 2c — quản lý FA xác nhận đề nghị nhận lại hàng. TO: SCS Office, CC: FA',
     @subj_fa, @body_fa, 1),
    (N'RETURN_BACK_DELIVERED',
     N'Mục 2c — SCS WH quét Pallet ID giao hàng cho FA xong. TO: FA, CC: SCS',
     @subj_dl, @body_dl, 2);

DECLARE @base int =
    (SELECT ISNULL(MAX(sort_order), 0) FROM master.email_events WHERE module = N'RECEIVING');

INSERT INTO master.email_events
    (code, module, name_key, description, subject_template, body_template,
     is_active, sort_order)
SELECT  e.code, N'RECEIVING', N'email.' + e.code, e.descr, e.subj, e.body, 1, @base + e.ord
FROM    @ev e
WHERE   NOT EXISTS (SELECT 1 FROM master.email_events x WHERE x.code = e.code);

PRINT CONCAT(N'6. Da them ', @@ROWCOUNT, N' su kien mail moi');

UPDATE  t
SET     t.subject_template = e.subj,
        t.body_template    = e.body,
        t.description      = e.descr
FROM    master.email_events t
JOIN    @ev e ON e.code = t.code
WHERE   t.updated_at IS NULL;

PRINT CONCAT(N'   Da cap nhat mau cho ', @@ROWCOUNT, N' su kien (chua ai sua tay)');

/* Dọn 3 sự kiện của bản 4 bước, nếu return_back_mail_schema.sql chưa dọn. */
DECLARE @dead TABLE (code nvarchar(100));
INSERT INTO @dead (code)
VALUES (N'RETURN_BACK_REQUESTED'), (N'RETURN_BACK_INSTRUCTED'), (N'RETURN_BACK_APPROVED');

UPDATE  e SET e.is_active = 0
FROM    master.email_events e JOIN @dead d ON d.code = e.code
WHERE   e.is_active = 1;

DELETE  e
FROM    master.email_events e JOIN @dead d ON d.code = e.code
WHERE   e.updated_at IS NULL
        AND NOT EXISTS (SELECT 1 FROM master.email_config c
                        WHERE c.event_code = e.code AND c.is_deleted = 0);

PRINT CONCAT(N'   Da XOA ', @@ROWCOUNT, N' su kien cua ban 4 buoc');

COMMIT;

/* =====================================================================
   7. Kiểm lại
   ===================================================================== */
SELECT N'7. Cot back_* tren wms.return_instructions' AS section;
SELECT  ten_cot = c.name, kieu = t.name,
        do_dai = IIF(t.name LIKE N'%char%', CONVERT(nvarchar(10), c.max_length / 2), N''),
        cho_null = IIF(c.is_nullable = 1, N'co', N'KHONG')
FROM    sys.columns c
JOIN    sys.types t ON t.user_type_id = c.user_type_id
WHERE   c.object_id = OBJECT_ID(N'wms.return_instructions')
        AND c.name LIKE N'back_%'
ORDER BY c.column_id;

SELECT N'8. Bang cu da bien chua' AS section;
SELECT  bang = v.n,
        con_lai = IIF(OBJECT_ID(v.n, N'U') IS NULL, N'da DROP', N'VAN CON — xem lai')
FROM    (VALUES (N'wms.return_back_requests'),
                (N'wms.return_back_request_lines')) v(n);

SELECT N'9. Mail' AS section;
SELECT  ma = e.code, dang_bat = IIF(e.is_active = 1, N'co', N'KHONG'),
        da_sua_tay = IIF(e.updated_at IS NULL, N'khong', N'CO'),
        con_bien_ReqNo = IIF(e.subject_template LIKE N'%{ReqNo}%'
                             OR e.body_template LIKE N'%{ReqNo}%',
                             N'CON — sua lai thanh {DocNo}', N'khong'),
        so_nguoi_nhan = (SELECT COUNT(*) FROM master.email_config c
                         WHERE c.event_code = e.code AND c.is_active = 1 AND c.is_deleted = 0)
FROM    master.email_events e
WHERE   e.code LIKE N'RETURN_BACK%'
ORDER BY e.sort_order;

SELECT N'10. Viec con phai lam tay' AS section;
SELECT N'Mo man Tai gia cong -> banh rang, khai nguoi nhan:' AS ghi_chu
UNION ALL SELECT N'  · RETURN_BACK_FA_APPROVED : TO = SCS Office, CC = FA'
UNION ALL SELECT N'  · RETURN_BACK_DELIVERED   : TO = FA,         CC = SCS'
UNION ALL SELECT N'Khong co dong TO nao dang bat thi KHONG gui.'
UNION ALL SELECT N'Quyen: FA = request_back · QL FA = approve_fa · SCS WH = process.'
UNION ALL SELECT N'approve_scs KHONG con cho dung — dung gan cho role nao.';
