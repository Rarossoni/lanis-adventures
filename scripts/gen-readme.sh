#!/usr/bin/env bash
# Gera o README.md com a lista de mods e o historico de mudancas, a partir do git.
# Roda sozinho no pre-commit (scripts/hooks/pre-commit). Uso manual: bash scripts/gen-readme.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

RAW="https://raw.githubusercontent.com/Rarossoni/lanis-adventures/main"
DIRS=(mods resourcepacks)
TODAY=$(date +%Y-%m-%d)
ME=$(git config user.name || echo "?")
STAGED=0; [ "${1:-}" = "--staged" ] && STAGED=1
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Funcoes awk compartilhadas: versao do mod a partir do nome do arquivo (ignora versao do MC).
AWK_LIB='
function ver(f,   s, v) {
  sub(/\.(jar|zip)$/, "", f); s = f
  while (match(s, /[0-9]+(\.[0-9]+)+(\+(alpha|beta)[.0-9]*)?/)) {
    v = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
    if (v ~ /^1\.(1[6-9]|2[01])(\.[0-9]+)?$/) continue
    return v
  }
  return "—"
}
function val(line) { sub(/^[^=]*= */, "", line); gsub(/^"|"$/, "", line); return line }
'

# --- ultima alteracao de cada arquivo (uma passada no git log) -----------------
git log --no-merges --format='@%ad|%an' --date=short --name-only -- "${DIRS[@]}" |
  awk -F'|' '/^@/ { d = substr($1, 2); a = $2; next } NF && !seen[$0]++ { print $0 "\t" d "\t" a }' > "$TMP/last"
if [ $STAGED = 1 ]; then
  git diff --cached --name-only -- "${DIRS[@]}" | awk -v d="$TODAY" -v a="$ME" '{ print $0 "\t" d "\t" a }' > "$TMP/staged"
  cat "$TMP/staged" "$TMP/last" | awk -F'\t' '!seen[$1]++' > "$TMP/last2" && mv "$TMP/last2" "$TMP/last"
fi

table() { # table <pasta>
  local files=("$1"/*.pw.toml)
  [ -e "${files[0]}" ] || return 0
  printf '| Mod | Versão | Lado | Última atualização | Por |\n|---|---|---|---|---|\n'
  awk -v today="$TODAY" -v me="$ME" "$AWK_LIB"'
    FNR == 1 && NR != FNR && prev != "" { row(prev) }
    FILENAME == LAST { split($0, p, "\t"); when[p[1]] = p[2]; who[p[1]] = p[3]; next }
    FNR == 1 { prev = FILENAME; name = file = side = mid = pid = "" }
    /^name = /       && name == "" { name = val($0) }
    /^filename = /   { file = val($0) }
    /^side = /       { side = val($0) }
    /^mod-id = /     { mid = val($0) }
    /^project-id = / { pid = val($0) }
    function row(f,   n, s, w, a) {
      n = name
      if (mid != "") n = "[" name "](https://modrinth.com/project/" mid ")"
      else if (pid != "") n = "[" name "](https://www.curseforge.com/projects/" pid ")"
      s = side == "client" ? "Cliente" : side == "server" ? "Servidor" : "Ambos"
      w = (f in when) ? when[f] : today; a = (f in who) ? who[f] : me
      printf "| %s | `%s` | %s | %s | %s |\n", n, ver(file), s, w, a | "sort -f"
    }
    END { if (prev != "") row(prev); close("sort -f") }
  ' LAST="$TMP/last" "$TMP/last" "${files[@]}"
}

# --- historico de mudancas (uma passada no git log -p) -----------------------
history() {
  {
    if [ $STAGED = 1 ]; then
      echo "@@COMMIT $TODAY — $ME"
      git diff --cached -p --no-renames --unified=200 -- "${DIRS[@]}"
    fi
    git log -p --no-merges --no-renames --unified=200 --format='@@COMMIT %ad — %an' --date=short -- "${DIRS[@]}"
  } | awk "$AWK_LIB"'
    function flush_file(   l) {
      if (path !~ /\.pw\.toml$/) { path = ""; return }
      if (st == "A")      l = "- ➕ **Adicionado** " nn " `" ver(nf) "`"
      else if (st == "D") l = "- ➖ **Removido** " on
      else if (of != nf && of != "" && nf != "") l = "- 🔄 **Atualizado** " nn " `" ver(of) "` → `" ver(nf) "`"
      else l = ""
      if (l != "") lines[++n] = l
      path = ""
    }
    function flush_commit(   i, j, t) {
      flush_file()
      if (n > 0) {
        for (i = 2; i <= n; i++) { t = lines[i]; for (j = i - 1; j > 0 && tolower(lines[j]) > tolower(t); j--) lines[j+1] = lines[j]; lines[j+1] = t }
        print "### " title
        for (i = 1; i <= n; i++) print lines[i]
        print ""
      }
      n = 0
    }
    /^@@COMMIT / { flush_commit(); title = substr($0, 10); next }
    /^diff --git / { flush_file(); path = $NF; sub(/^b\//, "", path); st = "M"; on = nn = of = nf = ""; next }
    /^new file mode/     { st = "A"; next }
    /^deleted file mode/ { st = "D"; next }
    /^(\+\+\+|---) / { next }
    /^[ +-](name|filename) = / {
      c = substr($0, 1, 1); k = substr($0, 2); v = val(k); sub(/ =.*/, "", k)
      if (k == "name")     { if (c != "+" && on == "") on = v; if (c != "-" && nn == "") nn = v }
      if (k == "filename") { if (c != "+") of = v; if (c != "-") nf = v }
    }
    END { flush_commit() }
  '
}

# --- README ------------------------------------------------------------------
pf() { sed -n "s/^$1 = \"\(.*\)\"$/\1/p" pack.toml | head -n1; }
MC=$(pf minecraft); FORGE=$(pf forge); PVER=$(pf version); AUTHOR=$(pf author)
NMODS=$(ls mods/*.pw.toml 2>/dev/null | wc -l | tr -d ' ')
NRP=$(ls resourcepacks/*.pw.toml 2>/dev/null | wc -l | tr -d ' ')

{
cat <<EOF
# Lanis Adventures

Modpack de aventura feito por **$AUTHOR**.

| Minecraft | Forge | Versão do pack | Mods |
|---|---|---|---|
| $MC | $FORGE | $PVER | $NMODS |

## Como jogar

1. No [Prism Launcher](https://prismlauncher.org/), crie uma instância **$MC** com **Forge $FORGE**.
2. Coloque o [packwiz-installer-bootstrap.jar](https://github.com/packwiz/packwiz-installer-bootstrap/releases) na pasta \`minecraft\` da instância.
3. Em *Editar → Configurações → Comandos personalizados*, use como **Comando pré-lançamento**:
   \`\`\`
   "\$INST_JAVA" -jar packwiz-installer-bootstrap.jar $RAW/pack.toml
   \`\`\`
4. Abra o jogo. Os mods são baixados e atualizados sozinhos a cada vez que o jogo abre.

> **Lado:** *Cliente* = só no seu PC (visual/desempenho) · *Servidor* = só no servidor · *Ambos* = nos dois.

## Mods ($NMODS)

EOF
table mods
if [ "$NRP" -gt 0 ]; then
  printf '\n## Resource packs (%s)\n\nAtive em *Opções → Pacotes de recursos*.\n\n' "$NRP"
  table resourcepacks
fi
printf '\n## Histórico de mudanças\n\n'
history
printf -- '---\n*Este README é gerado automaticamente por `scripts/gen-readme.sh` a cada commit. Não edite à mão.*\n'
} > README.md
