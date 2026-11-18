/* =====================================================================
   DỰNG LẠI 6 ĐỐI TƯỢNG CÒN THIẾU TRÊN SWMS_FINISH_GOODS_DEV
   soạn 18/11/2026

   VÌ SAO KHÔNG COPY TỪ DB THẬT:
   DB thật SWMS_FINISH_GOODS CHƯA có 6 bảng này (chưa đồng bộ từ DEV lên).
   DEV mới là bản đủ nhất. Nên script này KHÔNG đọc DB thật một dòng nào —
   toàn bộ DDL dưới đây dựng lại từ CODE đang chạy:

     wms.ng_inspections            <- Features/AbnormalReports/DataAccess/NgReportRepository.cs
     wms.ng_inspection_items          + AbnormalReport.cs (NgReport / NgItem /
     wms.ng_inspection_photos           NgPhoto / NgApproval / NgTypeRow)
     wms.ng_inspection_approvals      + Business/NgReportService.cs (bộ giá trị
     master.ng_types                    hợp lệ cho các cột trạng thái)
     wms.stocky_carts              <- Features/Stocky/DataAccess/StockyRepository.cs
                                      + StockyEntity.cs

   CÁCH CHẠY
     1. Chạy nguyên file. Chạy LẠI được nhiều lần: mỗi đối tượng đều bọc
        IF ... IS NULL, có rồi thì bỏ qua, không bao giờ DROP.
     2. Đọc MỤC 8 ở cuối: nó tự đối chiếu từng cột với danh sách code cần.
     3. Chạy lại export_schema_compact.sql, gửi lại để đối chiếu lần cuối.

   ⚠ CHỐT AN TOÀN: script TỪ CHỐI chạy nếu DB hiện tại không có đuôi _DEV.
     Thêm chốt này sau sự cố mất DB dev — không để một câu lệnh nào của tôi
     chạm vào DB thật nữa.

   ⚠ KHÔNG dùng SELECT INTO / không đụng tới dữ liệu đang có. Script chỉ
     CREATE những gì chưa có.
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ---------------------------------------------------------------------
   MỤC 0 — CHỐT AN TOÀN + THAM SỐ
   --------------------------------------------------------------------- */
/* Tham số duy nhất của script nằm ở MỤC 7.3 (@SeedTypes) — khai tại chỗ
   dùng, vì biến KHÔNG sống qua GO. */

IF RIGHT(DB_NAME(), 4) <> N'_DEV'
BEGIN
    DECLARE @db sysname = DB_NAME();
    RAISERROR(N'DUNG LAI: dang o DB [%s], khong phai DB co duoi _DEV. Chuyen sang SWMS_FINISH_GOODS_DEV roi chay lai.',
              16, 1, @db);
    SET NOEXEC ON;
END

PRINT N'### DB dang lam viec = ' + DB_NAME();
PRINT N'';
GO

/* =====================================================================
   MỤC 1 — master.ng_types   (DANH MỤC LOẠI LỖI)
   ---------------------------------------------------------------------
   Khoá chính là CHÍNH MÃ (code), không có cột id: NgReportRepository
   .UpsertTypeAsync upsert theo code, và wms.ng_inspections.ng_type trỏ
   thẳng vào code. Comment trong repo gọi đích danh pk_ng_types.

   Tên/mô tả lưu sẵn 4 ngôn ngữ ngay trong bảng (xem chú thích lớp
   NgTypeRow): thêm loại lỗi = một dòng INSERT, không phải sửa resx của Web
   + JSON của PDA rồi build lại cả ba.

   requires_oqc nằm luôn ở đây vì "có cần OQC kết luận không" là thuộc
   tính của LOẠI LỖI (GetRequiresOqcAsync đọc đúng cột này).
   ===================================================================== */
IF SCHEMA_ID(N'master') IS NULL EXEC(N'CREATE SCHEMA master;');
GO
IF OBJECT_ID(N'master.ng_types', N'U') IS NULL
BEGIN
    CREATE TABLE master.ng_types
    (
        code          nvarchar(30)   NOT NULL,

        name_vi       nvarchar(200)  NOT NULL,
        name_en       nvarchar(200)  NULL,
        name_ja       nvarchar(200)  NULL,
        name_zh       nvarchar(200)  NULL,

        note_vi       nvarchar(500)  NULL,
        note_en       nvarchar(500)  NULL,
        note_ja       nvarchar(500)  NULL,
        note_zh       nvarchar(500)  NULL,

        /* Mặc định 1: loại lỗi mới khai mà quên nghĩ tới OQC thì cho đi qua
           OQC vẫn an toàn hơn là bỏ qua một bước duyệt chất lượng. */
        requires_oqc  bit            NOT NULL CONSTRAINT df_ng_types_oqc    DEFAULT (1),
        sort_order    int            NOT NULL CONSTRAINT df_ng_types_sort   DEFAULT (0),
        is_active     bit            NOT NULL CONSTRAINT df_ng_types_active DEFAULT (1),
        is_deleted    bit            NOT NULL CONSTRAINT df_ng_types_del    DEFAULT (0),

        created_at    datetime2(0)   NOT NULL CONSTRAINT df_ng_types_crat   DEFAULT SYSDATETIME(),
        created_by    nvarchar(100)  NULL,
        updated_at    datetime2(0)   NULL,
        updated_by    nvarchar(100)  NULL,

        CONSTRAINT pk_ng_types PRIMARY KEY (code)
    );
    PRINT N'1. Da tao master.ng_types';
