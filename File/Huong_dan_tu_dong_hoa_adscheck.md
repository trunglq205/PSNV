# Hướng dẫn tự động hóa báo cáo tháng — adscheck.smit.vn (Windows)

> Tài liệu này gom toàn bộ các bước đã trao đổi thành một quy trình hoàn chỉnh để bạn thực hiện ở nhà.
> **Giai đoạn hiện tại:** cài công cụ → dựng trình duyệt đã đăng nhập → **ghi lại thao tác**, để hôm sau gửi lại nhằm sinh code tự động hóa hoàn chỉnh.

---

## 0. Tổng quan

**Mục tiêu cuối:** tự động vào adscheck.smit.vn → lọc dữ liệu theo tháng → tải file PDF → upload lên Google Drive, có thể hẹn lịch chạy hằng tháng.

**Cách tiếp cận:** dùng Playwright điều khiển **Chrome thật** với một **profile đã đăng nhập sẵn** (Facebook + extension adscheck đã liên kết). Lý do: trang chỉ cho vào mục Báo cáo sau khi đăng nhập Facebook và extension liên kết tài khoản, nên trình duyệt tự động phải "mang theo" trạng thái đăng nhập đó.

**Ba giai đoạn:**
1. Cài đặt + dựng profile + GHI thao tác  ← *bạn đang ở đây*
2. Gửi lại bản ghi → sinh script tự động hóa hoàn chỉnh
3. Chạy thử + hẹn lịch tự động

---

## 1. Cài đặt môi trường (làm một lần)

Mở **Command Prompt** (bấm Start, gõ `cmd`, Enter).

### 1.1. Cài Python
- Tải tại python.org/downloads (bản Windows mới nhất).
- Khi cài, **tick ô "Add python.exe to PATH"** ở dưới cùng màn hình đầu tiên → bấm *Install Now*.
- Kiểm tra:
```bash
python --version
pip --version
```

### 1.2. Tạo thư mục dự án + môi trường ảo
```bash
mkdir adscheck-automation
cd adscheck-automation
python -m venv venv
venv\Scripts\activate
```
Thấy `(venv)` ở đầu dòng là đã vào môi trường ảo.

### 1.3. Cài Playwright + trình duyệt
```bash
pip install playwright
playwright install chromium
```

---

## 2. Dựng profile Chrome đã đăng nhập sẵn

> **Điều kiện:** làm trên **cùng một máy và cùng tài khoản Windows** nơi bạn đăng nhập. Cookie của Chrome được mã hóa gắn với tài khoản Windows nên không mang sang máy/khác user được.

### 2.1. Chuẩn bị một profile đã đăng nhập đầy đủ
Trong Chrome, dùng một profile (ví dụ "Profile 2") để: đăng nhập Facebook, đăng nhập adscheck, và đảm bảo extension adscheck đã hoạt động + liên kết tài khoản. Vào thử mục Báo cáo để chắc chắn vào được.

### 2.2. Copy profile sang một thư mục riêng
1. **Đóng hẳn Chrome** (mở Task Manager, đảm bảo không còn tiến trình `chrome.exe`) — để file không bị khóa khi copy.
2. Tạo thư mục mới: `C:\adscheck-profile`.
3. Mở `%LOCALAPPDATA%\Google\Chrome\User Data` trong File Explorer.
4. Copy file **`Local State`** (nằm ngay trong `User Data`) → `C:\adscheck-profile\Local State`. *(File này giữ khóa giải mã cookie — bắt buộc phải có.)*
5. Tạo thư mục `C:\adscheck-profile\Default`, rồi copy **toàn bộ nội dung bên trong thư mục `Profile 2`** vào `C:\adscheck-profile\Default\`.
   - Có thể bỏ qua các thư mục cache lớn (`Cache`, `Code Cache`, `GPUCache`) để nhẹ và nhanh hơn — chúng không ảnh hưởng đăng nhập.

> **Bảo mật — quan trọng:** thư mục `C:\adscheck-profile` và file `Local State` chứa **cookie đăng nhập thật** của bạn. Giữ kín, không chia sẻ, không đẩy lên git, và **không gửi cho bất kỳ ai** (kể cả khi gửi tôi để gen code — xem Phần 5).

---

## 3. Script mở trình duyệt + ghi thao tác

Tạo file `record_adscheck.py` trong thư mục dự án với nội dung:

```python
"""
Mở adscheck.smit.vn bằng Chrome thật + profile đã đăng nhập (copy ở Phần 2),
rồi mở Inspector để GHI LẠI thao tác.
"""
from playwright.sync_api import sync_playwright

