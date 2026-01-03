#!/bin/bash
# [ Cipta Direktori ]
mkdir -p /etc/noobzvpns

# [ Cipta Konfigurasi JSON Yang Digunakan Pada Pelayan ]
cat > /etc/noobzvpns/config.json <<-JSON
{
	"tcp_std": [
		80
	],
	"tcp_ssl": [
		443
	],
	"ssl_cert": "/etc/noobzvpns/cert.pem",
	"ssl_key": "/etc/noobzvpns/key.pem",
	"ssl_version": "AUTO",
	"conn_timeout": 60,
	"dns_resolver": "/etc/resolv.conf",
	"http_ok": "HTTP/1.1 101 Switching Protocols[crlf]Upgrade: websocket[crlf][crlf]"
}
JSON

# Port dalam tcp_std & tcp_ssl boleh diubah ikut keperluan anda supaya tidak bertembung
# dengan servis lain pada VPS anda.

# [ Muat Turun Fail ]
wget -O /usr/bin/noobzvpns "https://github.com/noobz-id/noobzvpns/raw/master/noobzvpns.x86_64"
wget -O /etc/noobzvpns/cert.pem "https://github.com/noobz-id/noobzvpns/raw/master/cert.pem"
wget -O /etc/noobzvpns/key.pem "https://github.com/noobz-id/noobzvpns/raw/master/key.pem"

# [ Beri Kebenaran Pada Fail Konfigurasi + Sijil ]
chmod +x /etc/noobzvpns/*

# [ Beri Kebenaran Exec Pada Fail Biner ]
chmod +x /usr/bin/noobzvpns

# [ Ambil Fail Service Yang Diperlukan ]
wget -O /etc/systemd/system/noobzvpns.service "https://github.com/noobz-id/noobzvpns/raw/master/noobzvpns.service"

# [ Enable & Mulakan Servis ]
systemctl enable noobzvpns
systemctl restart noobzvpns

clear
echo "Selesai pemasangan NoobzVPNS."
