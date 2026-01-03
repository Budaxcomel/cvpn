#!/bin/bash

# ─────────────────────────────────────────────────────────────
# Semakan kebenaran langganan (remote whitelist)
# ─────────────────────────────────────────────────────────────
PERM_LIB="/opt/connectifyvpn/lib/permission.sh"
if [[ -f "$PERM_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$PERM_LIB"
  permission_check_or_exit "/opt/connectifyvpn"
else
  echo "Ralat: fail permission.sh tidak dijumpai. Sila jalankan installer dahulu."
  exit 1
fi

clear
# // Ini Adalah Auto Expired Untuk Noobzvpns
data=( `cat /etc/funny/.noob | grep '^###' | cut -d ' ' -f 2 | sort | uniq`); # // Membaca Akun Yang Active
now=`date +"%Y-%m-%d"` # // Tahun-Bulan-Tanggal hari inj
for user in "${data[@]}" # // Mendefinisikan Bahwa user = data
do
exp=$(grep -w "^### $user" "/etc/funny/.noob" | cut -d ' ' -f 3 | sort | uniq) # // Membaca Masa Aktif Username
d1=$(date -d "$exp" +%s) # // Menampikan Masa Aktif Sesuai Username
d2=$(date -d "$now" +%s) # // Tanggal Hari ini
exp2=$(( (d1 - d2) / 86400 )) # Xp 2
if [[ "$exp2" -le "0" ]]; then
sed -i "/^### $user $exp/,/^},{/d" /etc/funny/.noob
noobzvpns --remove-user "$user"
fi
done