USER_DATA_DIR = r"C:\adscheck-profile"   # thư mục profile đã copy ở Phần 2
URL = "https://adscheck.smit.vn/"

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        USER_DATA_DIR,
        channel="chrome",   # dùng Chrome THẬT -> đọc đúng cookie + extension của profile
        headless=False,     # phải hiện cửa sổ
        no_viewport=True,
    )
    page = context.pages[0] if context.pages else context.new_page()
    page.goto(URL)

    # Mở Inspector. Bấm "Record" trong Inspector rồi thao tác để Playwright ghi lại code.
    page.pause()

    context.close()
```

---

## 4. Ghi lại thao tác bằng Playwright

1. Đảm bảo đã `venv\Scripts\activate`, rồi chạy:
```bash
python record_adscheck.py
```
2. Sẽ mở ra một cửa sổ **Chrome** (đã đăng nhập sẵn) và một cửa sổ **Playwright Inspector**.
3. Trong Inspector, chọn ngôn ngữ là **Python**, rồi bấm nút **Record** (đang sáng = đang ghi).
4. Thao tác **thật và chậm rãi** trên cửa sổ Chrome, đúng quy trình bạn muốn tự động:
   - Vào mục **Báo cáo**.
   - **Lọc theo khoảng ngày** của một tháng cụ thể (ví dụ tháng trước).
   - Bấm nút **tải PDF**.
5. Mỗi thao tác sẽ được dịch thành code (kèm selector) hiển thị trong Inspector.

**Mẹo để bản ghi sạch và chính xác:**
- Thao tác từng bước rõ ràng, tránh click thừa lung tung.
- Cần selector của một phần tử cụ thể thì dùng nút **"Pick locator"** trong Inspector rồi rê chuột vào phần tử đó.
- Nếu ghi bị rối, cứ đóng lại và chạy `python record_adscheck.py` để ghi lại từ đầu.

---

## 5. Export bản ghi để hôm sau gửi sinh code

1. Trong Inspector, kiểm tra ngôn ngữ vẫn là **Python**.
2. Bấm **nút copy** (biểu tượng clipboard) — nó copy toàn bộ code đã ghi.
3. Mở **Notepad**, dán vào, lưu thành file **`thao_tac_da_ghi.py`** (hoặc `.txt`) trong thư mục dự án.
4. *(Rất nên làm — giúp tôi sinh code chuẩn hơn)* Chụp màn hình:
   - Khu vực **bộ lọc ngày** (thấy rõ ô nhập / định dạng ngày).
   - Nút **tải PDF**.

**Hôm sau bạn gửi cho tôi:**
- File `thao_tac_da_ghi.py` (bản ghi).
- Vài ảnh chụp ở trên (nếu có).

Từ đó tôi sẽ dựng script tự động hóa hoàn chỉnh: tự tính khoảng ngày của tháng, lọc DataTable, đặt tên file theo tháng, và **upload lên Google Drive**, kèm cách hẹn lịch chạy hằng tháng.

> **An toàn khi gửi:** bản ghi chỉ chứa các thao tác và selector — KHÔNG có mật khẩu (vì lúc ghi bạn đã đăng nhập sẵn).
> **Tuyệt đối không gửi:** thư mục `C:\adscheck-profile` hay file `Local State` — đó là cookie đăng nhập thật của bạn.

---

## 6. Phần tiếp theo (sau khi có bản ghi)

Tôi sẽ biến bản ghi thành một script chạy được, gồm: tự động tính tháng cần báo cáo, lọc DataTable, chờ tải PDF, upload Google Drive (qua Google Drive API), và hướng dẫn hẹn lịch bằng Windows Task Scheduler để chạy tự động ngày 1 hằng tháng.

---

## Phụ lục — Lỗi thường gặp

- **Mở ra bị đăng xuất (chưa login):** kiểm tra đã dùng `channel="chrome"`, đang ở **cùng tài khoản Windows**, và **đã copy file `Local State`**. Nếu vẫn không được, phương án chắc ăn: dùng một thư mục profile trống rồi tự đăng nhập Facebook bằng tay một lần trong cửa sổ Chrome do script mở — profile sẽ tự nhớ cho các lần sau.
- **Extension không hoạt động trong cửa sổ tự động:** nạp extension thủ công bằng cách thêm tham số sau vào phần `args=[...]` của `launch_persistent_context` (trỏ tới thư mục extension trong profile đã copy):
  ```python
  args=[
      r"--disable-extensions-except=C:\adscheck-profile\Default\Extensions\<ID>\<phien_ban>",
      r"--load-extension=C:\adscheck-profile\Default\Extensions\<ID>\<phien_ban>",
  ],
  ```
- **Gõ lệnh `playwright ...` báo không nhận** (vd `playwright install`): thêm `python -m` ở trước → `python -m playwright install`.
- **PowerShell chặn lệnh `activate`:** dùng **Command Prompt (cmd)** thay vì PowerShell.
- **Cửa sổ vừa mở đã đóng ngay:** chính `page.pause()` giữ cho cửa sổ mở; đừng đóng Inspector hay bấm Resume cho tới khi ghi xong.

***update 20260609***
# Hướng dẫn tự động hóa báo cáo tháng — adscheck.smit.vn (Windows) — BẢN ĐẦY ĐỦ

> Tài liệu mang về nhà để thực hiện. Thư mục làm việc: **`E:\PythonTool\`**.
> **Giai đoạn hiện tại:** cài công cụ → mở trình duyệt đã đăng nhập → **ghi lại thao tác**, rồi gửi bản ghi lại để sinh script tự động hóa hoàn chỉnh (tự lọc theo tháng + tải PDF + upload Google Drive + hẹn lịch).

---

## 0. Cách tiếp cận (đọc qua cho hiểu)

**Mục tiêu cuối:** máy tự vào adscheck → lọc theo tháng → tải PDF → upload Google Drive, chạy tự động hằng tháng.

**Vì sao làm theo cách này:** trang chỉ vào được mục Báo cáo sau khi đăng nhập Facebook và extension adscheck liên kết tài khoản. Cách "copy profile cho Playwright tự mở" đã thử và **không chạy được**, vì Chrome đời mới mã hóa cookie gắn với chính ứng dụng Chrome, đồng thời Google/Facebook chặn đăng nhập trên trình duyệt do công cụ tự động khởi chạy.
Giải pháp dùng được: **bạn tự mở Chrome như bình thường** (Chrome tin cậy, đăng nhập + extension hoạt động), rồi **Playwright chỉ KẾT NỐI vào** Chrome đó để điều khiển và ghi thao tác.

**Ba giai đoạn:** (1) cài đặt + đăng nhập + ghi thao tác ← *bạn đang ở đây*; (2) gửi bản ghi → sinh code; (3) chạy thử + hẹn lịch.

---

## 1. Cài đặt môi trường (làm một lần)

Mở **Command Prompt** (Start → gõ `cmd`). Vào thư mục làm việc — lưu ý phải có `/d` để đổi sang ổ E::
```bash
cd /d E:\PythonTool
```

**1.1. Cài Python:** tải tại python.org/downloads (bản Windows mới nhất). Khi cài, **tick ô "Add python.exe to PATH"** → bấm *Install Now*. Kiểm tra:
```bash
python --version
pip --version
```

**1.2. Tạo môi trường ảo (trong E:\PythonTool):**
```bash
python -m venv venv
venv\Scripts\activate
```
Thấy `(venv)` ở đầu dòng là được.

**1.3. Cài Playwright:**
```bash
pip install playwright
playwright install chromium
```
(`playwright install chromium` không bắt buộc cho cách kết nối CDP, nhưng cài cũng không sao.)

---

## 2. Tạo 2 file trong E:\PythonTool

Cách tạo file: mở **Notepad** → dán nội dung → *Save As* → ô "Save as type" chọn **All files** → đặt đúng tên (có đuôi `.bat` / `.py`) → lưu vào `E:\PythonTool`.

### 2.1. File `mo_chrome_debug.bat`
```bat
@echo off
set CHROME="C:\Program Files\Google\Chrome\Application\chrome.exe"
if not exist %CHROME% set CHROME="C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
start "" %CHROME% --remote-debugging-port=9222 --user-data-dir="E:\PythonTool\adscheck-chrome" https://adscheck.smit.vn/
```
*(Nếu Chrome cài ở nơi khác, sửa lại dòng `set CHROME`.)*

### 2.2. File `record_adscheck_cdp.py`
```python
"""
Kết nối Playwright vào Chrome đang mở ở chế độ debug (cổng 9222) để GHI thao tác.
Trước khi chạy: phải mở Chrome bằng mo_chrome_debug.bat và để cửa sổ đó MỞ.
"""
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://localhost:9222")
    context = browser.contexts[0]
    page = context.pages[0] if context.pages else context.new_page()
    page.goto("https://adscheck.smit.vn/")
    page.pause()   # Inspector: bấm "Record" để ghi, hoặc "Pick locator" để lấy selector
    # KHÔNG đóng browser — đó là Chrome thật của bạn.
