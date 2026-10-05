#!/usr/bin/env bash
# 1) Da nome fixo aos arquivos dos resource packs (ex.: fresh-animations.zip), para a
#    ordem salva no jogo nao quebrar quando um pack atualizar. O nome original fica
#    guardado na linha "# arquivo = ..." (usada pelo README para mostrar a versao).
# 2) Gera config/resourcepackoverrides.json com a ordem de resourcepack-order.txt.
# Roda sozinho no pre-commit.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

for f in resourcepacks/*.pw.toml; do
  [ -e "$f" ] || continue
  slug=$(basename "$f" .pw.toml)
  cur=$(sed -n 's/^filename = "\(.*\)"$/\1/p' "$f")
  ext="${cur##*.}"; stable="$slug.$ext"
  [ "$cur" = "$stable" ] && continue
  # packwiz acabou de (re)escrever o arquivo: guarda o nome original e fixa o nome
  sed -i -e '/^# arquivo = /d' \
         -e "s|^filename = .*|filename = \"$stable\"\n# arquivo = \"${cur//|/\\|}\"|" "$f"
done

# Ordem: o arquivo lista de cima (prioridade) para baixo; o config quer de baixo para cima.
mapfile -t order < <(grep -vE '^\s*(#|$)' resourcepack-order.txt | tr -d '\r')
packs=()
for slug in "${order[@]}"; do [ -e "resourcepacks/$slug.pw.toml" ] && packs+=("$slug"); done
for f in resourcepacks/*.pw.toml; do
  slug=$(basename "$f" .pw.toml)
  [[ " ${order[*]} " == *" $slug "* ]] || packs=("$slug" "${packs[@]}")
done

mkdir -p config
{
  printf '{\n  "schema_version": 2,\n  "failed_reloads_per_session": 5,\n  "default_packs": [\n'
  printf '    "vanilla",\n    "mod_resources"'
  for ((i = ${#packs[@]} - 1; i >= 0; i--)); do
    fn=$(sed -n 's/^filename = "\(.*\)"$/\1/p' "resourcepacks/${packs[$i]}.pw.toml")
    printf ',\n    "file/%s"' "$fn"
  done
  printf '\n  ],\n  "default_overrides": {\n    "force_compatible": true\n  }\n}\n'
} > config/resourcepackoverrides.json
