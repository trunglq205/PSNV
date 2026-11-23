1. Da them cot fa_result.
1. Da them rang buoc ck_ngi_fa_result.
2. Da them cot review_round (mac dinh 1).
3. Da them cot pallet_status_before.
Msg 2714, Level 16, State 5, Line 164
There is already an object named 'ck_ngi_step' in the database.
Msg 1750, Level 16, State 1, Line 164
Could not create constraint or index. See previous errors.
5a. Da dien fa_result = ok cho 4 phieu da chot truoc day.
5b. CO 1 phieu dang cho Supervisor chot.
    Luong moi khong con nut do -> chung se KET.
    Doi @CloseReadyDocs = 1 roi chay lai de dong chung theo luat moi.
6. CHI XEM TRUOC. Doi @StampExisting = 1 roi chay lai de dong dau that.
7. *** ck_ngi_step CHUA nhan fa_fix: The UPDATE statement conflicted with the CHECK constraint "ck_ngi_step". The conflict occurred in database "SWMS_FINISH_GOODS_DEV", table "wms.ng_inspections", column 'current_step'. ***
 
=== XONG — VIEC TIEP THEO ===
1. Deploy API + Web ban moi. Chay script nay TRUOC khi deploy.
2. Quyen abnormal_report.finalize KHONG con gac gi. Khong xoa la quyen
   (xoa roi khai lai se lam song lai quyen cua moi role tung duoc gan).
3. Pallet mang inspection_status = ng thi KHONG LEN DUOC PHIEU XUAT.
 

Completion time: 2026-11-23T15:18:45.8388117+07:00
