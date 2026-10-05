#!/usr/bin/env bash
# Atualiza os mods pelo packwiz e liga o servidor.
cd "$(dirname "$0")"

# Usa sempre o Java 17, mesmo que o padrao da VM seja outro (por causa de outro servidor)
JAVA17_BIN=$(ls -d /usr/lib/jvm/java-17-openjdk*/bin 2>/dev/null | head -n1)
[ -n "$JAVA17_BIN" ] && export PATH="$JAVA17_BIN:$PATH"

java -jar packwiz-installer-bootstrap.jar -g -s server \
  https://raw.githubusercontent.com/Rarossoni/lanis-adventures/main/pack.toml

exec ./run.sh nogui
