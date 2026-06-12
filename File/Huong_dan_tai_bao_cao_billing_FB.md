# Hướng dẫn tải báo cáo thanh toán Facebook tự động (Windows) — BẢN ĐẦY ĐỦ

> Tài liệu mang về nhà để thực hiện. Thư mục làm việc: **`E:\PythonTool\`**.
> **Mục tiêu giai đoạn này:** tự động tải file **PDF báo cáo thanh toán THÁNG TRƯỚC** từ Facebook Billing Hub cho một **danh sách tài khoản quảng cáo**. Bước cuối (upload Google Drive + hẹn lịch) làm sau.

---

## 0. Tổng quan & cách tiếp cận

**Quy trình thật:** với mỗi tài khoản quảng cáo → vào thẳng trang "Hoạt động thanh toán" trên Facebook Billing Hub → lọc dữ liệu **"Tháng trước"** → bấm **Tải xuống → Tải báo cáo xuống (PDF)** → lưu file.

**Cách làm:** Python + Playwright, **dùng lại profile Chrome đã đăng nhập Facebook** là `D:\AdsBotProfile` (chính là profile tool .NET của bạn đang dùng). Vì profile này đã đăng nhập FB *trực tiếp* (không phải copy), nên Playwright dùng lại được — đây là lý do cách này chạy còn cách copy profile trước đó thì không.

**Lưu ý:** ở luồng này **không cần adscheck.smit.vn và không cần extension** — chỉ cần đăng nhập Facebook trong profile là đủ.

---

## 1. Cài đặt môi trường (làm một lần)

Mở **Command Prompt** (Start → gõ `cmd`). Vào thư mục làm việc — nhớ có `/d` để đổi sang ổ E::
```bash
cd /d E:\PythonTool
```

**1.1. Cài Python:** tải tại python.org/downloads (bản Windows mới nhất). Khi cài, **tick ô "Add python.exe to PATH"** → *Install Now*. Kiểm tra:
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
```
(Không cần `playwright install chromium` vì script dùng Chrome thật của bạn — `channel="chrome"`.)

---

## 2. Đảm bảo profile đã đăng nhập Facebook

- `D:\AdsBotProfile` là profile tool .NET của bạn dùng và đã đăng nhập Facebook.
- **Quan trọng:** trước khi chạy script, phải **ĐÓNG mọi cửa sổ Chrome và tool .NET đang dùng profile này** — nếu profile đang bị một tiến trình khác giữ, Playwright sẽ không khởi chạy được.
- Nếu sau này mở ra thấy bị đăng xuất Facebook, xem cách đăng nhập lại ở **Phụ lục B**.

---

## 3. Hai file cần có trong E:\PythonTool

Cách tạo file: mở **Notepad** → dán nội dung → *Save As* → ô "Save as type" chọn **All files** → đặt đúng tên (đuôi `.py` / `.txt`) → lưu vào `E:\PythonTool`.

### 3.1. File `account_ids.txt`
```
# Mỗi dòng một Account ID (chính là payment_account_id/asset_id dùng trong URL billing).
# Dòng bắt đầu bằng # sẽ bị bỏ qua. Thay/để thêm ID của bạn vào đây:
2060618941471327
```

