#!/usr/bin/env python3
r"""
Lấy SỐ THẺ (4 số cuối) và MÃ TK (3 ký tự cuối, unique) từ trang Hoạt động thanh toán
Facebook Billing Hub, cho một danh sách tài khoản quảng cáo.

Với mỗi tài khoản: mở trang billing -> chọn "Tháng trước" -> đọc số thẻ + mã tk -> ghi file.
CHƯƠNG TRÌNH DỪNG Ở ĐÂY (không tải PDF — đó là script riêng).

  - Số thẻ: LUÔN chỉ có 1 số duy nhất.
  - Mã tk: 3 ký tự cuối của dãy mã dưới "MasterCard", chỉ lấy unique.
  - Phân trang: lấy hết mã tk ở trang đầu; nếu >=2 mã tk unique thì DỪNG (khỏi bấm
    "Xem thêm"); nếu <2 thì bấm "Xem thêm" tới khi đủ 2 HOẶC hết nút "Xem thêm".

Dùng lại profile Chrome đã đăng nhập FB: D:\AdsBotProfile
"""
from __future__ import annotations
import re
import sys
import logging
from pathlib import Path
from datetime import date, timedelta

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout, Page

# =========================== CẤU HÌNH ===========================
PROFILE_DIR      = r"D:\AdsBotProfile"   # profile Chrome ĐÃ đăng nhập FB
OUTPUT_DIR       = r"D:\openChorm"        # nơi lưu file report
BUSINESS_ID      = "2461376284235400"     # business_id của bạn
ACCOUNT_IDS_FILE = "account_ids.txt"      # danh sách ID, mỗi dòng một Account ID

SCRAPE_WAIT_MS   = 2_500   # chờ bảng có dữ liệu trước khi đọc (mili-giây)
XEM_THEM_WAIT_MS = 2_500   # chờ sau khi bấm "Xem thêm" để tải thêm dòng
MAX_MORE_CLICKS  = 50      # chốt chặn số lần bấm "Xem thêm" (phòng lặp vô hạn)
# ================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("cards")


# JS đọc dữ liệu từ các dòng ĐANG hiển thị trong bảng
JS_EXTRACT = r"""
() => {
  const cards = new Set();
  const codes = [];
  const els = document.querySelectorAll('span, div');
  for (const el of els) {
    if (el.querySelector('span, div')) continue;          // chỉ xét phần tử "lá"
    const t = (el.textContent || '').trim();
    if (!t || t.length > 40) continue;                    // bỏ đoạn text dài
    // Số thẻ: 4 số cuối -> nhận theo "MasterCard/Visa ... 5189" hoặc "•••• 5189"
    let m = t.match(/(?:mastercard|visa|jcb|amex|th\u1ebb)[^\d]*?(\d{4})\b/i)
         || t.match(/[\u2022\u00b7\u2219\u2027*.\-]{2,}\s*(\d{4})\b/);
    if (m) cards.add(m[1]);
    // Mã tk: chuỗi in hoa 8-14 ký tự, có >=2 chữ và >=1 số
    if (/^[A-Z0-9]{8,14}$/.test(t)) {
      const letters = (t.match(/[A-Z]/g) || []).length;
      const digits  = (t.match(/[0-9]/g) || []).length;
      if (letters >= 2 && digits >= 1) codes.push(t);
    }
  }
  return { cards: [...cards], codes: codes };
}
"""


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


def select_last_month(page: Page, account_id: str) -> None:
    log.info("[%s] Mở billing & chọn 'Tháng trước'...", account_id)
    page.goto(billing_url(account_id), wait_until="domcontentloaded", timeout=120_000)
    page.get_by_role("button", name=re.compile("–")).first.click()
    page.get_by_label(re.compile("Giá trị đặt sẵn")).get_by_text("Tháng trước", exact=True).click()
    # Nếu dòng trên không khớp, thử: page.get_by_text("Tháng trước", exact=True).click()


def extract_card_and_codes(page: Page, account_id: str) -> tuple[str, list[str]]:
    """Trả về (số thẻ, danh sách mã tk unique = 3 ký tự cuối)."""
    cards: set[str] = set()
    ma_tk: list[str] = []
    seen: set[str] = set()

    def scrape_once() -> None:
        data = page.evaluate(JS_EXTRACT)
        for c in data["cards"]:
            cards.add(c)
        for code in data["codes"]:
            k = code[-3:]                       # 3 ký tự cuối
            if k not in seen:
                seen.add(k)
                ma_tk.append(k)

    page.wait_for_timeout(SCRAPE_WAIT_MS)       # chờ bảng tải sau khi chọn Tháng trước
    scrape_once()                               # <-- quét toàn bộ mã tk ở "trang đầu"

    clicks = 0
    while len(ma_tk) < 2 and clicks < MAX_MORE_CLICKS:
        btn = page.get_by_role("button", name="Xem thêm")
        if btn.count() == 0 or not btn.first.is_visible():
            break                               # không còn nút -> dừng
        try:
            btn.first.scroll_into_view_if_needed()
            btn.first.click()
        except Exception:
            break
        clicks += 1
        page.wait_for_timeout(XEM_THEM_WAIT_MS)  # chờ tải thêm dòng
        scrape_once()

    if len(cards) > 1:
        log.warning("[%s] Thấy %d số thẻ %s (mong đợi 1) — lấy phần tử đầu.",
                    account_id, len(cards), sorted(cards))
    card = next(iter(cards)) if cards else ""    # luôn chỉ 1 thẻ
    return card, ma_tk


def main() -> None:
    account_ids = read_account_ids()
    out_dir = Path(OUTPUT_DIR)
    out_dir.mkdir(parents=True, exist_ok=True)
    label = last_month_label()
    log.info("Lấy số thẻ + mã tk cho %d tài khoản (tháng %s).", len(account_ids), label)

    report_path = out_dir / f"report_the_matk_{label}.txt"
    ok, fail = 0, 0

    with sync_playwright() as p, report_path.open("w", encoding="utf-8") as rf:
        rf.write("Account ID\tSố thẻ\tMã tk\n")

        context = p.chromium.launch_persistent_context(
            PROFILE_DIR, channel="chrome", headless=False,
            no_viewport=True, args=["--start-maximized"],
        )

        for account_id in account_ids:
            page = context.new_page()
            card, ma_tk = "", []
            try:
                select_last_month(page, account_id)
                card, ma_tk = extract_card_and_codes(page, account_id)
                log.info("[%s] Thẻ: %s | Mã tk: %s", account_id, card or "?", " ".join(ma_tk) or "?")
                ok += 1
                card_out = card or "KHÔNG THẤY"
                matk_out = " ".join(ma_tk) or "KHÔNG THẤY"
            except PWTimeout as e:
                fail += 1
                card_out, matk_out = "LỖI (timeout)", "LỖI (timeout)"
                log.error("[%s] LỖI (timeout): %s", account_id, e)
            except Exception as e:
                fail += 1
                card_out, matk_out = "LỖI", "LỖI"
                log.error("[%s] LỖI: %s", account_id, e)
            finally:
                rf.write(f"{account_id}\t{card_out}\t{matk_out}\n")
                rf.flush()
                page.close()

        log.info("XONG. Lấy được: %d | Lỗi: %d", ok, fail)
        log.info("File report: %s", report_path)
        input("Nhấn Enter để đóng trình duyệt...")   # bỏ dòng này khi hẹn lịch tự động
        context.close()


if __name__ == "__main__":
    main()