END
ELSE PRINT N'1. master.ng_types da co — bo qua';
GO

/* =====================================================================
   MỤC 2 — wms.ng_inspections   (PHIẾU HÀNG BẤT THƯỜNG)
   ---------------------------------------------------------------------
   Luồng 5 bước TUẦN TỰ (xem chú thích lớp NgReport):
     1 SCS tạo  2 Leader SCS duyệt  3 OQC kết luận  4 FA chọn hướng  5 SCS chốt

   Ba cột trạng thái tách riêng (leader_status / oqc_status / fa_status)
   chứ không gộp vào một: ApplyStepAsync ghi từng bước độc lập, và câu
   tính lại current_step đọc đồng thời fa_status với oqc_status.

   leader_by_code tách khỏi leader_by: bước 5 phải so "người chốt có phải
   chính người duyệt bước 2" — so bằng MÃ NHÂN VIÊN mới chắc, so bằng họ
   tên sẽ báo nhầm khi hai người trùng tên.
   ===================================================================== */
IF SCHEMA_ID(N'wms') IS NULL EXEC(N'CREATE SCHEMA wms;');
GO
IF OBJECT_ID(N'wms.ng_inspections', N'U') IS NULL
BEGIN
    CREATE TABLE wms.ng_inspections
    (
        id              bigint         NOT NULL IDENTITY(1,1),
        doc_no          nvarchar(30)   NOT NULL,   -- NG-yyyyMMdd-nnn

        /* NULL được: phiếu có thể lập trước khi gắn pallet. Màn hình
           LEFT JOIN wms.pallets nên pallet đã xoá mềm vẫn đọc được phiếu. */
        lot_id          bigint         NULL,

        ng_type         nvarchar(30)   NOT NULL,
        description     nvarchar(1000) NULL,
        discovered_at   datetime2(0)   NOT NULL,

        /* 'submitted' khai sẵn trong CHECK: UpdateDraft kiểm
           DocStatus is not ("draft" or "submitted" or "in_review"), nên
           giá trị này phải hợp lệ dù luồng hiện tại chưa sinh ra nó. */
        doc_status      nvarchar(30)   NOT NULL CONSTRAINT df_ngi_docst DEFAULT N'draft',
        current_step    nvarchar(30)   NOT NULL CONSTRAINT df_ngi_step  DEFAULT N'created',

        leader_status   nvarchar(20)   NOT NULL CONSTRAINT df_ngi_ldst  DEFAULT N'pending',
        leader_by       nvarchar(100)  NULL,
        leader_by_code  nvarchar(50)   NULL,
        leader_at       datetime2(0)   NULL,
        leader_comment  nvarchar(1000) NULL,

        fa_status       nvarchar(20)   NOT NULL CONSTRAINT df_ngi_fast  DEFAULT N'pending',
        fa_resolution   nvarchar(20)   NULL,
        fa_by           nvarchar(100)  NULL,
        fa_at           datetime2(0)   NULL,
        fa_comment      nvarchar(1000) NULL,

        /* 'skipped' KHÁC 'pending' — nhờ vậy mọi guard tuần tự phía sau tự
           đúng khi loại lỗi không cần OQC (xem ApplyStepAsync nhánh leader). */
        oqc_status      nvarchar(20)   NOT NULL CONSTRAINT df_ngi_oqcst DEFAULT N'pending',
        oqc_by          nvarchar(100)  NULL,
        oqc_at          datetime2(0)   NULL,
        oqc_comment     nvarchar(1000) NULL,

        resolution      nvarchar(20)   NOT NULL CONSTRAINT df_ngi_res   DEFAULT N'pending',
        finalized_by    nvarchar(100)  NULL,
        finalized_at    datetime2(0)   NULL,
        final_comment   nvarchar(1000) NULL,

        cancelled_by    nvarchar(100)  NULL,
        cancelled_at    datetime2(0)   NULL,
        cancel_reason   nvarchar(500)  NULL,

        is_deleted      bit            NOT NULL CONSTRAINT df_ngi_del   DEFAULT (0),
        created_at      datetime2(0)   NOT NULL CONSTRAINT df_ngi_crat  DEFAULT SYSDATETIME(),
        created_by      nvarchar(100)  NULL,
        updated_at      datetime2(0)   NULL,
        updated_by      nvarchar(100)  NULL,

        CONSTRAINT pk_ng_inspections PRIMARY KEY (id),

        CONSTRAINT ck_ngi_doc_status CHECK (doc_status IN
            (N'draft', N'submitted', N'in_review', N'ready_to_finalize',
             N'finalized', N'cancelled')),
        CONSTRAINT ck_ngi_step CHECK (current_step IN
            (N'created', N'oqc_confirm', N'fa_confirm', N'scs_finalize', N'done')),
        CONSTRAINT ck_ngi_leader CHECK (leader_status IN
            (N'pending', N'submitted', N'cancelled')),
        CONSTRAINT ck_ngi_fa CHECK (fa_status IN (N'pending', N'approved')),
        CONSTRAINT ck_ngi_oqc CHECK (oqc_status IN
            (N'pending', N'skipped', N'ok', N'ng')),
        /* Bộ 4 hướng xử lý lấy từ NgReportService.Resolutions, cộng
           'pending' là giá trị khởi tạo. */
        CONSTRAINT ck_ngi_res CHECK (resolution IN
            (N'pending', N'replace', N'accept', N'return', N'scrap')),
        CONSTRAINT ck_ngi_fa_res CHECK (fa_resolution IS NULL OR fa_resolution IN
            (N'replace', N'accept', N'return', N'scrap'))
    );
    PRINT N'2. Da tao wms.ng_inspections';
