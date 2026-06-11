# Hướng dẫn tự động: tải báo cáo billing Facebook + upload Google Drive (Windows) — BẢN ĐẦY ĐỦ

> Tài liệu mang về nhà để thực hiện. Thư mục làm việc: **`E:\PythonTool\`**.
> **Quy trình:** với danh sách tài khoản quảng cáo → tải **PDF báo cáo thanh toán THÁNG TRƯỚC** từ Facebook Billing Hub → **upload lên Google Drive** → **mở quyền "ai có link cũng xem"** → **ghi link ra file text theo đúng thứ tự ID**. Cuối cùng (tùy chọn): hẹn lịch chạy hằng tháng.

---

## 0. Tổng quan & cách tiếp cận

- **Tải PDF:** Python + Playwright, dùng lại profile Chrome đã đăng nhập Facebook là `D:\AdsBotProfile`. Với mỗi tài khoản, mở thẳng trang "Hoạt động thanh toán", chọn preset **"Tháng trước"**, bấm **Tải xuống → Tải báo cáo xuống (PDF)**.
- **Google Drive:** sau khi tải, dùng Google Drive API để upload, mở quyền công khai theo link, và lấy link.
- **File link:** ghi `Account ID` + link vào `links_<tháng>.txt`, theo đúng thứ tự trong `account_ids.txt` (tài khoản lỗi vẫn được ghi một dòng để không lệch thứ tự).
- Luồng này **không cần adscheck.smit.vn / extension** — chỉ cần đăng nhập Facebook trong profile.

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

**1.3. Cài thư viện:**
```bash
pip install playwright
pip install google-api-python-client google-auth-httplib2 google-auth-oauthlib
```
(Không cần `playwright install chromium` vì script dùng Chrome thật của bạn — `channel="chrome"`.)

---

## 2. Đảm bảo profile Facebook đã đăng nhập

- `D:\AdsBotProfile` là profile đã đăng nhập Facebook (đăng nhập trực tiếp, không copy).
- **Quan trọng:** trước khi chạy script, **ĐÓNG mọi cửa sổ Chrome và tool đang dùng profile này** — nếu profile bị tiến trình khác giữ, Playwright không khởi chạy được.
- Nếu mở ra thấy bị đăng xuất Facebook, xem **Phụ lục B** để đăng nhập lại.

---

## 3. Thiết lập Google Drive API (làm một lần)

1. Vào https://console.cloud.google.com/ → tạo project (hoặc chọn project sẵn có).
2. **APIs & Services → Library** → tìm **Google Drive API** → **Enable**.
3. **APIs & Services → Credentials** → **Create Credentials → OAuth client ID**.
   - Nếu được hỏi, cấu hình **OAuth consent screen**: chọn *External*, điền tên app, thêm email Google của bạn vào *Test users*.
   - **Application type: Desktop app**.
4. Tải file JSON về → đổi tên thành **`credentials.json`** → đặt vào `E:\PythonTool`.
5. Lần đầu chạy script, trình duyệt sẽ mở để bạn đăng nhập Google và cấp quyền → file `token.json` tự được tạo; các lần sau không phải làm lại.

> Muốn dồn các file vào một thư mục Drive cụ thể: lấy ID thư mục từ URL `drive.google.com/drive/folders/<ID>` rồi điền vào `DRIVE_FOLDER_ID` trong script.

---

## 4. Hai file cần có trong E:\PythonTool

Cách tạo file: mở **Notepad** → dán nội dung → *Save As* → ô "Save as type" chọn **All files** → đặt đúng tên (đuôi `.py` / `.txt`) → lưu vào `E:\PythonTool`.

### 4.1. File `account_ids.txt`
```
# Mỗi dòng một Account ID (chính là payment_account_id/asset_id dùng trong URL billing).
# Dòng bắt đầu bằng # sẽ bị bỏ qua. Thay/để thêm ID của bạn vào đây:
2060618941471327
```

### 4.2. File `download_billing_reports.py`
```python
#!/usr/bin/env python3
r"""
Tự động tải báo cáo thanh toán (PDF) THÁNG TRƯỚC từ Facebook Billing Hub cho một
danh sách tài khoản quảng cáo; sau đó UPLOAD lên Google Drive, mở quyền "ai có
link cũng xem được", và ghi link ra file text theo ĐÚNG THỨ TỰ các ID.
"""
from __future__ import annotations
import re
import sys
import logging
from pathlib import Path
from datetime import date, timedelta

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout, Page