```

---

## 3. Mở Chrome + đăng nhập (LẦN ĐẦU, làm một lần)

1. **Double-click `mo_chrome_debug.bat`.** Một cửa sổ Chrome mở ra adscheck.smit.vn. Lần đầu profile này **trống/chưa đăng nhập** — đúng như dự kiến (Chrome chỉ cho chế độ debug trên profile riêng, không dùng profile mặc định của bạn).
2. Trong cửa sổ Chrome đó: **đăng nhập Facebook**.
3. **Cài extension adscheck**: trên trang adscheck bấm nút tải tiện ích → cài từ Chrome Store, để extension liên kết tài khoản.
4. Vào thử mục **Báo cáo** để chắc chắn đã vào được.
5. Lưu ý:
   - Nút **"Xác minh danh tính"** của Google ở góc phải có thể **bỏ qua** — thứ cần là đăng nhập Facebook + extension + vào được Báo cáo.
   - Lần đầu Facebook có thể hỏi xác minh thiết bị (mã 2FA / "có phải bạn không") → cứ hoàn tất bình thường.

Sau bước này, profile `E:\PythonTool\adscheck-chrome` đã nhớ đăng nhập + extension cho các lần sau.

---

## 4. Ghi lại thao tác

1. **Giữ nguyên cửa sổ Chrome ở Phần 3 đang mở.**
2. Mở **một cửa sổ cmd khác**:
```bash
cd /d E:\PythonTool
venv\Scripts\activate
python record_adscheck_cdp.py
```
3. Playwright kết nối vào Chrome đó, cửa sổ **Playwright Inspector** hiện ra. Chọn ngôn ngữ **Python**.
4. Bấm **Record**, rồi thao tác **chậm rãi và đúng quy trình** trên cửa sổ Chrome:
   - Vào mục **Báo cáo**.
   - **Lọc theo khoảng ngày** của một tháng cụ thể (ví dụ tháng trước).
   - Bấm nút **tải PDF**.
5. Mỗi thao tác được dịch thành code (kèm selector) trong Inspector. Cần selector của một phần tử cụ thể thì dùng nút **"Pick locator"** rồi rê chuột vào phần tử đó.

**Mẹo:** thao tác sạch, tránh click thừa; ghi bị rối thì đóng Inspector và chạy lại `python record_adscheck_cdp.py`.

---

## 5. Export bản ghi để gửi sinh code

1. Trong Inspector, để ngôn ngữ **Python**, bấm **nút copy** (biểu tượng clipboard).
2. Mở **Notepad**, dán vào, lưu thành **`E:\PythonTool\thao_tac_da_ghi.py`** (hoặc `.txt`).
3. *(Rất nên làm — giúp sinh code chuẩn hơn)* Chụp màn hình **khu vực bộ lọc ngày** và **nút tải PDF**.

**Hôm sau gửi lại:** file `thao_tac_da_ghi.py` + vài ảnh chụp.

- **An toàn khi gửi:** bản ghi chỉ chứa thao tác và selector, KHÔNG có mật khẩu (lúc ghi bạn đã đăng nhập sẵn).
- **Tuyệt đối không gửi:** thư mục `E:\PythonTool\adscheck-chrome` — đó là cookie đăng nhập thật của bạn.

---

## 6. Các lần sau & bước tiếp theo

**Mỗi lần dùng về sau** (đã đăng nhập + extension rồi, không phải làm lại): chỉ cần
1. Double-click `mo_chrome_debug.bat`.
2. Chạy script (`python record_adscheck_cdp.py`, hoặc script tự động hóa sau này).

**Bước tiếp theo:** sau khi nhận bản ghi của bạn, tôi sẽ dựng script tự động hoàn chỉnh: tự tính tháng cần báo cáo, lọc DataTable, chờ tải PDF, **upload Google Drive**, và hướng dẫn hẹn lịch bằng Windows Task Scheduler để chạy tự động hằng tháng.

---

## Phụ lục A — Lưu ý dùng cmd / lệnh hay vướng
- Đổi sang ổ E: phải có `/d`: `cd /d E:\PythonTool`.
- Nếu gõ `playwright ...` báo không nhận: thêm `python -m` → `python -m playwright install`.
- Nếu PowerShell chặn lệnh `activate`: dùng **Command Prompt (cmd)**.

## Phụ lục B — Lỗi thường gặp
- **`.bat` không mở Chrome / sai đường dẫn:** mở `.bat` bằng Notepad, sửa dòng `set CHROME` cho đúng nơi cài `chrome.exe`.
- **Script báo không kết nối được (CDP):** đảm bảo đã **mở Chrome bằng `.bat` TRƯỚC** và cửa sổ còn mở; cổng phải là `9222` ở cả hai nơi.
- **Vẫn bị đăng xuất / không vào được Báo cáo:** kiểm tra bạn đã đăng nhập trong **đúng cửa sổ Chrome do `.bat` mở** (không phải Chrome thường), và đã cài extension trong cửa sổ đó.
- **Cổng 9222 đang bận:** đổi sang số khác (vd `9333`) ở cả `.bat` và script.
- **Chrome hiện thông báo "đang được điều khiển" / DevTools:** bình thường khi Playwright kết nối, cứ bỏ qua.

## Phụ lục C — Bảo mật
- Thư mục `E:\PythonTool\adscheck-chrome` chứa cookie đăng nhập của bạn → giữ kín, không chia sẻ, không đẩy lên git, không gửi cho ai.
- Bản ghi thao tác (`thao_tac_da_ghi.py`) thì an toàn để gửi.
