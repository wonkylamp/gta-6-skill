#!/bin/bash
# GTA VI launch-day cover. Scrolls a fake build-and-deploy all day, keeps the Mac
# awake, nudges the cursor 1px so Slack/Teams keep you "active", goes quiet at
# lunch, and clocks out on its own. Ctrl-C or `/gta-6 stop` ends the shift early.
#
# Settings come from env vars, or from a one-shot .session file the skill writes:
#   GTA6_TZ           IANA time zone for the schedule (default: the Mac's)
#   GTA6_CLOCK_OUT    HH:MM or "off" (default 17:30)
#   GTA6_LUNCH        HH:MM-HH:MM or "off" (default 12:30-13:15)
#   GTA6_PROJECT      repo to borrow service, test and commit names from (read-only)
#   GTA6_NUDGE_EVERY  seconds between cursor nudges (default 240)
#   GTA6_FORCE        1 = start even after clock-out time
#   GTA6_LID          1 = stay awake with the lid closed (asks for your password,
#                     undone at clock-out)
#   GTA6_DEMO         1 = scroll 4x faster and open with tests and a deploy,
#                     for screen recordings

DIR="$(cd "$(dirname "$0")" && pwd)"
G=$'\033[32m' Y=$'\033[33m' B=$'\033[34m' C=$'\033[36m' R=$'\033[31m' D=$'\033[2m' W=$'\033[1m' N=$'\033[0m'

warn() { echo "${Y}warn: $*${N}"; }

if [[ -f $DIR/.session ]]; then
  while IFS='=' read -r k v; do
    case $k in
      GTA6_TZ | GTA6_CLOCK_OUT | GTA6_LUNCH | GTA6_PROJECT | GTA6_NUDGE_EVERY | GTA6_FORCE | GTA6_LID)
        [[ -z ${!k} ]] && printf -v "$k" '%s' "$v" ;;
    esac
  done < "$DIR/.session"
  rm -f "$DIR/.session"
fi

