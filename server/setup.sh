#!/usr/bin/env bash
# Instala o servidor do Lanis Adventures (Forge 1.20.1) numa VM Linux (Oracle Cloud Free Tier).
# Uso: curl -fsSL https://raw.githubusercontent.com/Rarossoni/lanis-adventures/main/server/setup.sh | bash
set -euo pipefail

FORGE_VERSION="1.20.1-47.4.26"
REPO_RAW="https://raw.githubusercontent.com/Rarossoni/lanis-adventures/main"
DIR="$HOME/lanis-server"
MEM="${MEM:-10G}"   # RAM do servidor; mude com: MEM=12G bash setup.sh

echo ">> Instalando Java 17, tmux e utilitarios..."
if command -v apt-get >/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y openjdk-17-jre-headless tmux curl
elif command -v dnf >/dev/null; then
  sudo dnf install -y java-17-openjdk-headless tmux curl
else
  echo "Gerenciador de pacotes nao suportado (precisa de apt ou dnf)." >&2; exit 1
fi

mkdir -p "$DIR"
cd "$DIR"

echo ">> Instalando Forge $FORGE_VERSION..."
if [ ! -f run.sh ]; then
  curl -fsSL -o forge-installer.jar \
    "https://maven.minecraftforge.net/net/minecraftforge/forge/$FORGE_VERSION/forge-$FORGE_VERSION-installer.jar"
  java -jar forge-installer.jar --installServer
  rm -f forge-installer.jar forge-installer.jar.log
fi

echo ">> Baixando packwiz-installer-bootstrap..."
curl -fsSL -o packwiz-installer-bootstrap.jar \
  "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar"

curl -fsSL -o start.sh "$REPO_RAW/server/start.sh"
chmod +x start.sh run.sh

echo "eula=true" > eula.txt
echo "-Xms${MEM} -Xmx${MEM}" > user_jvm_args.txt

echo ">> Liberando a porta 25565 no firewall da VM..."
if command -v firewall-cmd >/dev/null; then
  sudo firewall-cmd --permanent --add-port=25565/tcp && sudo firewall-cmd --reload
else
  sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 25565 -j ACCEPT
  if command -v netfilter-persistent >/dev/null; then sudo netfilter-persistent save; fi
fi

echo ">> Criando servico systemd (NAO liga sozinho com a VM)..."
sudo tee /etc/systemd/system/lanis.service >/dev/null <<EOF
[Unit]
Description=Lanis Adventures (Minecraft)
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$DIR
ExecStart=/usr/bin/tmux new-session -d -s lanis $DIR/start.sh
ExecStop=/usr/bin/tmux send-keys -t lanis "stop" Enter
ExecStop=/bin/bash -c 'while tmux has-session -t lanis 2>/dev/null; do sleep 1; done'
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
# Nao habilitamos o autostart para nao disputar a porta com outro servidor.
# Para o Lanis ligar junto com a VM: sudo systemctl enable lanis

echo
echo "Pronto! O servidor NAO foi ligado e NAO liga sozinho com a VM."
echo "Comandos uteis:"
echo "  sudo systemctl start lanis     # ligar"
echo "  sudo systemctl stop lanis      # desligar (salva o mundo)"
echo "  sudo systemctl restart lanis   # reiniciar (pega a versao nova do pack)"
echo "  tmux attach -t lanis           # abrir o console (sair: Ctrl+B e depois D)"
echo
echo "Lembre de liberar a porta 25565/TCP na Security List da VCN no painel da Oracle."