END
ELSE PRINT N'2. wms.ng_inspections da co — bo qua';
GO

/* =====================================================================
   MỤC 3 — wms.ng_inspection_items   (PHẠM VI ẢNH HƯỞNG)
   ---------------------------------------------------------------------
   scope = pallet | box | serial. Khi MỌI mục đều là 'pallet' thì
   HeaderSelect tính whole_pallet = 1 và màn hình hiện "cả pallet" thay vì
   "1 cái" — nên scope phải đúng bộ ba này, không nhận giá trị lạ.

   Sửa phiếu nháp = xoá mềm toàn bộ mục cũ rồi chèn lại (UpdateDraftAsync),
   nên is_deleted phải có và mọi truy vấn đều lọc nó.
   ===================================================================== */
IF OBJECT_ID(N'wms.ng_inspection_items', N'U') IS NULL
BEGIN
    CREATE TABLE wms.ng_inspection_items
    (
        id            bigint        NOT NULL IDENTITY(1,1),
        ng_id         bigint        NOT NULL,

        scope         nvarchar(10)  NOT NULL CONSTRAINT df_ngit_scope DEFAULT N'serial',

        /* Cả ba đều NULL được: scope='pallet' chỉ điền pallet_id,
           scope='box' điền thêm box_id, scope='serial' điền box_line_id. */
        pallet_id     bigint        NULL,
        box_id        bigint        NULL,
        box_line_id   bigint        NULL,

        /* Mã người dùng quét/nhìn thấy (mã pallet, mã thùng, hoặc serial).
           Lưu lại CHUỖI để phiếu cũ vẫn đọc được khi dòng gốc bị xoá mềm. */
        code          nvarchar(100) NULL,

        qty_affected  int           NOT NULL CONSTRAINT df_ngit_qty DEFAULT (0),
        note          nvarchar(500) NULL,

        is_deleted    bit           NOT NULL CONSTRAINT df_ngit_del  DEFAULT (0),
        created_at    datetime2(0)  NOT NULL CONSTRAINT df_ngit_crat DEFAULT SYSDATETIME(),
        created_by    nvarchar(100) NULL,

        CONSTRAINT pk_ng_inspection_items PRIMARY KEY (id),
        CONSTRAINT ck_ngit_scope CHECK (scope IN (N'pallet', N'box', N'serial'))
    );
    PRINT N'3. Da tao wms.ng_inspection_items';
END
ELSE PRINT N'3. wms.ng_inspection_items da co — bo qua';
GO

/* =====================================================================
   MỤC 4 — wms.ng_inspection_photos   (ẢNH LỖI)
   ---------------------------------------------------------------------
   File gốc nằm trên đĩa, DB chỉ giữ ĐƯỜNG DẪN TƯƠNG ĐỐI (xem lớp NgPhoto).
   sort_order do AddPhotoAsync tự tính MAX+1 trong cùng phiếu.
   ===================================================================== */
IF OBJECT_ID(N'wms.ng_inspection_photos', N'U') IS NULL
BEGIN
    CREATE TABLE wms.ng_inspection_photos
    (
        id            bigint        NOT NULL IDENTITY(1,1),
        ng_id         bigint        NOT NULL,

        /* Gắn ảnh vào MỘT mục cụ thể; NULL = ảnh chung của cả phiếu. */
        item_id       bigint        NULL,

        file_path     nvarchar(400) NOT NULL,
        file_name     nvarchar(260) NOT NULL,
        content_type  nvarchar(100) NULL,
        size_bytes    bigint        NULL,
        caption       nvarchar(300) NULL,
        sort_order    int           NOT NULL CONSTRAINT df_ngph_sort DEFAULT (0),

        is_deleted    bit           NOT NULL CONSTRAINT df_ngph_del  DEFAULT (0),
        created_at    datetime2(0)  NOT NULL CONSTRAINT df_ngph_crat DEFAULT SYSDATETIME(),
        created_by    nvarchar(100) NULL,

        CONSTRAINT pk_ng_inspection_photos PRIMARY KEY (id)
    );
    PRINT N'4. Da tao wms.ng_inspection_photos';
