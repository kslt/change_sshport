#!/bin/bash

# Kontrollera root
if [[ $EUID -ne 0 ]]; then
  echo "❗ Kör detta skript som root: sudo $0"
  exit 1
fi

echo "🔐 Nuvarande SSH-port:"
current_port=$(grep -Ei "^Port " /etc/ssh/sshd_config | awk '{print $2}')
if [[ -z "$current_port" ]]; then
  current_port="22 (standard)"
fi
echo "➡️  $current_port"

# Fråga efter ny port med validering
while true; do
  read -rp "👉 Ange ny SSH-port (1–65535): " new_port
  new_port=$(echo "$new_port" | tr -d '[:space:]')

  if [[ "$new_port" =~ ^[0-9]+$ ]] && (( new_port >= 1 && new_port <= 65535 )); then
    echo "✅ Validerad port: $new_port"
    break
  else
    echo "❌ Ogiltig port. Försök igen."
  fi
done

# Bekräftelse
read -rp "❓ Är du säker på att du vill ändra till port $new_port? (j/n): " confirm
if [[ "$confirm" != "j" && "$confirm" != "J" ]]; then
  echo "❎ Ingen ändring gjord."
  exit 0
fi

# Backup av konfig
echo "📝 Säkerhetskopierar sshd_config till /etc/ssh/sshd_config.bak"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Ändra porten
echo "🔧 Ändrar SSH-port..."
if grep -qEi "^#?Port " /etc/ssh/sshd_config; then
  sed -i -E "s/^#?Port .*/Port $new_port/" /etc/ssh/sshd_config
else
  echo "Port $new_port" >> /etc/ssh/sshd_config
fi

# UFW: tillåt nya porten om aktiv
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
  echo "🧱 Uppdaterar brandväggsregler (ufw)..."
  ufw allow "$new_port"/tcp
  ufw delete allow "$current_port"/tcp 2>/dev/null
fi

# Starta om SSH
echo "♻️  Startar om SSH-tjänsten..."
systemctl restart ssh

# Bekräftelse
echo "✅ SSH-port är nu ändrad till: $new_port"
echo "📢 Nästa gång du ansluter: ssh användare@IP -p $new_port"
