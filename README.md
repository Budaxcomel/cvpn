# ConnectifyVPN Autoscript

**Penulis/Author:** Budaxcomel


## Pemasangan (melalui Git Clone)

> Pastikan anda sudah upload repo ini ke GitHub anda sendiri, kemudian `git clone` di VPS.

```bash
apt update && apt upgrade -y
apt install -y git curl wget unzip jq
git clone https://github.com/<OWNER>/<REPO>.git
cd <REPO>

# Installer akan auto set PERMISSION_URL berdasarkan repo Git anda
sudo bash install-connectifyvpn.sh
```

## Sistem Kebenaran Langganan (Remote Whitelist)

Skrip ini akan membuat semakan **IP VPS** dan **tarikh tamat** melalui fail whitelist dalam repo GitHub.

Laluan fail whitelist (default):
- `permission/ipuk/ip`

Format (1 baris = 1 VPS):
- `<IP> <USERNAME> <YYYY-MM-DD>`
- atau `<IP>|<USERNAME>|<YYYY-MM-DD>`

Contoh:
```text
203.0.113.10 connectifyvpn 2026-12-31
```

Jika anda mahu guna URL whitelist lain, anda boleh set:
- `/etc/connectifyvpn/permission.conf` (PERMISSION_URL=...)
