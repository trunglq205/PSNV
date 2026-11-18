### DB dev  = SWMS_FINISH_GOODS_DEV
### DB thật = SWMS_FINISH_GOODS
### @WhatIf = 0   (GHI THẬT)
 
bang                                                                                                                                                                                                                                                             o_db_that        o_db_dev        so_cot      cot_tinh_toan so_dong_that
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ---------------- --------------- ----------- ------------- --------------------
master.ng_types                                                                                                                                                                                                                                                  >>> KHONG CO <<< thieu           0           0             0
wms.stocky_carts                                                                                                                                                                                                                                                 >>> KHONG CO <<< thieu           0           0             0
wms.ng_inspections                                                                                                                                                                                                                                               >>> KHONG CO <<< thieu           0           0             0
wms.ng_inspection_items                                                                                                                                                                                                                                          >>> KHONG CO <<< thieu           0           0             0
wms.ng_inspection_photos                                                                                                                                                                                                                                         >>> KHONG CO <<< thieu           0           0             0
wms.ng_inspection_approvals                                                                                                                                                                                                                                      >>> KHONG CO <<< thieu           0           0             0

MỤC 1: cot_tinh_toan > 0 nghĩa là bảng có COMPUTED COLUMN —
        `SELECT INTO` sẽ biến nó thành cột thường, phải sửa tay.
 
buoc                                     doi_tuong                                                                                                                                                                                                                                                        stmt
---------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 
===== XONG: 0 câu OK, 0 câu lỗi =====
MỤC 8 bỏ qua: master.ng_types vẫn chưa tạo được.
bang                                                                                                                                                                                                                                                             cot_that    cot_dev     trang_thai
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------- ----------- -----------------
master.ng_types                                                                                                                                                                                                                                                  0           0           >>> VAN THIEU <<<
wms.stocky_carts                                                                                                                                                                                                                                                 0           0           >>> VAN THIEU <<<
wms.ng_inspections                                                                                                                                                                                                                                               0           0           >>> VAN THIEU <<<
wms.ng_inspection_items                                                                                                                                                                                                                                          0           0           >>> VAN THIEU <<<
wms.ng_inspection_photos                                                                                                                                                                                                                                         0           0           >>> VAN THIEU <<<
wms.ng_inspection_approvals                                                                                                                                                                                                                                      0           0           >>> VAN THIEU <<<

 
### Cột lệch nhau thì chạy lại export_schema_compact.sql trên CẢ HAI DB
### rồi so, chứ đừng thêm cột bằng tay.

Completion time: 2026-11-18T13:56:14.2374910+07:00