END
ELSE PRINT N'4. wms.ng_inspection_photos da co — bo qua';
GO

/* =====================================================================
   MỤC 5 — wms.ng_inspection_approvals   (NHẬT KÝ TỪNG BƯỚC)
   ---------------------------------------------------------------------
   KHÔNG ghi đè, KHÔNG xoá mềm: ApplyStepAsync chèn một dòng mỗi lần bấm,
   và truy vấn chi tiết đọc không lọc is_deleted. Vì vậy bảng này cố ý
   KHÔNG có cột is_deleted — đó là chủ ý, không phải thiếu sót.
   ===================================================================== */
IF OBJECT_ID(N'wms.ng_inspection_approvals', N'U') IS NULL
BEGIN
    CREATE TABLE wms.ng_inspection_approvals
    (
        id          bigint         NOT NULL IDENTITY(1,1),
        ng_id       bigint         NOT NULL,

        step        nvarchar(20)   NOT NULL,   -- leader | fa | oqc | finalize
        action      nvarchar(20)   NOT NULL,   -- submit | cancel | approve | ok | ng | finalize
        resolution  nvarchar(20)   NULL,
        [comment]   nvarchar(1000) NULL,

        acted_by    nvarchar(100)  NULL,
        acted_at    datetime2(0)   NOT NULL CONSTRAINT df_ngap_at DEFAULT SYSDATETIME(),

        CONSTRAINT pk_ng_inspection_approvals PRIMARY KEY (id),
        CONSTRAINT ck_ngap_step CHECK (step IN (N'leader', N'fa', N'oqc', N'finalize'))
    );
    PRINT N'5. Da tao wms.ng_inspection_approvals';
END
ELSE PRINT N'5. wms.ng_inspection_approvals da co — bo qua';
GO

/* =====================================================================
   MỤC 6 — wms.stocky_carts   (DANH MỤC XE STOCKY)
   ---------------------------------------------------------------------
   ⚠ BẢNG NÀY CHỈ LƯU BẢN THÂN CÁI XE. Hàng trên xe KHÔNG lưu ở đây mà SUY
   RA từ wms.pallets qua cột stocky_code (xem chú thích lớp StockyCart) —
   nhờ vậy hai nơi không bao giờ lệch nhau. Đừng thêm cột lot_id/qty vào
   đây.

   status chỉ có 2 giá trị và nói về "xe CÓ CÒN ĐƯỢC QUẢN LÝ KHÔNG", KHÔNG
   nói xe đứng ở đâu:
     in_warehouse — còn trong hệ thống (có thể đang ở bãi đậu, ở ô
                    Receiving, hoặc đã đẩy sang FA). Vị trí đọc ở locator_id.
     returned     — đã trả vendor, rời hệ thống.

   locator_id = Ô RIÊNG CỦA XE, không phải ô của pallet trên xe. Đây là thứ
   luồng xuất FA và chức năng "đặt xe vào ô" ghi vào.

   code nvarchar(50) khớp đúng wms.pallets.stocky_code nvarchar(50) — hai
   cột này đem so trực tiếp (x.stocky_code = c.code), lệch kiểu là SQL phải
   convert ngầm và index mất tác dụng.
   ===================================================================== */
IF OBJECT_ID(N'wms.stocky_carts', N'U') IS NULL
BEGIN
    CREATE TABLE wms.stocky_carts
    (
        id           bigint        NOT NULL IDENTITY(1,1),

        code         nvarchar(50)  NOT NULL,   -- mã trên QR dán sẵn trên xe
        name         nvarchar(100) NULL,
        vendor       nvarchar(100) NULL,

        status       nvarchar(20)  NOT NULL CONSTRAINT df_stc_status DEFAULT N'in_warehouse',
        locator_id   bigint        NULL,

        received_at  datetime2(0)  NULL,
        received_by  nvarchar(100) NULL,
        returned_at  datetime2(0)  NULL,
        returned_by  nvarchar(100) NULL,
        note         nvarchar(500) NULL,

        is_deleted   bit           NOT NULL CONSTRAINT df_stc_del  DEFAULT (0),
        created_at   datetime2(0)  NOT NULL CONSTRAINT df_stc_crat DEFAULT SYSDATETIME(),
        created_by   nvarchar(100) NULL,
        updated_at   datetime2(0)  NULL,
        updated_by   nvarchar(100) NULL,

        CONSTRAINT pk_stocky_carts PRIMARY KEY (id),
        CONSTRAINT ck_stc_status CHECK (status IN (N'in_warehouse', N'returned'))
    );
    PRINT N'6. Da tao wms.stocky_carts';
