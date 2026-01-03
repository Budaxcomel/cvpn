from telethon import TelegramClient, events, Button
import datetime as DT
import os, subprocess, sqlite3, math, logging

logging.basicConfig(level=logging.INFO)
uptime = DT.datetime.now()

# ─────────────────────────────────────────────────────────────
# Konfigurasi Bot (Telethon)
# Fail ini akan cuba baca var.txt (dalam folder yang sama)
# ─────────────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
VAR_FILE = os.path.join(BASE_DIR, "var.txt")

# Nilai default (akan ditimpa jika var.txt wujud)
BOT_TOKEN = ""
ADMIN = ""
API_ID = ""
API_HASH = ""
TG_SESSION = "connectifyvpn"

if os.path.isfile(VAR_FILE):
    # var.txt mengandungi assignment Python (contoh: BOT_TOKEN="xxx")
    exec(open(VAR_FILE, "r").read(), globals())
else:
    # Cipta template supaya pengguna tahu apa yang perlu diisi
    with open(VAR_FILE, "w") as f:
        f.write('BOT_TOKEN=""\n')
        f.write('ADMIN=""\n')
        f.write('API_ID=""\n')
        f.write('API_HASH=""\n')
        f.write('TG_SESSION="connectifyvpn"\n')

if not BOT_TOKEN or not API_ID or not API_HASH:
    raise SystemExit(
        f"[ConnectifyVPN] Sila isi BOT_TOKEN, API_ID dan API_HASH dalam {VAR_FILE} sebelum jalankan bot."
    )

bot = TelegramClient(TG_SESSION, int(API_ID), str(API_HASH)).start(bot_token=BOT_TOKEN)

# ─────────────────────────────────────────────────────────────
# Database admin
# ─────────────────────────────────────────────────────────────
DB_FILE = os.path.join(BASE_DIR, "database.db")
if not os.path.isfile(DB_FILE):
    x = sqlite3.connect(DB_FILE)
    c = x.cursor()
    c.execute("CREATE TABLE admin (user_id)")
    if ADMIN:
        c.execute("INSERT INTO admin (user_id) VALUES (?)", (str(ADMIN),))
    x.commit()

def get_db():
    x = sqlite3.connect(DB_FILE)
    x.row_factory = sqlite3.Row
    return x

def valid(user_id: str) -> str:
    db = get_db()
    rows = db.execute("SELECT user_id FROM admin").fetchall()
    allowed = [v[0] for v in rows]
    return "true" if user_id in allowed else "false"

def convert_size(size_bytes):
    if size_bytes == 0:
        return "0B"
    size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
    i = int(math.floor(math.log(size_bytes, 1024)))
    p = math.pow(1024, i)
    s = round(size_bytes / p, 2)
    return "%s %s" % (s, size_name[i])
