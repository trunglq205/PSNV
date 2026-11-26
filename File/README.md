1. Master vessel: cột ETA là số ngày tính theo ngày lịch (tính cả t7,cn) hay ngày làm việc(k tính t7,cn, lễ) => tính theo lịch, cả t7, cn và nghỉ lễ nhé (cứ cộng leadtime là ra ETA)
2. Master customer fix: cột ETD customer fix là ngày trong tháng hay là khoảng gap trừ đi (ETD = ETA - 15)  => là ngày trong tháng, hay nói chính xác hơn nó chính là ETD request luôn
3. Master WH capacity ==>  hiểu theo ý A
	A) Đây là năng lực đóng container FCL của kho, giảm dần khi kho phải đóng nhiều hàng lẻ. Ví dụ ngày 20/07 kho PSNV có 12 pallet hàng lẻ, rơi vào nhóm 6~29, nên hôm đó kho chỉ đóng được tối đa 3 cont 40H. Nếu lịch xếp 5 cont vào ngày đó thì vượt 2 cont, phải dời 2 cont sang ngày làm việc trước đó.
4. GW,Volume của model lấy từ đâu? Volume là theo cái hay theo thùng => link từ SAP, volume và weight lấy theo thùng => tạm thời sẽ thêm cột trong Master model để k phụ thuộc vào SAP, nào auto link SAP sau
5. Master model: PAP-WAS TRUCK đóng hàng ở kho nào? => đóng hàng ở kho PSNV nhé  -> insert thiếu sẽ bổ sung sau
6. OBE và UKB có cùng là Kobe không? vessel và PO ghi OBE còn master model và aloocation lại ghi là UKB => cùng Kobe, chị sẽ sửa lại để master thống nhất là 1