END
ELSE PRINT N'6. wms.stocky_carts da co — bo qua';
GO

/* =====================================================================
   MỤC 7 — KHOÁ NGOẠI, INDEX, DỮ LIỆU MẪU
   ---------------------------------------------------------------------
   Tách khỏi phần CREATE TABLE và để sau GO: bảng vừa tạo ở lô lệnh trên,
   lô này mới nhìn thấy cột của nó. Gộp chung một lô là lỗi biên dịch.
   ===================================================================== */

/* ---- 7.1 Khoá ngoại ---------------------------------------------- */

/* ng_type -> danh mục. Chính comment trong SoftDeleteTypeAsync gọi tên
   ràng buộc này: nhờ nó mà xoá CỨNG một loại lỗi còn phiếu tham chiếu sẽ
   bị SQL Server chặn, nên repo mới phải xoá MỀM. */
IF OBJECT_ID(N'wms.ng_inspections', N'U') IS NOT NULL
   AND OBJECT_ID(N'master.ng_types', N'U') IS NOT NULL
   AND OBJECT_ID(N'fk_ng_inspections_ng_type', N'F') IS NULL
BEGIN
    /* Có phiếu mang mã chưa khai trong danh mục thì KHÔNG thêm FK, vì thêm
       sẽ hỏng; báo ra để xử lý tay. */
    IF EXISTS (SELECT 1 FROM wms.ng_inspections n
               WHERE NOT EXISTS (SELECT 1 FROM master.ng_types t WHERE t.code = n.ng_type))
        PRINT N'7.1 ⚠ BO QUA fk_ng_inspections_ng_type: co phieu mang ma loai loi chua khai trong master.ng_types.';
    ELSE
    BEGIN
        ALTER TABLE wms.ng_inspections ADD CONSTRAINT fk_ng_inspections_ng_type
            FOREIGN KEY (ng_type) REFERENCES master.ng_types (code);
        PRINT N'7.1 Da tao fk_ng_inspections_ng_type';
    END
END
GO

/* Con -> cha. CASCADE vì ba bảng con không có nghĩa khi phiếu biến mất.
   (Thực tế phiếu chỉ xoá mềm, nên cascade gần như không bao giờ chạy —
   để đó cho chắc khi dọn dữ liệu test.) */
IF OBJECT_ID(N'fk_ngit_ng', N'F') IS NULL AND OBJECT_ID(N'wms.ng_inspection_items', N'U') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspection_items ADD CONSTRAINT fk_ngit_ng
        FOREIGN KEY (ng_id) REFERENCES wms.ng_inspections (id) ON DELETE CASCADE;
    PRINT N'7.1 Da tao fk_ngit_ng';
END
GO
IF OBJECT_ID(N'fk_ngph_ng', N'F') IS NULL AND OBJECT_ID(N'wms.ng_inspection_photos', N'U') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspection_photos ADD CONSTRAINT fk_ngph_ng
        FOREIGN KEY (ng_id) REFERENCES wms.ng_inspections (id) ON DELETE CASCADE;
    PRINT N'7.1 Da tao fk_ngph_ng';
END
GO
IF OBJECT_ID(N'fk_ngap_ng', N'F') IS NULL AND OBJECT_ID(N'wms.ng_inspection_approvals', N'U') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspection_approvals ADD CONSTRAINT fk_ngap_ng
        FOREIGN KEY (ng_id) REFERENCES wms.ng_inspections (id) ON DELETE CASCADE;
    PRINT N'7.1 Da tao fk_ngap_ng';
END
GO

/* ảnh -> mục. KHÔNG cascade: mục bị xoá mềm chứ không xoá cứng, và ảnh
   phải sống độc lập (item_id NULL = ảnh chung của phiếu). */
IF OBJECT_ID(N'fk_ngph_item', N'F') IS NULL AND OBJECT_ID(N'wms.ng_inspection_photos', N'U') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspection_photos ADD CONSTRAINT fk_ngph_item
        FOREIGN KEY (item_id) REFERENCES wms.ng_inspection_items (id);
    PRINT N'7.1 Da tao fk_ngph_item';
END
GO

/* phiếu -> pallet, và ô của xe -> danh mục ô. Chỉ thêm khi bảng đích có
   thật (DEV có cả hai, nhưng kiểm cho chắc). */
IF OBJECT_ID(N'fk_ngi_pallet', N'F') IS NULL
   AND OBJECT_ID(N'wms.ng_inspections', N'U') IS NOT NULL
   AND OBJECT_ID(N'wms.pallets', N'U') IS NOT NULL
BEGIN
    ALTER TABLE wms.ng_inspections ADD CONSTRAINT fk_ngi_pallet
        FOREIGN KEY (lot_id) REFERENCES wms.pallets (id);
    PRINT N'7.1 Da tao fk_ngi_pallet';
