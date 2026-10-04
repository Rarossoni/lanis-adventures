#!/usr/bin/env bash
# Atualiza os mods pelo packwiz e liga o servidor.
cd "$(dirname "$0")"

java -jar packwiz-installer-bootstrap.jar -g -s server \
  https://raw.githubusercontent.com/Rarossoni/lanis-adventures/main/pack.toml

exec ./run.sh nogui
