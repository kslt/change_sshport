#!/bin/bash

# Kontrollera att skriptet körs som root
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Kör detta skript med sudo:"
  echo "   sudo $0"
  exit 1
fi

# Hämta aktuell port från sshd_config
current_port=$(grep -Ei "^Port" /etc/ssh/sshd_config | awk '{print $2}')
if [ -z "$current_port" ]; then
  current_port="22 (standard)"
fi

echo "🔐 Nuvarande SSH-port: $current_port"
read -p "👉 Ange ny SSH-port (1-65535): " new_port

# Kontrollera att porten är ett heltal mellan 1 och 65535
if [[ "$new_port" =~ ^[0-9]+$ ]]; then
  if (( new_port >= 1 && new_port <= 65535 )); then
    echo "✅ Validerad port: $new_port"
  else
    echo "❌ Portnummer utanför tillåtet intervall (1-65535)."
    exit 1
  fi
else
  echo "❌ Ogiltigt format: Porten måste vara ett heltal."
  exit 1
fi

read -p "❓ Är du säker på att du vill ändra till port $new_port? (j/n): " confirm
if [[ "$confirm" != "j" && "$confirm" != "J" ]]; then
  echo "❎ Ingen ändring gjord."
  exit 0
fi

# Ändra port i sshd_config
echo "🔧 Ändrar SSH-port..."
sed -i.bak -E "s/^#?Port .*/Port $new_port/" /etc/ssh/sshd_config

# Tillåt port i brandvägg om ufw används
if command -v ufw > /dev/null; then
  echo "🧱 Uppdaterar UFW-regler..."
  ufw allow $new_port/tcp
  ufw delete allow ssh >/dev/null 2>&1
fi

# Starta om SSH-tjänsten
echo "♻️  Startar om SSH-tjänst..."
systemctl restart ssh

echo "✅ SSH-port ändrad till $new_port."
echo "📢 Glöm inte: Nästa gång du ansluter, använd: ssh användare@IP -p $new_port"