# Google Drive API
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# =========================== CẤU HÌNH ===========================
PROFILE_DIR      = r"D:\AdsBotProfile"   # profile Chrome ĐÃ đăng nhập FB
DOWNLOAD_DIR     = r"D:\openChorm"        # nơi lưu PDF + file link
BUSINESS_ID      = "2461376284235400"     # business_id của bạn (lấy từ URL billing hub)
ACCOUNT_IDS_FILE = "account_ids.txt"      # danh sách ID, mỗi dòng một Account ID

# --- Google Drive ---
DRIVE_FOLDER_ID  = ""                     # ID thư mục Drive đích (để trống = My Drive gốc)
CREDENTIALS_FILE = "credentials.json"     # OAuth client tải từ Google Cloud Console
TOKEN_FILE       = "token.json"           # tự tạo sau lần đăng nhập Google đầu tiên
SCOPES           = ["https://www.googleapis.com/auth/drive.file"]
# ================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("billing")


def last_month_label() -> str:
    last_day_prev = date.today().replace(day=1) - timedelta(days=1)
    return last_day_prev.strftime("%Y_%m")


def read_account_ids() -> list[str]:
    p = Path(ACCOUNT_IDS_FILE)
    if not p.exists():
        log.error("Không thấy %s. Tạo file này, mỗi dòng một Account ID.", ACCOUNT_IDS_FILE)
        sys.exit(1)
    ids = [ln.strip() for ln in p.read_text(encoding="utf-8").splitlines()
           if ln.strip() and not ln.strip().startswith("#")]
    if not ids:
        log.error("%s đang trống.", ACCOUNT_IDS_FILE)
        sys.exit(1)
    return ids


def billing_url(account_id: str) -> str:
    return ("https://business.facebook.com/billing_hub/payment_activity"
            f"?asset_id={account_id}&business_id={BUSINESS_ID}"
            f"&payment_account_id={account_id}&placement=ads_manager")


# ----------------------- GOOGLE DRIVE -----------------------
def get_drive_service():
    """Xác thực Google Drive. Lần đầu mở trình duyệt cấp quyền; sau đó dùng token đã lưu."""
    creds = None
    if Path(TOKEN_FILE).exists():
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not Path(CREDENTIALS_FILE).exists():
                raise FileNotFoundError(
                    f"Không thấy {CREDENTIALS_FILE}. Tải OAuth client (Desktop app) từ "
                    "Google Cloud Console rồi đặt cạnh script."
                )
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        Path(TOKEN_FILE).write_text(creds.to_json())
    return build("drive", "v3", credentials=creds)


def upload_and_share(service, file_path: Path, folder_id: str = "") -> str:
    """Upload PDF, mở quyền 'ai có link cũng xem', trả về link xem file."""
    metadata: dict = {"name": file_path.name}
    if folder_id:
        metadata["parents"] = [folder_id]
    media = MediaFileUpload(str(file_path), mimetype="application/pdf", resumable=True)
    f = service.files().create(body=metadata, media_body=media, fields="id, webViewLink").execute()
    file_id = f["id"]
    try:
        service.permissions().create(
            fileId=file_id, body={"type": "anyone", "role": "reader"}
        ).execute()
    except Exception as e:
        log.warning("Không mở được quyền công khai cho %s: %s", file_path.name, e)
    return f.get("webViewLink") or f"https://drive.google.com/file/d/{file_id}/view"