END
GO
IF OBJECT_ID(N'fk_stc_locator', N'F') IS NULL
   AND OBJECT_ID(N'wms.stocky_carts', N'U') IS NOT NULL
   AND OBJECT_ID(N'master.locators', N'U') IS NOT NULL
BEGIN
    ALTER TABLE wms.stocky_carts ADD CONSTRAINT fk_stc_locator
        FOREIGN KEY (locator_id) REFERENCES master.locators (id);
    PRINT N'7.1 Da tao fk_stc_locator';
END
GO

/* ---- 7.2 Index ---------------------------------------------------- */

/* Số phiếu duy nhất TRONG SỐ PHIẾU CHƯA XOÁ MỀM — index lọc, không phải
   unique thường: phiếu xoá mềm vẫn giữ nguyên doc_no, unique thường sẽ
   chặn sinh lại số đó. Cùng khuôn với ux_return_instructions_doc_no. */
IF OBJECT_ID(N'wms.ng_inspections', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_ng_inspections_doc_no'
                     AND object_id = OBJECT_ID(N'wms.ng_inspections'))
    CREATE UNIQUE INDEX ux_ng_inspections_doc_no
        ON wms.ng_inspections (doc_no) WHERE is_deleted = 0;
GO
/* Màn danh sách lọc theo doc_status rồi sắp xếp discovered_at DESC. */
IF OBJECT_ID(N'wms.ng_inspections', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ngi_status_found'
                     AND object_id = OBJECT_ID(N'wms.ng_inspections'))
    CREATE INDEX ix_ngi_status_found
        ON wms.ng_inspections (doc_status, discovered_at DESC) WHERE is_deleted = 0;
GO
IF OBJECT_ID(N'wms.ng_inspections', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ngi_lot'
                     AND object_id = OBJECT_ID(N'wms.ng_inspections'))
    CREATE INDEX ix_ngi_lot ON wms.ng_inspections (lot_id) WHERE is_deleted = 0;
GO
/* ng_type: CountReportsOfTypeAsync và cột UsedByReports của màn quản trị
   đều đếm theo cột này. Không lọc is_deleted — hai câu đó đếm cả phiếu đã
   xoá mềm (chặn xoá loại lỗi thì phải tính cả phiếu cũ). */
IF OBJECT_ID(N'wms.ng_inspections', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ngi_ng_type'
                     AND object_id = OBJECT_ID(N'wms.ng_inspections'))
    CREATE INDEX ix_ngi_ng_type ON wms.ng_inspections (ng_type);
GO
IF OBJECT_ID(N'wms.ng_inspection_items', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ngit_ng'
                     AND object_id = OBJECT_ID(N'wms.ng_inspection_items'))
    CREATE INDEX ix_ngit_ng ON wms.ng_inspection_items (ng_id) WHERE is_deleted = 0;
GO
IF OBJECT_ID(N'wms.ng_inspection_photos', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ngph_ng'
                     AND object_id = OBJECT_ID(N'wms.ng_inspection_photos'))
    CREATE INDEX ix_ngph_ng ON wms.ng_inspection_photos (ng_id, sort_order) WHERE is_deleted = 0;
GO
IF OBJECT_ID(N'wms.ng_inspection_approvals', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_ngap_ng'
                     AND object_id = OBJECT_ID(N'wms.ng_inspection_approvals'))
    CREATE INDEX ix_ngap_ng ON wms.ng_inspection_approvals (ng_id, acted_at);
GO

/* Mã xe duy nhất TRONG SỐ XE CHƯA XOÁ MỀM — chính comment trong
   ReceiveAsync gọi tên index này và giải thích vì sao phải upsert. */
IF OBJECT_ID(N'wms.stocky_carts', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ux_stocky_carts_code'
                     AND object_id = OBJECT_ID(N'wms.stocky_carts'))
    CREATE UNIQUE INDEX ux_stocky_carts_code
        ON wms.stocky_carts (code) WHERE is_deleted = 0;
GO
IF OBJECT_ID(N'wms.stocky_carts', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_stc_status'
                     AND object_id = OBJECT_ID(N'wms.stocky_carts'))
    CREATE INDEX ix_stc_status ON wms.stocky_carts (status) WHERE is_deleted = 0;
GO
/* wms.pallets.stocky_code: mọi truy vấn "hàng trên xe" đi qua cột này
   (OUTER APPLY ... WHERE x.stocky_code = c.code). Chỉ tạo nếu chưa có. */
IF OBJECT_ID(N'wms.pallets', N'U') IS NOT NULL
   AND COL_LENGTH(N'wms.pallets', N'stocky_code') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_pallets_stocky_code'
                     AND object_id = OBJECT_ID(N'wms.pallets'))
    CREATE INDEX ix_pallets_stocky_code
        ON wms.pallets (stocky_code) WHERE is_deleted = 0 AND stocky_code IS NOT NULL;