HHMM='^([01]?[0-9]|2[0-3]):[0-5][0-9]$'
CLOCK_OUT=${GTA6_CLOCK_OUT:-17:30}
LUNCH=${GTA6_LUNCH:-12:30-13:15}
NUDGE_EVERY=${GTA6_NUDGE_EVERY:-240}
[[ $CLOCK_OUT == off || $CLOCK_OUT =~ $HHMM ]] || { warn "bad GTA6_CLOCK_OUT '$CLOCK_OUT', using 17:30"; CLOCK_OUT=17:30; }
if [[ $LUNCH != off ]] && ! [[ ${LUNCH%-*} =~ $HHMM && ${LUNCH#*-} =~ $HHMM ]]; then
  warn "bad GTA6_LUNCH '$LUNCH', using 12:30-13:15"
  LUNCH=12:30-13:15
fi

ZONE=$(readlink /etc/localtime | sed 's|.*zoneinfo/||')
if [[ -n $GTA6_TZ ]]; then
  if [[ -f /usr/share/zoneinfo/$GTA6_TZ ]]; then
    export TZ=$GTA6_TZ
    ZONE=$GTA6_TZ
  else
    warn "unknown time zone '$GTA6_TZ', using $ZONE"
  fi
fi

mins() { echo $((10#${1%%:*} * 60 + 10#${1##*:})); }
now() { mins "$(date +%H:%M)"; }
off_the_clock() { [[ $CLOCK_OUT != off ]] && (($(now) >= $(mins "$CLOCK_OUT"))); }
at_lunch() { [[ $LUNCH != off ]] && (($(now) >= $(mins "${LUNCH%-*}") && $(now) < $(mins "${LUNCH#*-}"))); }

if off_the_clock; then
  if [[ $GTA6_FORCE == 1 ]]; then
    warn "it's past $CLOCK_OUT, so no auto clock-out this run"
    CLOCK_OUT=off
  else
    printf '\n   %sAFTER HOURS%s\n   It is %s in %s. Nobody is watching. Go play.\n\n' "$W" "$N" "$(date +%H:%M)" "$ZONE"
    exit 0
  fi
fi

date +%s > "$DIR/.started"
rm -f "$DIR/.stats"
caffeinate -dims -w $$ &
if [[ ! -x $DIR/.jiggle ]] && command -v swiftc >/dev/null; then
  swiftc -O "$DIR/jiggle.swift" -o "$DIR/.jiggle" 2>/dev/null
fi
[[ -x $DIR/.jiggle ]] || warn "swiftc not found, cursor nudge is off (fix: xcode-select --install)"

sleep_disabled() { pmset -g 2>/dev/null | grep -q 'SleepDisabled[[:space:]]*1'; }
LID_SET=""
if [[ $GTA6_LID == 1 ]] && ! sleep_disabled; then
  echo "${W}Lid mode:${N} macOS needs your password to stay awake with the lid closed."
  if sudo pmset -a disablesleep 1; then
    LID_SET=1
    # Keep sudo fresh in this window so clock-out can turn sleep back on unattended.
    while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 60; done &
  else
    warn "sleep is still on, so closing the lid will sleep the Mac"
  fi
fi

# jot, not $RANDOM: bash 3.2 seeds $RANDOM in each $(...) from the pid, so
# back-to-back picks come out correlated.
r() { jot -r 1 "$1" "$2"; }
hex() { LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c "$1"; }
pick() { local a=("$@"); echo "${a[$(jot -r 1 0 $((${#a[@]} - 1)))]}"; }
chance() { (($(jot -r 1 1 "$1") == 1)); }
slug() { echo "$1" | tr 'A-Z_ ' 'a-z--' | tr -cd 'a-z0-9.-'; }

DOMAINS=(billing auth ledger search notifications payouts inventory checkout identity pricing orders webhooks reporting media sessions)
SUFFIXES=(api worker gateway service consumer scheduler)
VERBS=(retries rejects dedupes paginates caches normalises validates streams batches reconciles throttles serialises)
OBJECTS=("webhook deliveries" "refresh tokens" "ledger entries" "currency amounts" "search results" "payout batches" "session cookies" "audit events" "price tiers" "inventory holds" "idempotency keys" "feature flags")
CONDITIONS=("after a 503" "under concurrent writes" "across a DST rollover" "with a stale cursor" "when upstream times out" "on cold start" "for empty input" "with unicode names" "after a partial failure" "at the rate limit")
TYPES=(fix feat refactor perf chore test)
CHANGES=("handle stale cursor on retry" "guard against duplicate deliveries" "drop legacy fallback path" "cache lookups per request" "tighten timeout budget" "batch writes to cut round trips" "log request ids on failure" "make backfill resumable")
EGG_SERVICES=(leonida-api vice-ingest port-gellhorn-worker ambrosia-cache kelly-county-etl grassrivers-gateway)
EGG_TESTS=("backs off when wanted_level >= 3" "assigns heist crew of exactly two (jason, lucia)" "geo index covers all of leonida" "evicts stale entries from ambrosia cache")
EGG_COMMITS=("fix(heists): crew size off by one" "chore: bump @leonida/core to 6.0.0" "perf(vice-ingest): faster wanted-level decay")

# Borrow real names from a project, read-only, so the log looks like your codebase.
P_SERVICES=() P_TEST_FILES=() P_TESTS=() P_COMMITS=() ORG=platform BRANCH="" RUNNER="vitest run" LINTER="eslint . --max-warnings=0"
if [[ -n $GTA6_PROJECT ]]; then
  if [[ -d $GTA6_PROJECT ]]; then
    p=$GTA6_PROJECT
    ORG=$(slug "$(basename "$p")")
    for d in "$p"/apps/*/ "$p"/packages/*/ "$p"/services/*/; do
      [[ -d $d ]] && P_SERVICES+=("$(slug "$(basename "$d")")")
    done
    ((${#P_SERVICES[@]})) || P_SERVICES=("$ORG-api" "$ORG-worker" "$ORG-web")
    while IFS= read -r line; do P_TEST_FILES+=("$line"); done < <(
      { git -C "$p" ls-files 2>/dev/null || (cd "$p" && find . -type f -not -path '*/node_modules/*'); } |
        grep -E '\.(test|spec)\.|_test\.|Tests?\.swift$|(^|/)test_[^/]*\.py$' | head -300)
    if ((${#P_TEST_FILES[@]})); then
      while IFS= read -r line; do P_TESTS+=("$line"); done < <(
        cd "$p" && printf '%s\0' "${P_TEST_FILES[@]}" |
          xargs -0 grep -hoE "(it|test)\(['\"\`][^'\"\`]{8,70}|func test[A-Za-z0-9_]{4,60}|def test_[a-z0-9_]{4,60}" 2>/dev/null |
          awk '{
            if (sub(/^func test/, "")) { gsub(/[A-Z]/, " &"); $0 = tolower($0); gsub(/_/, " "); sub(/^ +/, "") }
            else if (sub(/^def test_/, "")) gsub(/_/, " ")
            else sub(/^(it|test)\(./, "")
            if (length($0) >= 8 && index($0, "${") == 0) print
          }' | sort -u | head -200)
      case ${P_TEST_FILES[0]} in
        *.swift) RUNNER="swift test --filter" LINTER="swiftlint lint --strict" ;;
        *.py) RUNNER="pytest -q" LINTER="ruff check ." ;;
      esac
    fi
    while IFS= read -r line; do P_COMMITS+=("$line"); done < <(git -C "$p" log --format=%s -n 80 2>/dev/null)
    BRANCH=$(git -C "$p" branch --show-current 2>/dev/null)
  else
    warn "GTA6_PROJECT '$GTA6_PROJECT' not found, using made-up names"
  fi
fi

service() {
  if ((${#P_SERVICES[@]})) && ! chance 4; then pick "${P_SERVICES[@]}"
  elif chance 12; then pick "${EGG_SERVICES[@]}"
  else echo "$(pick "${DOMAINS[@]}")-$(pick "${SUFFIXES[@]}")"; fi
}
test_name() {
  if ((${#P_TESTS[@]})) && ! chance 4; then pick "${P_TESTS[@]}"
  elif chance 8; then pick "${EGG_TESTS[@]}"
  else echo "$(pick "${VERBS[@]}") $(pick "${OBJECTS[@]}") $(pick "${CONDITIONS[@]}")"; fi
}
commit() {
  if ((${#P_COMMITS[@]})) && ! chance 4; then pick "${P_COMMITS[@]}"
  elif chance 8; then pick "${EGG_COMMITS[@]}"
  else echo "$(pick "${TYPES[@]}")($(pick "${DOMAINS[@]}")): $(pick "${CHANGES[@]}")"; fi
}

nap() { if [[ $GTA6_DEMO == 1 ]]; then sleep "$(awk "BEGIN { print $1 / 4 }")"; else sleep "$1"; fi; }
last_nudge=$SECONDS
tick() {
  if ((SECONDS - last_nudge >= NUDGE_EVERY)); then
    [[ -x $DIR/.jiggle ]] && "$DIR/.jiggle"
    last_nudge=$SECONDS
  fi
}
say() {
  printf '%s\n' "$*"
  nap "0.$(r 0 3)$(r 0 9)"
  tick
}
think() { nap "$(r 1 3).$(r 0 9)"; }
cmd() { say ""; say "${D}$(date '+%H:%M:%S')${N} ${W}\$ $*${N}"; }
rep() { local s; printf -v s '%*s' "$2" ''; echo "${s// /$1}"; }
bar() {
  local steps=$(r 12 24) i fill
  for ((i = 0; i <= steps; i++)); do
    fill=$((i * 28 / steps))
    printf '\r%s [%s%s] %3d%%' "$1" "$(rep = "$fill")" "$(rep ' ' $((28 - fill)))" $((i * 100 / steps))
    nap "0.$(r 1 4)"
  done
  printf '\n'
  tick
}

DEPLOYS=0 TESTS=0 IMAGES=0 MIGRATIONS=0
end_card() {
  local h=$((SECONDS / 3600)) m=$((SECONDS % 3600 / 60))
  printf '\n\n   %sEND OF SHIFT%s  %s %s\n\n' "$W" "$N" "$(date +%H:%M)" "$ZONE"
  printf '   deploys shipped   %s\n   tests passed      %s\n   images pushed     %s\n   migrations run    %s\n   time in Leonida   %dh %02dm\n\n' \
    "$DEPLOYS" "$TESTS" "$IMAGES" "$MIGRATIONS" "$h" "$m"
  printf '   %sMISSION PASSED%s\n   %sRESPECT +%s\n\n' $'\033[1;33m' "$N" "$W" "$N"
  [[ -n $LID_SET ]] && sudo -n pmset -a disablesleep 0 2>/dev/null && LID_SET=""
  sleep_disabled && printf '   %sSleep is still disabled. Undo with: sudo pmset -a disablesleep 0%s\n\n' "$Y" "$N"
  printf 'deploys=%s\ntests=%s\nimages=%s\nmigrations=%s\nseconds=%s\n' "$DEPLOYS" "$TESTS" "$IMAGES" "$MIGRATIONS" "$SECONDS" > "$DIR/.stats"
}

install() {
  cmd "pnpm install --frozen-lockfile"
  say "Lockfile is up to date, resolution step is skipped"
  bar "Progress: resolved $(r 1200 1500), reused $(r 1100 1400)"
  local pkg=$(pick esbuild esbuild sharp @prisma/client @leonida/core)
  say "${D}node_modules/$pkg: Running postinstall script, done in $(r 1 4).$(r 0 9)s${N}"
  say "Done in $(r 8 40).$(r 1 9)s"
}

build() {
  cmd "turbo run build --filter=...[origin/main]"
  local n=$(r 3 5) svc i
  for ((i = 0; i < n; i++)); do
    svc=$(service)
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
  local file a target n=$(r 6 9) passed=0 tries=0 seen="|" t
  if ((${#P_TEST_FILES[@]})); then
    file=$(pick "${P_TEST_FILES[@]}")
  else
    a=$(pick "${DOMAINS[@]}")
    file=src/$a/$a.test.ts
  fi
  target=$file
  [[ $RUNNER == swift* ]] && target=$(basename "$file" .swift)
  cmd "$RUNNER $target"
  while ((passed < n && tries < 40)); do
    tries=$((tries + 1))
    t=$(test_name)
    [[ $seen == *"|$t|"* ]] && continue
    seen="$seen$t|"
    if chance 9; then
      say " ${R}✗${N} $file > $t ${D}$(r 900 3000)ms${N}"
      say "   ${R}→ expected 200, received 504${N}"
      say "   ${Y}retry 1/2${N}"
      think
    fi
    say " ${G}✓${N} $file > $t ${D}$(r 2 400)ms${N}"
    passed=$((passed + 1))
  done
  say ""
  say " ${W}Test Files${N}  ${G}1 passed${N} (1)"
  say "      ${W}Tests${N}  ${G}$passed passed${N} ($passed)"
  say "   ${W}Duration${N}  $(r 1 9).$(r 10 99)s"
  TESTS=$((TESTS + passed))
}

image() {
  local svc=$(service) sha=$(hex 7) i
  cmd "docker buildx build --platform linux/amd64 -t ghcr.io/$ORG/$svc:$sha --push ."
  local steps=("FROM node:22-alpine AS base" "WORKDIR /app" "COPY pnpm-lock.yaml package.json ./" "RUN pnpm fetch --prod" "COPY . ." "RUN pnpm build" "RUN pnpm prune --prod" "FROM gcr.io/distroless/nodejs22" "COPY --from=base /app/dist ./dist")
  for ((i = 0; i < ${#steps[@]}; i++)); do
    say "#$((i + 4)) [$((i + 1))/${#steps[@]}] ${steps[i]}"
    chance 3 && think
    say "#$((i + 4)) DONE $(r 0 14).$(r 0 9)s"
  done
  say "#14 exporting to image"
  bar "#14 pushing layers"
  say "#14 pushing manifest for ghcr.io/$ORG/$svc:$sha@sha256:$(hex 64)"
  say "#14 DONE $(r 3 12).$(r 0 9)s"
  IMAGES=$((IMAGES + 1))
}

deploy() {
  local svc=$(service) i
  cmd "kubectl -n prod rollout status deploy/$svc"
  for i in 1 2 3 4 5; do
    say "Waiting for deployment \"$svc\" rollout to finish: $i of 6 updated replicas are available..."
    think
  done
  say "${G}deployment \"$svc\" successfully rolled out${N}"
  DEPLOYS=$((DEPLOYS + 1))
}

logs() {
  local svc=$(service) n=$(r 10 20) i
  cmd "stern -n prod $svc --since 1m"
  for ((i = 0; i < n; i++)); do
    if chance 8; then
      say "${Y}$svc-$(hex 5)${N} $(date '+%H:%M:%S') ${Y}WARN${N} $(pick "slow query $(r 400 1900)ms" "retrying upstream (attempt 2/3)" "pool at $(r 80 95)% capacity" "upstream slow, wanted_level=$(r 1 3), backing off $(r 2 8)s")"
    else
      say "${C}$svc-$(hex 5)${N} $(date '+%H:%M:%S') ${B}INFO${N} req=$(hex 12) $(pick GET POST PUT) /v1/$(pick "${DOMAINS[@]}") $(pick 200 200 200 201 204) ${D}$(r 4 180)ms${N}"
    fi
  done
}

migrate() {
  cmd "pnpm db:migrate --env=staging"
  local m id first=add_$(pick "${DOMAINS[@]}")_index last=drop_legacy_$(pick "${DOMAINS[@]}")_flags
  chance 5 && first=add_vice_city_index
  chance 5 && last=drop_legacy_wanted_flags
  for m in "$first" "backfill_$(pick "${DOMAINS[@]}")_owners" "$last"; do
    id=$(date +%Y_%m_%d)_$(printf '%02d%02d%02d' "$(r 9 17)" "$(r 0 59)" "$(r 0 59)")_$m
    say "Migrating: $id"
    if [[ $m == backfill* ]]; then bar "  rows"; else think; fi
    say "${G}Migrated:${N}  $id ${D}($(r 40 900).$(r 10 99)ms)${N}"
  done
  MIGRATIONS=$((MIGRATIONS + 3))
}

lint() {
  cmd "$LINTER"
  bar "Linting $(r 300 1400) files"
  say "${G}✓${N} No problems found"
}

git_log() {
  local i
  cmd "git pull --rebase && git log --oneline -6"
  say "Successfully rebased and updated refs/heads/${BRANCH:-main}."
  for i in 1 2 3 4 5 6; do say "${Y}$(hex 7)${N} $(commit)"; done
}

lunch() {
  local spin=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0
  cmd "gh pr checks --watch"
  say "${G}All checks were successful${N}"
  while at_lunch; do
    printf '\r%s Waiting on review (1 of 2 required approvals)' "${spin[i++ % 10]}"
    sleep 1
  done
  printf '\r%s✓%s Approved by 2 reviewers, merging            \n' "$G" "$N"
  last_nudge=$SECONDS
}

trap 'end_card; exit 0' INT TERM HUP
printf '\033]0;deploy — prod\007'

[[ $GTA6_DEMO == 1 ]] && for phase in suite deploy image; do "$phase"; done
while :; do
  off_the_clock && { end_card; exit 0; }
  at_lunch && lunch
  "$(pick install build suite suite image deploy logs logs migrate lint git_log)"
done
