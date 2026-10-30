#!/bin/bash
# GTA VI launch-day cover. Scrolls a fake build-and-deploy forever, keeps the Mac
# awake, and nudges the cursor 1px so Slack/Teams keep you "active".
# Ctrl-C or `/gta-6 stop` ends the shift.

DIR="$(cd "$(dirname "$0")" && pwd)"
JIGGLE_EVERY=${JIGGLE_EVERY:-240}

G=$'\033[32m' Y=$'\033[33m' B=$'\033[34m' C=$'\033[36m' R=$'\033[31m' D=$'\033[2m' W=$'\033[1m' N=$'\033[0m'

date +%s > "$DIR/.started"
caffeinate -dims -w $$ &
if [[ ! -x "$DIR/.jiggle" ]] && command -v swiftc >/dev/null; then
  swiftc -O "$DIR/jiggle.swift" -o "$DIR/.jiggle" 2>/dev/null
fi
[[ -x "$DIR/.jiggle" ]] || echo "${Y}warn: swiftc not found, cursor nudge is off (fix: xcode-select --install)${N}"

trap 'printf "\n\n\033[1;33m   MISSION PASSED\033[0m\n   \033[1mRESPECT +\033[0m\n\n"; exit 0' INT TERM
printf '\033]0;deploy — prod\007'

SERVICES=(leonida-api vice-ingest port-gellhorn-worker ambrosia-cache kelly-county-etl grassrivers-gateway billing-service auth-service)
TESTS=(
  "retries idempotent writes after 503"
  "backs off when wanted_level >= 3"
  "assigns heist crew of exactly two (jason, lucia)"
  "geo index covers all of leonida"
  "migrates legacy sessions without data loss"
  "handles DST rollover in scheduler"
  "rejects expired refresh tokens"
  "dedupes webhook deliveries"
  "paginates ledger with stable cursors"
  "evicts stale entries from ambrosia cache"
  "normalises currency to minor units"
  "survives upstream timeout during checkout"
)

r() { echo $(( RANDOM % ($2 - $1 + 1) + $1 )); }
hex() { LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c "$1"; }
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
cmd() { say ""; say "${D}$(date '+%H:%M:%S')${N} ${W}\$ $*${N}"; }

last_jiggle=$SECONDS
say() {
  printf '%s\n' "$*"
  sleep "0.$(r 0 3)$(r 0 9)"
  if (( SECONDS - last_jiggle >= JIGGLE_EVERY )); then
    [[ -x "$DIR/.jiggle" ]] && "$DIR/.jiggle"
    last_jiggle=$SECONDS
  fi
}
think() { sleep "$(r 1 3).$(r 0 9)"; }

install() {
  cmd "pnpm install --frozen-lockfile"
  say "Lockfile is up to date, resolution step is skipped"
  say "Progress: resolved $(r 1200 1500), reused $(r 1100 1400), downloaded $(r 3 40), added $(r 3 40), done"
  say "${D}node_modules/.pnpm/@leonida+core@6.0.0/node_modules/@leonida/core: Running postinstall script...${N}"
  think
  say "${D}node_modules/.pnpm/@leonida+core@6.0.0/node_modules/@leonida/core: Running postinstall script, done in $(r 1 4).$(r 0 9)s${N}"
  say "Done in $(r 8 40).$(r 1 9)s"
}

build() {
  cmd "turbo run build --filter=...[origin/main]"
  local n=$(r 3 5) svc i
  for ((i = 0; i < n; i++)); do
    svc=$(pick "${SERVICES[@]}")
    say "${C}$svc:build:${N} cache miss, executing $(hex 16)"
    say "${C}$svc:build:${N} > tsc -p tsconfig.build.json && tsc-alias"
    think
    say "${C}$svc:build:${N} ${G}✓${N} emitted $(r 40 900) files in $(r 2 19).$(r 0 9)s"
  done
  say ""
  say " ${W}Tasks:${N}    ${G}$n successful${N}, $n total"
  say "${W}Cached:${N}    $(r 0 2) cached, $n total"
  say "  ${W}Time:${N}    $(r 9 59).$(r 100 999)s"
}