GO

/* ---- 7.3 Dữ liệu mẫu cho master.ng_types -------------------------- */
/* ⚠ ĐÂY LÀ MÃ TÔI ĐẶT, KHÔNG PHẢI MÃ CŨ CỦA ANH.
   Mã loại lỗi nằm HOÀN TOÀN trong dữ liệu — không chỗ nào trong code hay
   file ngôn ngữ nhắc tới một mã cụ thể, nên không có cách nào đọc lại mã
   cũ từ source. Nếu anh còn nhớ bộ mã cũ thì sửa khối dưới trước khi
   chạy; không thì dùng tạm bộ này rồi sửa trong màn quản trị danh mục.
   Bảng ng_inspections đang rỗng nên đổi mã lúc này không hỏng gì. */
DECLARE @SeedTypes bit = 1;   -- đổi 0 nếu không muốn chèn

IF @SeedTypes = 1 AND OBJECT_ID(N'master.ng_types', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM master.ng_types)
BEGIN
    INSERT INTO master.ng_types
        (code, name_vi, name_en, name_ja, name_zh, requires_oqc, sort_order,
         is_active, is_deleted, created_at, created_by)
    VALUES
        (N'appearance', N'Lỗi ngoại quan',   N'Appearance defect', N'外観不良',   N'外观不良',   1, 10, 1, 0, SYSDATETIME(), N'system'),
        (N'packaging',  N'Lỗi bao bì',       N'Packaging defect',  N'梱包不良',   N'包装不良',   1, 20, 1, 0, SYSDATETIME(), N'system'),
        (N'label',      N'Sai nhãn / tem',   N'Label error',       N'ラベル不良', N'标签错误',   1, 30, 1, 0, SYSDATETIME(), N'system'),
        /* Lệch số lượng là chuyện ĐẾM, không phải chuyện chất lượng — nên
           không cần OQC kết luận (xem chú thích GetRequiresOqcAsync). */
        (N'qty_diff',   N'Lệch số lượng',    N'Quantity mismatch', N'数量差異',   N'数量差异',   0, 40, 1, 0, SYSDATETIME(), N'system'),
        (N'wet',        N'Ẩm ướt / ngấm nước', N'Wet / water damage', N'水濡れ',  N'受潮',      1, 50, 1, 0, SYSDATETIME(), N'system'),
        (N'damage',     N'Móp / vỡ',         N'Dented / broken',   N'破損',      N'破损',      1, 60, 1, 0, SYSDATETIME(), N'system'),
        (N'other',      N'Khác',             N'Other',             N'その他',    N'其他',      1, 99, 1, 0, SYSDATETIME(), N'system');
    PRINT N'7.3 Da chen 7 loai loi mau vao master.ng_types (SUA LAI NEU CAN)';
END
ELSE PRINT N'7.3 Bo qua chen mau (da tat, hoac bang da co du lieu)';
GO

/* =====================================================================
   MỤC 8 — TỰ ĐỐI CHIẾU: CODE CẦN GÌ, DB CÓ GÌ
   ---------------------------------------------------------------------
   Danh sách dưới đây lấy từ chính các câu SQL trong repository. Chạy xong
   mà cột nao_thieu = 0 ở cả 6 dòng là đủ.
   ===================================================================== */
IF OBJECT_ID('tempdb..#need') IS NOT NULL DROP TABLE #need;
CREATE TABLE #need (bang sysname, cot sysname);

INSERT INTO #need (bang, cot)
SELECT N'master.ng_types', v FROM (VALUES
 (N'code'),(N'name_vi'),(N'name_en'),(N'name_ja'),(N'name_zh'),
 (N'note_vi'),(N'note_en'),(N'note_ja'),(N'note_zh'),
 (N'requires_oqc'),(N'sort_order'),(N'is_active'),(N'is_deleted'),
 (N'created_at'),(N'created_by'),(N'updated_at'),(N'updated_by')) x(v)
UNION ALL
SELECT N'wms.ng_inspections', v FROM (VALUES
 (N'id'),(N'doc_no'),(N'lot_id'),(N'ng_type'),(N'description'),(N'discovered_at'),
 (N'doc_status'),(N'current_step'),
 (N'leader_status'),(N'leader_by'),(N'leader_by_code'),(N'leader_at'),(N'leader_comment'),
 (N'fa_status'),(N'fa_resolution'),(N'fa_by'),(N'fa_at'),(N'fa_comment'),
 (N'oqc_status'),(N'oqc_by'),(N'oqc_at'),(N'oqc_comment'),
 (N'resolution'),(N'finalized_by'),(N'finalized_at'),(N'final_comment'),
 (N'cancelled_by'),(N'cancelled_at'),(N'cancel_reason'),
 (N'is_deleted'),(N'created_at'),(N'created_by'),(N'updated_at'),(N'updated_by')) x(v)