### 3.2. File `download_billing_reports.py`
```python
#!/usr/bin/env python3
r"""
Tự động tải báo cáo thanh toán (PDF) THÁNG TRƯỚC từ Facebook Billing Hub,
cho một danh sách tài khoản quảng cáo. Dùng lại profile D:\AdsBotProfile.
"""
from __future__ import annotations
import re
import sys
import logging
from pathlib import Path
from datetime import date, timedelta

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout, Page

# =========================== CẤU HÌNH ===========================
PROFILE_DIR      = r"D:\AdsBotProfile"   # profile Chrome ĐÃ đăng nhập FB (giống .NET)
DOWNLOAD_DIR     = r"D:\openChorm"        # nơi lưu PDF (đổi tùy ý)
BUSINESS_ID      = "2461376284235400"     # business_id của bạn (lấy từ URL billing hub)
ACCOUNT_IDS_FILE = "account_ids.txt"      # danh sách ID, mỗi dòng một Account ID
# ================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("billing")


def last_month_label() -> str:
    """Nhãn tháng trước dạng YYYY_MM để đặt tên file."""
    last_day_prev = date.today().replace(day=1) - timedelta(days=1)
    return last_day_prev.strftime("%Y_%m")


def read_account_ids() -> list[str]:
    p = Path(ACCOUNT_IDS_FILE)
    if not p.exists():
        log.error("Không thấy %s. Tạo file này, mỗi dòng một Account ID.", ACCOUNT_IDS_FILE)
        sys.exit(1)
    ids = [
        ln.strip() for ln in p.read_text(encoding="utf-8").splitlines()
        if ln.strip() and not ln.strip().startswith("#")
    ]
    if not ids:
        log.error("%s đang trống.", ACCOUNT_IDS_FILE)
        sys.exit(1)
    return ids


def billing_url(account_id: str) -> str:
    return (
        "https://business.facebook.com/billing_hub/payment_activity"
        f"?asset_id={account_id}"
        f"&business_id={BUSINESS_ID}"
        f"&payment_account_id={account_id}"
        "&placement=ads_manager"
    )


def download_one(page: Page, account_id: str, out_dir: Path, label: str) -> None:
    log.info("[%s] Mở trang Hoạt động thanh toán...", account_id)
    page.goto(billing_url(account_id), wait_until="networkidle", timeout=60_000)

    # 1) Mở bộ chọn ngày: nút hiển thị khoảng ngày luôn chứa dấu "–"
    log.info("[%s] Mở bộ chọn ngày & chọn 'Tháng trước'...", account_id)
    page.get_by_role("button", name=re.compile("–")).first.click()

    # 2) Chọn preset "Tháng trước" (preset tự áp dụng, không cần bấm Cập nhật)
    page.get_by_label(re.compile("Giá trị đặt sẵn")).get_by_text("Tháng trước", exact=True).click()
    # Nếu dòng trên không khớp, thử thay bằng:
    # page.get_by_text("Tháng trước", exact=True).click()

    # 3) Tải xuống -> "Tải báo cáo xuống (PDF)" (mở popup + tải file)
    log.info("[%s] Tải PDF...", account_id)
    page.get_by_role("button", name="Tải xuống").click()
    with page.expect_download(timeout=60_000) as dl_info:
        with page.expect_popup() as popup_info:
            page.get_by_role("link", name="Tải báo cáo xuống (PDF)").click()
        popup = popup_info.value
    download = dl_info.value

    dest = out_dir / f"bao_cao_{account_id}_{label}.pdf"
    download.save_as(dest)
    try:
        popup.close()
    except Exception:
        pass
    log.info("[%s] Đã lưu: %s", account_id, dest)


def main() -> None:
    account_ids = read_account_ids()
    out_dir = Path(DOWNLOAD_DIR)
    out_dir.mkdir(parents=True, exist_ok=True)
    label = last_month_label()
    log.info("Sẽ tải báo cáo tháng %s cho %d tài khoản.", label, len(account_ids))

    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(
            PROFILE_DIR,
            channel="chrome",
            headless=False,
            accept_downloads=True,
            no_viewport=True,
            args=["--start-maximized"],
        )

        ok, fail = 0, 0
        for account_id in account_ids:
            page = context.new_page()
            try:
                download_one(page, account_id, out_dir, label)
                ok += 1
            except PWTimeout as e:
                fail += 1
                shot = out_dir / f"loi_{account_id}.png"
                try:
                    page.screenshot(path=str(shot))
                except Exception:
                    pass
                log.error("[%s] LỖI (timeout): %s | đã lưu ảnh: %s", account_id, e, shot)
            except Exception as e:
                fail += 1
                log.error("[%s] LỖI: %s", account_id, e)
            finally:
                page.close()

        log.info("XONG. Thành công: %d | Lỗi: %d | File ở: %s", ok, fail, out_dir)
        input("Nhấn Enter để đóng trình duyệt...")   # bỏ dòng này khi hẹn lịch tự động
        context.close()


if __name__ == "__main__":
    main()
```