# ----------------------- FACEBOOK -----------------------
def download_one(page: Page, account_id: str, out_dir: Path, label: str) -> Path:
    log.info("[%s] Mở trang Hoạt động thanh toán...", account_id)
    page.goto(billing_url(account_id), wait_until="networkidle", timeout=60_000)

    log.info("[%s] Mở bộ chọn ngày & chọn 'Tháng trước'...", account_id)
    page.get_by_role("button", name=re.compile("–")).first.click()
    page.get_by_label(re.compile("Giá trị đặt sẵn")).get_by_text("Tháng trước", exact=True).click()
    # Nếu dòng trên không khớp, thử: page.get_by_text("Tháng trước", exact=True).click()

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
    return dest


def main() -> None:
    account_ids = read_account_ids()
    out_dir = Path(DOWNLOAD_DIR)
    out_dir.mkdir(parents=True, exist_ok=True)
    label = last_month_label()
    log.info("Sẽ xử lý tháng %s cho %d tài khoản.", label, len(account_ids))

    # Xác thực Google Drive TRƯỚC (lần đầu sẽ mở trình duyệt để cấp quyền)
    drive = get_drive_service()

    links_path = out_dir / f"links_{label}.txt"
    ok, fail = 0, 0

    with sync_playwright() as p, links_path.open("w", encoding="utf-8") as lf:
        lf.write("Account ID\tLink Google Drive\n")

        context = p.chromium.launch_persistent_context(
            PROFILE_DIR, channel="chrome", headless=False,
            accept_downloads=True, no_viewport=True, args=["--start-maximized"],
        )

        for account_id in account_ids:
            page = context.new_page()
            try:
                pdf = download_one(page, account_id, out_dir, label)
                link = upload_and_share(drive, pdf, DRIVE_FOLDER_ID)
                lf.write(f"{account_id}\t{link}\n"); lf.flush()
                log.info("[%s] Link Drive: %s", account_id, link)
                ok += 1
            except PWTimeout as e:
                fail += 1
                shot = out_dir / f"loi_{account_id}.png"
                try:
                    page.screenshot(path=str(shot))
                except Exception:
                    pass
                lf.write(f"{account_id}\tLỖI (timeout)\n"); lf.flush()
                log.error("[%s] LỖI (timeout): %s | ảnh: %s", account_id, e, shot)
            except Exception as e:
                fail += 1
                lf.write(f"{account_id}\tLỖI\n"); lf.flush()
                log.error("[%s] LỖI: %s", account_id, e)
            finally:
                page.close()

        log.info("XONG. Thành công: %d | Lỗi: %d", ok, fail)
        log.info("PDF & file link ở: %s (link: %s)", out_dir, links_path.name)
        input("Nhấn Enter để đóng trình duyệt...")   # bỏ dòng này khi hẹn lịch tự động
        context.close()


if __name__ == "__main__":
    main()