UNION ALL
SELECT N'wms.ng_inspection_items', v FROM (VALUES
 (N'id'),(N'ng_id'),(N'scope'),(N'pallet_id'),(N'box_id'),(N'box_line_id'),
 (N'code'),(N'qty_affected'),(N'note'),(N'is_deleted'),(N'created_at'),(N'created_by')) x(v)
UNION ALL
SELECT N'wms.ng_inspection_photos', v FROM (VALUES
 (N'id'),(N'ng_id'),(N'item_id'),(N'file_path'),(N'file_name'),(N'content_type'),
 (N'size_bytes'),(N'caption'),(N'sort_order'),(N'is_deleted'),(N'created_at'),(N'created_by')) x(v)
UNION ALL
SELECT N'wms.ng_inspection_approvals', v FROM (VALUES
 (N'id'),(N'ng_id'),(N'step'),(N'action'),(N'resolution'),(N'comment'),
 (N'acted_by'),(N'acted_at')) x(v)
UNION ALL
SELECT N'wms.stocky_carts', v FROM (VALUES
 (N'id'),(N'code'),(N'name'),(N'vendor'),(N'status'),(N'locator_id'),
 (N'received_at'),(N'received_by'),(N'returned_at'),(N'returned_by'),(N'note'),
 (N'is_deleted'),(N'created_at'),(N'created_by'),(N'updated_at'),(N'updated_by')) x(v);

SELECT  n.bang,
        co_bang    = CASE WHEN OBJECT_ID(n.bang, N'U') IS NULL
                          THEN N'>>> CHUA CO <<<' ELSE N'co' END,
        code_can   = COUNT(*),
        db_co      = SUM(CASE WHEN COL_LENGTH(n.bang, n.cot) IS NOT NULL THEN 1 ELSE 0 END),
        nao_thieu  = SUM(CASE WHEN COL_LENGTH(n.bang, n.cot) IS NULL THEN 1 ELSE 0 END),
        ket_luan   = CASE WHEN SUM(CASE WHEN COL_LENGTH(n.bang, n.cot) IS NULL THEN 1 ELSE 0 END) = 0
                          THEN N'DU' ELSE N'>>> CON THIEU <<<' END
FROM    #need n
GROUP BY n.bang
ORDER BY n.bang;

/* Liệt kê đích danh cột nào còn thiếu (rỗng = đủ) */
SELECT  n.bang, cot_con_thieu = n.cot
FROM    #need n
WHERE   COL_LENGTH(n.bang, n.cot) IS NULL
ORDER BY n.bang, n.cot;

/* Ràng buộc / index đã dựng */
SELECT  bang = OBJECT_SCHEMA_NAME(i.object_id) COLLATE DATABASE_DEFAULT + N'.' +
               OBJECT_NAME(i.object_id)        COLLATE DATABASE_DEFAULT,
        ten  = i.name COLLATE DATABASE_DEFAULT,
        loai = CASE WHEN i.is_primary_key = 1 THEN N'PK'
                    WHEN i.is_unique = 1      THEN N'UNIQUE'
                    ELSE N'INDEX' END,
        co_loc = i.has_filter
FROM    sys.indexes i
WHERE   i.object_id IN (OBJECT_ID(N'master.ng_types'), OBJECT_ID(N'wms.ng_inspections'),
                        OBJECT_ID(N'wms.ng_inspection_items'), OBJECT_ID(N'wms.ng_inspection_photos'),
                        OBJECT_ID(N'wms.ng_inspection_approvals'), OBJECT_ID(N'wms.stocky_carts'))
  AND   i.name IS NOT NULL
ORDER BY 1, 3, 2;

SELECT  khoa_ngoai = fk.name COLLATE DATABASE_DEFAULT,
        tu   = OBJECT_SCHEMA_NAME(fk.parent_object_id) COLLATE DATABASE_DEFAULT + N'.' +
               OBJECT_NAME(fk.parent_object_id)        COLLATE DATABASE_DEFAULT,
        den  = OBJECT_SCHEMA_NAME(fk.referenced_object_id) COLLATE DATABASE_DEFAULT + N'.' +
               OBJECT_NAME(fk.referenced_object_id)        COLLATE DATABASE_DEFAULT
FROM    sys.foreign_keys fk
WHERE   fk.parent_object_id IN (OBJECT_ID(N'wms.ng_inspections'),
                        OBJECT_ID(N'wms.ng_inspection_items'), OBJECT_ID(N'wms.ng_inspection_photos'),
                        OBJECT_ID(N'wms.ng_inspection_approvals'), OBJECT_ID(N'wms.stocky_carts'))
ORDER BY 2, 1;

PRINT N'';
PRINT N'===== XONG =====';
PRINT N'Cot "ket_luan" phai la DU o ca 6 dong, va bang "cot_con_thieu" phai RONG.';
PRINT N'Sau do chay lai export_schema_compact.sql va gui lai de doi chieu lan cuoi.';
GO

SET NOEXEC OFF;
GO
