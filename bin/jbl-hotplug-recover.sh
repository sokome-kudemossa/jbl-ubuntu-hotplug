#!/usr/bin/env bash
set -euo pipefail

LOG="$HOME/.cache/jbl-hotplug.log"
exec >>"$LOG" 2>&1
echo "$(date -Is) [start] hotplug check"

in_audio_block() { awk '/^Audio/{a=1;next}/^Video/{a=0} a'; }

find_sink() {
  wpctl status | in_audio_block | sed -n '/Sinks:/,/Sink endpoints:/p' \
    | grep -i 'JBL Quantum' | grep -vi 'Chat' \
    | sed -E 's/^[^0-9]*([0-9]+)\..*/\1/' | head -n1
}
find_source() {
  wpctl status | in_audio_block | sed -n '/Sources:/,/Source endpoints:/p' \
    | grep -i 'JBL Quantum' \
    | sed -E 's/^[^0-9]*([0-9]+)\..*/\1/' | head -n1
}

select_defaults() {
  local s="$1" src="$2"
  [[ -n "$s"   ]] && wpctl set-default "$s"   && echo "$(date -Is) [ok] default sink -> $s"
  [[ -n "$src" ]] && wpctl set-default "$src" && echo "$(date -Is) [ok] default source -> $src"
}

# 1) tenta direto (talvez já esteja tudo ok)
SINK="$(find_sink || true)"; SRC="$(find_source || true)"
if [[ -n "${SINK:-}" || -n "${SRC:-}" ]]; then
  echo "$(date -Is) [info] nodes já visíveis: sink=${SINK:-} src=${SRC:-}"
  select_defaults "${SINK:-}" "${SRC:-}"
  echo "$(date -Is) [done]"; exit 0
fi

# 2) debounce curto e re-testar antes de reiniciar
sleep 1
SINK="$(find_sink || true)"; SRC="$(find_source || true)"
if [[ -n "${SINK:-}" || -n "${SRC:-}" ]]; then
  echo "$(date -Is) [info] nodes apareceram após debounce"
  select_defaults "${SINK:-}" "${SRC:-}"
  echo "$(date -Is) [done]"; exit 0
fi

# 3) reinicia stack de áudio do usuário
echo "$(date -Is) [info] reiniciando wireplumber/pipewire"
systemctl --user restart wireplumber pipewire pipewire-pulse || true

# 4) aguarda até 10s os nós do JBL surgirem e seleciona
for i in $(seq 1 10); do
  sleep 1
  SINK="$(find_sink || true)"; SRC="$(find_source || true)"
  if [[ -n "${SINK:-}" || -n "${SRC:-}" ]]; then
    echo "$(date -Is) [ok] nodes visíveis após restart (t=${i}s): sink=${SINK:-} src=${SRC:-}"
    select_defaults "${SINK:-}" "${SRC:-}"
    echo "$(date -Is) [done]"; exit 0
  fi
done

echo "$(date -Is) [warn] JBL não apareceu nos nós após restart"
echo "$(date -Is) [done]"; exit 0