```

---

## 5. Chạy thử (TEST với 1 ID trước)

1. **Đóng** mọi Chrome / tool đang dùng `D:\AdsBotProfile`.
2. Để `account_ids.txt` chỉ có **một ID**.
3. Chạy:
```bash
cd /d E:\PythonTool
venv\Scripts\activate
python download_billing_reports.py
```
4. Lần đầu, trình duyệt sẽ mở để bạn **cấp quyền Google Drive** (xong sẽ lưu `token.json`).

**Kiểm tra 3 thứ:**
- File `bao_cao_<ID>_<tháng>.pdf` đã xuất hiện trên Google Drive.
- Mở link bằng **cửa sổ ẩn danh** (chưa đăng nhập) xem có xem được không → xác nhận quyền công khai đã bật.
- File `links_<tháng>.txt` trong `D:\openChorm` có đúng `ID + link`. (Mở bằng Excel sẽ tách 2 cột.)

---

## 6. Chạy cho cả danh sách

Khi 1 ID đã chạy ổn, mở `account_ids.txt`, dán thêm các ID khác (mỗi dòng một ID), lưu lại, rồi chạy lại script. Nó xử lý lần lượt từng tài khoản; tài khoản lỗi được ghi log + chụp `loi_<ID>.png` và vẫn ghi một dòng trong file link để giữ đúng thứ tự.

---

## 7. (Tùy chọn — khi đã chạy ổn) Hẹn lịch chạy hằng tháng

Trước khi hẹn lịch: **xóa dòng `input("Nhấn Enter để đóng trình duyệt...")`** trong script (chạy nền không có người bấm Enter).

Trong **Task Scheduler** → **Create Task**:
- **General:** đặt tên; chọn **"Run only when user is logged on"** (vì trình duyệt mở ở chế độ hiện cửa sổ, cần phiên desktop).
- **Triggers → New:** *Monthly*, chọn ngày 1, giờ mong muốn.
- **Actions → New → Start a program:**
  - Program/script: `E:\PythonTool\venv\Scripts\python.exe`
  - Add arguments: `download_billing_reports.py`
  - Start in: `E:\PythonTool`

Lưu ý khi hẹn lịch:
- Máy phải **đang bật và đã đăng nhập Windows** vào giờ chạy.
- Lúc lịch chạy, **không có Chrome nào đang mở** `D:\AdsBotProfile`.
- `token.json` phải đã tồn tại (đã cấp quyền Drive ít nhất một lần), để chạy nền không phải mở trình duyệt cấp quyền.
- Khi chạy, một cửa sổ Chrome sẽ hiện lên thao tác — đó là bình thường.

---

## Phụ lục A — Lưu ý dùng cmd
- Đổi sang ổ E: phải có `/d`: `cd /d E:\PythonTool`.
- Nếu gõ `playwright ...` báo không nhận: thêm `python -m` → `python -m playwright ...`.
- Nếu PowerShell chặn lệnh `activate`: dùng **Command Prompt (cmd)**.

## Phụ lục B — Lỗi thường gặp
- **Không khởi chạy được / profile bị khóa:** đóng hết Chrome và tool đang dùng `D:\AdsBotProfile`.
- **Mở ra bị đăng xuất Facebook:** mở profile để đăng nhập lại bằng lệnh sau (đóng các Chrome khác trước), đăng nhập Facebook xong thì đóng cửa sổ rồi chạy lại script:
  ```bash
  "C:\Program Files\Google\Chrome\Application\chrome.exe" --user-data-dir="D:\AdsBotProfile"
  ```
- **Kẹt ở bước chọn ngày hoặc tải PDF (sai selector):** xem log + ảnh `loi_<ID>.png` trong `D:\openChorm`; thử bỏ comment dòng thay thế cho "Tháng trước" trong script; nếu vẫn kẹt, gửi log + ảnh để chỉnh.
- **Link Drive không công khai / báo cảnh báo khi mở quyền:** nếu tài khoản Google thuộc tổ chức (Workspace) chặn chia sẻ ra ngoài, bước mở quyền có thể bị từ chối — file vẫn lên Drive nhưng link không công khai. Với Gmail cá nhân thì bình thường.
- **business_id của bạn khác:** sửa `BUSINESS_ID` trong script (lấy từ URL billing hub: `business_id=...`).
- **Account ID nào dùng:** chính là `payment_account_id` / `asset_id` trong URL billing (ví dụ `2060618941471327`).

## Phụ lục C — Bảo mật
- `D:\AdsBotProfile` (phiên đăng nhập FB), `credentials.json` và `token.json` (quyền Google Drive) đều **nhạy cảm** → giữ kín, không chia sẻ, không đẩy lên git, không gửi cho ai.
- File PDF, `account_ids.txt`, `links_*.txt` và script thì bình thường.