suite() {
  local file=$(pick ledger checkout session scheduler webhook geo heist cache)
  cmd "vitest run src/$file --reporter=verbose"
  local pool=("${TESTS[@]}") n=$(r 6 9) passed=0 i j t
  for ((i = 0; i < n; i++)); do
    j=$(( i + RANDOM % (${#pool[@]} - i) ))
    t=${pool[j]} pool[j]=${pool[i]}
    if (( RANDOM % 9 == 0 )); then
      say " ${R}✗${N} src/$file/$file.test.ts > $t ${D}$(r 900 3000)ms${N}"
      say "   ${R}→ expected 200, received 504${N}"
      say "   ${Y}retry 1/2${N}"
      think
    fi
    say " ${G}✓${N} src/$file/$file.test.ts > $t ${D}$(r 2 400)ms${N}"
    passed=$((passed + 1))
  done
  say ""
  say " ${W}Test Files${N}  ${G}1 passed${N} (1)"
  say "      ${W}Tests${N}  ${G}$passed passed${N} ($passed)"
  say "   ${W}Duration${N}  $(r 1 9).$(r 10 99)s"
}

image() {
  local svc=$(pick "${SERVICES[@]}") sha=$(hex 7) i
  cmd "docker buildx build --platform linux/amd64 -t ghcr.io/acme/$svc:$sha --push ."
  local steps=("FROM node:22-alpine AS base" "WORKDIR /app" "COPY pnpm-lock.yaml package.json ./" "RUN pnpm fetch --prod" "COPY . ." "RUN pnpm build" "RUN pnpm prune --prod" "FROM gcr.io/distroless/nodejs22" "COPY --from=base /app/dist ./dist")
  for ((i = 0; i < ${#steps[@]}; i++)); do
    say "#$((i + 4)) [$((i + 1))/${#steps[@]}] ${steps[i]}"
    (( RANDOM % 3 == 0 )) && think
    say "#$((i + 4)) DONE $(r 0 14).$(r 0 9)s"
  done
  say "#14 exporting to image"
  say "#14 pushing layers $(r 3 9)/$(r 10 12)"
  think
  say "#14 pushing manifest for ghcr.io/acme/$svc:$sha@sha256:$(hex 64)"
  say "#14 DONE $(r 3 12).$(r 0 9)s"
}

deploy() {
  local svc=$(pick "${SERVICES[@]}") i
  cmd "kubectl -n prod rollout status deploy/$svc"
  for i in 1 2 3 4 5; do
    say "Waiting for deployment \"$svc\" rollout to finish: $i of 6 updated replicas are available..."
    think
  done
  say "${G}deployment \"$svc\" successfully rolled out${N}"
}

logs() {
  local svc=$(pick "${SERVICES[@]}") i
  cmd "stern -n prod $svc --since 1m"
  local n=$(r 10 20)
  for ((i = 0; i < n; i++)); do
    if (( RANDOM % 8 == 0 )); then
      say "${Y}$svc-$(hex 5)${N} $(date '+%H:%M:%S') ${Y}WARN${N} upstream slow, wanted_level=$(r 1 3), backing off $(r 2 8)s"
    else
      say "${C}$svc-$(hex 5)${N} $(date '+%H:%M:%S') ${B}INFO${N} req=$(hex 12) $(pick GET POST PUT) /v1/$(pick orders ledger sessions heists payouts properties) $(pick 200 200 200 201 204) ${D}$(r 4 180)ms${N}"
    fi
  done
}

migrate() {
  cmd "pnpm db:migrate --env=staging"
  local m id
  for m in "add_vice_city_index" "backfill_property_owners" "drop_legacy_wanted_flags"; do
    id=2026_11_19_$(printf '%02d%02d%02d' "$(r 9 17)" "$(r 0 59)" "$(r 0 59)")_$m
    say "Migrating: $id"
    think
    say "${G}Migrated:${N}  $id ${D}($(r 40 900).$(r 10 99)ms)${N}"
  done
}

while :; do
  "$(pick install build suite suite image deploy logs logs migrate)"
done