---

## 4. Chạy thử (TEST với 1 ID trước)

1. **Đóng** mọi Chrome / tool .NET đang dùng `D:\AdsBotProfile`.
2. Để `account_ids.txt` chỉ có **một ID** (đang sẵn `2060618941471327`).
3. Chạy:
```bash
cd /d E:\PythonTool
venv\Scripts\activate
python download_billing_reports.py
```
4. Kết quả mong đợi: file `bao_cao_2060618941471327_<YYYY_MM>.pdf` xuất hiện trong `D:\openChorm`.

Cửa sổ Chrome sẽ mở (đã đăng nhập), tự vào trang thanh toán, chọn "Tháng trước", tải PDF. Tháng được tính tự động (preset "Tháng trước" của Facebook, đúng múi giờ).

---

## 5. Chạy cho cả danh sách

Khi 1 ID đã chạy ổn, mở `account_ids.txt`, dán thêm các ID khác (mỗi dòng một ID), lưu lại, rồi chạy lại script — nó sẽ xử lý lần lượt từng tài khoản. Tài khoản nào lỗi sẽ được ghi log và chụp ảnh `loi_<ID>.png` mà không làm dừng các tài khoản còn lại.

---

## 6. Bước tiếp theo (sau khi tải PDF ổn)

Sau khi phần tải PDF chắc chắn, tôi sẽ bổ sung: **upload các file PDF lên Google Drive**, và hướng dẫn **hẹn lịch chạy hằng tháng** bằng Windows Task Scheduler (lúc đó nhớ xóa dòng `input("Nhấn Enter...")` ở cuối script để chạy không cần thao tác tay).

---

## Phụ lục A — Lưu ý dùng cmd
- Đổi sang ổ E: phải có `/d`: `cd /d E:\PythonTool`.
- Nếu gõ `playwright ...` báo không nhận: thêm `python -m` → `python -m playwright ...`.
- Nếu PowerShell chặn lệnh `activate`: dùng **Command Prompt (cmd)**.

## Phụ lục B — Lỗi thường gặp
- **Không khởi chạy được / profile bị khóa:** đóng hết Chrome và tool .NET đang dùng `D:\AdsBotProfile`.
- **Mở ra bị đăng xuất Facebook:** mở profile đó để đăng nhập lại bằng lệnh sau (đóng các Chrome khác trước), đăng nhập Facebook xong thì đóng cửa sổ rồi chạy lại script:
  ```bash
  "C:\Program Files\Google\Chrome\Application\chrome.exe" --user-data-dir="D:\AdsBotProfile"
  ```
- **Kẹt ở bước chọn ngày hoặc tải PDF (sai selector):** xem log + ảnh `loi_<ID>.png` trong `D:\openChorm`; thử bỏ comment dòng thay thế cho "Tháng trước" trong script; nếu vẫn kẹt, gửi tôi ảnh + log để chỉnh selector.
- **business_id của bạn khác:** sửa `BUSINESS_ID` trong script (lấy từ URL billing hub: phần `business_id=...`).
- **Dùng Account ID nào:** chính là `payment_account_id` / `asset_id` trong URL billing (ví dụ `2060618941471327`).

## Phụ lục C — Bảo mật
- `D:\AdsBotProfile` chứa phiên đăng nhập Facebook của bạn → giữ kín, không chia sẻ, không đẩy lên git, không gửi cho ai.
- File PDF báo cáo, `account_ids.txt`, và script thì bình thường, không nhạy cảm.
