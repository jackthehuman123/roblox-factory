#!/usr/bin/env bash
# Tests for tools/asset_db.luau against temp roots. Prints nothing on success.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.rokit/bin:$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

fail() {
	echo "tests/asset_db.test.sh: $1"
	fails=$((fails + 1))
}

# db <root> <args...>: sets $out and $status
db() {
	local r="$1"
	shift
	out="$(lune run tools/asset_db --root "$r" "$@" 2>&1)"
	status=$?
}

# scaffold <name>: empty library under $TMP/<name>/assets, with a Bed model and thumb
scaffold() {
	local a="$TMP/$1/assets"
	mkdir -p "$a/library" "$a/thumbs" "$a/images" "$a/skipped" "$a/inbox"
	cp assets/tags.luau "$a/tags.luau"
	printf 'return {}\n' >"$a/index.luau"
	printf 'return {}\n' >"$a/images.luau"
	printf 'return { parts = { { size = { 1, 1, 1 }, at = { 0, 0.5, 0 } } } }\n' >"$a/library/Bed.luau"
	: >"$a/thumbs/Bed.png"
}

entry() {
	printf '{"name":"%s","tags":["light"],"size":[1,1,1],"sources":["%s"],"built":"code","review":"approved"}' "$1" "$2" >"$TMP/$1.json"
}

result() {
	printf '{"built":["Bed"],"skipped":[{"object":"Rug","why":"flat"}]}' >"$TMP/result.json"
}

check_clean() {
	local o
	o="$(lune run tools/asset_check --root "$1" 2>&1)"
	[ -z "$o" ] || fail "$2: asset_check not clean: $o"
}

R="$TMP/a"
scaffold a
echo one >"$R/assets/inbox/bed.png"
result
db "$R" seen "$R/assets/inbox/bed.png"
[ "$status" -eq 0 ] && [ "$out" = "new" ] || fail "seen new: got $status '$out'"

entry Bed bed.png
db "$R" add "$TMP/Bed.json"
[ "$status" -eq 0 ] || fail "add: expected 0, got $status ($out)"
grep -q 'review = "unreviewed"' "$R/assets/index.luau" || fail "add: review not forced to unreviewed"
db "$R" add "$TMP/Bed.json"
[ "$status" -eq 1 ] || fail "add duplicate: expected 1, got $status"
printf '%s\n' "$out" | grep -q '^asset_db: ' || fail "add duplicate: message: $out"

entry Ghost bed.png
db "$R" add "$TMP/Ghost.json"
[ "$status" -eq 1 ] || fail "add without library file: expected 1, got $status"

db "$R" merge Bed other.png
[ "$status" -eq 0 ] || fail "merge: expected 0, got $status ($out)"
db "$R" merge Bed other.png
[ "$(grep -o 'other.png' "$R/assets/index.luau" | wc -l | tr -d ' ')" -eq 1 ] || fail "merge: source added twice"
db "$R" merge Nope other.png
[ "$status" -eq 1 ] || fail "merge unknown: expected 1, got $status"
echo one >"$R/assets/images/other.png"

db "$R" finish "$R/assets/inbox/bed.png" done "$TMP/result.json"
[ "$status" -eq 0 ] && [ "$out" = "finished bed.png" ] || fail "finish done: got $status '$out'"
[ ! -e "$R/assets/inbox/bed.png" ] && [ -e "$R/assets/images/bed.png" ] || fail "finish done: file not moved"
grep -q 'file = "bed.png"' "$R/assets/images.luau" || fail "finish done: not logged"
check_clean "$R" "after finish done"

cp "$R/assets/images/bed.png" "$R/assets/inbox/renamed copy.png"
db "$R" seen "$R/assets/inbox/renamed copy.png"
[ "$out" = "processed bed.png" ] || fail "seen processed: got '$out'"

# redo: same content finished again keeps one entry
db "$R" finish "$R/assets/inbox/renamed copy.png" done "$TMP/result.json"
[ "$status" -eq 0 ] || fail "redo: expected 0, got $status ($out)"
[ "$(grep -c 'hash = ' "$R/assets/images.luau")" -eq 1 ] || fail "redo: log has more than one entry"
check_clean "$R" "after redo"

# skipped
echo two >"$R/assets/inbox/sk.png"
db "$R" finish "$R/assets/inbox/sk.png" skipped "$TMP/result.json"
[ "$status" -eq 0 ] && [ -e "$R/assets/skipped/sk.png" ] || fail "finish skipped: $status $out"
grep -A6 'file = "sk.png"' "$R/assets/images.luau" | grep -q 'status = "skipped"' || fail "finish skipped: status"

# odd file name
echo three >"$R/assets/inbox/bedroom photos (1).png"
printf '{"built":[],"skipped":[]}' >"$TMP/empty.json"
db "$R" finish "$R/assets/inbox/bedroom photos (1).png" done "$TMP/empty.json"
[ "$status" -eq 0 ] && [ -e "$R/assets/images/bedroom photos (1).png" ] || fail "odd name: $status $out"
grep -q 'file = "bedroom photos (1).png"' "$R/assets/images.luau" || fail "odd name: not logged"
check_clean "$R" "after odd name"

# name clash
echo different >"$R/assets/inbox/bed.png"
db "$R" finish "$R/assets/inbox/bed.png" done "$TMP/empty.json"
[ "$status" -eq 0 ] && [ "$out" = "finished bed-2.png" ] || fail "name clash: got $status '$out'"
[ -e "$R/assets/images/bed-2.png" ] && [ "$(cat "$R/assets/images/bed.png")" = "one" ] || fail "name clash: files"
grep -q 'file = "bed-2.png"' "$R/assets/images.luau" || fail "name clash: not logged"
check_clean "$R" "after name clash"

# add and merge on a complete catalogue stay clean
B="$TMP/b"
scaffold b
echo one >"$B/assets/images/bed.png"
echo two >"$B/assets/images/other.png"
db "$B" add "$TMP/Bed.json"
[ "$status" -eq 0 ] || fail "add (complete): $status $out"
check_clean "$B" "after add"
db "$B" merge Bed other.png
check_clean "$B" "after merge"

# finish on an image already in place, spelled oddly, must not delete it
(cd "$B" && lune run "$ROOT/tools/asset_db" finish ./assets/images/bed.png done "$TMP/result.json" >/dev/null 2>&1)
[ -e "$B/assets/images/bed.png" ] || fail "relative in-place finish: file deleted"
db "$B" finish "$B/assets/../assets//images/bed.png" done "$TMP/result.json"
[ -e "$B/assets/images/bed.png" ] || fail "odd-spelled in-place finish: file deleted"
[ "$(grep -c 'hash = ' "$B/assets/images.luau")" -eq 1 ] || fail "in-place finish: log count"
check_clean "$B" "after in-place finish"

# bad result.json: exit 1, nothing moved, nothing logged
echo bad >"$B/assets/inbox/new.png"
printf '{"built":"Bed"}' >"$TMP/bad1.json"
printf '{"built":[],"skipped":[{"object":"Rug"}]}' >"$TMP/bad2.json"
for bad in bad1 bad2; do
	db "$B" finish "$B/assets/inbox/new.png" done "$TMP/$bad.json"
	[ "$status" -eq 1 ] || fail "$bad: expected 1, got $status"
	printf '%s\n' "$out" | grep -q '^asset_db: ' || fail "$bad: message: $out"
	[ -e "$B/assets/inbox/new.png" ] || fail "$bad: image moved"
done
[ "$(grep -c 'hash = ' "$B/assets/images.luau")" -eq 1 ] || fail "bad result: logged anyway"

# bad entry json
printf '{"name":"Bed","tags":"light"}' >"$TMP/badentry.json"
db "$B" add "$TMP/badentry.json"
[ "$status" -eq 1 ] && printf '%s\n' "$out" | grep -q '^asset_db: ' || fail "bad entry: $status $out"

# redo keeps the logged file name and follows a status change
C="$TMP/c"
scaffold c
echo same >"$C/assets/inbox/bed.png"
db "$C" finish "$C/assets/inbox/bed.png" done "$TMP/result.json"
echo same >"$C/assets/inbox/other-name.png"
db "$C" finish "$C/assets/inbox/other-name.png" done "$TMP/result.json"
[ "$out" = "finished bed.png" ] || fail "redo name: got '$out'"
[ -e "$C/assets/images/bed.png" ] && [ ! -e "$C/assets/images/other-name.png" ] && [ ! -e "$C/assets/inbox/other-name.png" ] || fail "redo: stale or missing file"
echo same >"$C/assets/inbox/third.png"
db "$C" finish "$C/assets/inbox/third.png" skipped "$TMP/result.json"
[ -e "$C/assets/skipped/bed.png" ] && [ ! -e "$C/assets/images/bed.png" ] && [ ! -e "$C/assets/inbox/third.png" ] || fail "redo status change: files"
[ "$(grep -c 'hash = ' "$C/assets/images.luau")" -eq 1 ] || fail "redo status: log count"
grep -A6 'file = "bed.png"' "$C/assets/images.luau" | grep -q 'status = "skipped"' || fail "redo status: log status"

# review round trip and empty library
D="$TMP/d"
scaffold d
echo one >"$D/assets/images/bed.png"
db "$D" add "$TMP/Bed.json"
db "$D" review
[ "$status" -eq 0 ] && grep -q '^- \[ \] Bed' "$D/assets/REVIEW.md" || fail "review render: $status $out"
sed -i.bak 's/verdict:$/verdict: approved/' "$D/assets/REVIEW.md"
db "$D" review
[ "$status" -eq 0 ] && [ "$(printf '%s\n' "$out" | head -1)" = "review: 1 verdicts applied" ] || fail "review apply: $status $out"
grep -q 'review = "approved"' "$D/assets/index.luau" || fail "review: index not approved"
grep -q '^- \[x\] Bed — verdict: approved' "$D/assets/REVIEW.md" || fail "review: not under Checked"
check_clean "$D" "after review"
cp "$D/assets/REVIEW.md" "$TMP/rev1.md"
cp "$D/assets/index.luau" "$TMP/idx1.luau"
db "$D" review
[ "$out" = "review: 0 verdicts applied" ] && cmp -s "$TMP/rev1.md" "$D/assets/REVIEW.md" && cmp -s "$TMP/idx1.luau" "$D/assets/index.luau" || fail "review idempotent: $out"
sed -i.bak 's/verdict: approved/verdict: Rejected: too small/' "$D/assets/REVIEW.md"
db "$D" review
grep -q 'regen: too small' "$D/assets/REVIEW.md" || fail "capitalised rejection lost"
sed -i.bak 's/verdict: regen: too small/verdict: hmm/' "$D/assets/REVIEW.md"
db "$D" review
printf '%s\n' "$out" | grep -q '^asset_db: ignored line' && grep -q 'verdict: hmm' "$D/assets/REVIEW.md" || fail "typed text erased: $out"
E="$TMP/e"
scaffold e
rm "$E/assets/library/Bed.luau"
db "$E" review
[ "$status" -eq 0 ] && [ "$out" = "review: 0 verdicts applied" ] || fail "empty library: $status $out"

# wanted list: unticked item waits, ticked and approved is ready
F="$TMP/f"
scaffold f
printf '## game-a\n- [ ] Bed — a bed\n' >"$F/assets/WANTED.md"
db "$F" wanted game-a
[ "$status" -eq 0 ] && [ "$out" = "wanted Bed: a bed" ] || fail "wanted unticked: $status '$out'"
echo one >"$F/assets/images/bed.png"
db "$F" add "$TMP/Bed.json"
db "$F" want-done Bed
[ "$status" -eq 0 ] && [ "$out" = "wanted: Bed done" ] || fail "want-done: $status '$out'"
grep -q '^- \[x\] Bed — built' "$F/assets/WANTED.md" || fail "want-done: not ticked"
db "$F" wanted game-a
[ "$out" = "review Bed" ] || fail "wanted before approval: '$out'"
db "$F" review
sed -i.bak 's/verdict:$/verdict: approved/' "$F/assets/REVIEW.md"
db "$F" review
db "$F" wanted game-a
[ "$status" -eq 0 ] && [ -z "$out" ] || fail "wanted ready: $status '$out'"
db "$F" want-done Bed
[ "$status" -eq 1 ] && [ "$out" = "asset_db: Bed is not wanted" ] || fail "want-done unknown: $status '$out'"

# M3: only the asked-for section's garbled lines are reported
printf '## game-a\n- [ ] Bed — a bed\n## game-b\n- [ ] lower — typo\n' >"$F/assets/WANTED.md"
db "$F" wanted game-a
printf '%s\n' "$out" | grep -q 'ignored line' && fail "wanted: other game's typo reported: $out"
db "$F" wanted game-b
printf '%s\n' "$out" | grep -q 'ignored line - \[ \] lower' || fail "wanted: own typo not reported: $out"

# C1: replace is only for regen (or legacy rejected) entries
H="$TMP/h"
scaffold h
echo one >"$H/assets/images/bed.png"
db "$H" add "$TMP/Bed.json"
db "$H" replace "$TMP/Bed.json"
[ "$status" -eq 1 ] || fail "replace unreviewed: expected 1, got $status ($out)"
db "$H" review
sed -i.bak 's/verdict:$/verdict: approved/' "$H/assets/REVIEW.md"
db "$H" review
db "$H" replace "$TMP/Bed.json"
[ "$status" -eq 1 ] || fail "replace approved: expected 1, got $status ($out)"
sed -i.bak 's/verdict: approved/verdict: rejected: too small/' "$H/assets/REVIEW.md"
db "$H" review
grep -q 'reason = "too small"' "$H/assets/index.luau" || fail "replace setup: not rejected"
db "$H" replace "$TMP/Bed.json"
[ "$status" -eq 0 ] || fail "replace regen: expected 0, got $status ($out)"
grep -q 'review = "unreviewed"' "$H/assets/index.luau" || fail "replace: not unreviewed"
grep -q 'reason' "$H/assets/index.luau" && fail "replace: reason not cleared"
db "$H" replace "$TMP/Ghost.json"
[ "$status" -eq 1 ] || fail "replace unknown name: expected 1, got $status"
check_clean "$H" "after replace"
db "$H" review
grep -q 'review = "unreviewed"' "$H/assets/index.luau" || fail "replace then review: flipped back: $out"
grep -q '^- \[ \] Bed' "$H/assets/REVIEW.md" || fail "replace then review: not under To check"
grep -q '^- \[x\] Bed' "$H/assets/REVIEW.md" && fail "replace then review: stale checked line"

# C2: sources follow the stored image name
I="$TMP/i"
scaffold i
echo A >"$I/assets/images/bed.png"
echo B >"$I/assets/inbox/bed.png"
db "$I" add "$TMP/Bed.json"
db "$I" finish "$I/assets/inbox/bed.png" done "$TMP/empty.json"
[ "$out" = "finished bed-2.png" ] || fail "sources clash: got '$out'"
grep -q 'bed-2.png' "$I/assets/index.luau" && ! grep -q '"bed.png"' "$I/assets/index.luau" || fail "sources not rewritten"
check_clean "$I" "after sources rewrite"

# I1: a status-changing redo never deletes a different image at the destination name
J="$TMP/j"
scaffold j
echo A >"$J/assets/inbox/bed.png"
db "$J" finish "$J/assets/inbox/bed.png" done "$TMP/empty.json"
echo B >"$J/assets/inbox/bed.png"
db "$J" finish "$J/assets/inbox/bed.png" skipped "$TMP/empty.json"
echo A >"$J/assets/inbox/x.png"
db "$J" finish "$J/assets/inbox/x.png" skipped "$TMP/empty.json"
[ "$status" -eq 0 ] || fail "redo clash: $status $out"
[ "$(cat "$J/assets/skipped/bed.png")" = "B" ] || fail "redo clash: B lost"
[ "$(cat "$J/assets/skipped/bed-2.png")" = "A" ] || fail "redo clash: A lost"
[ ! -e "$J/assets/images/bed.png" ] && [ ! -e "$J/assets/inbox/x.png" ] || fail "redo clash: stale files"
grep -q 'file = "bed-2.png"' "$J/assets/images.luau" || fail "redo clash: log name"
[ "$(grep -c 'hash = ' "$J/assets/images.luau")" -eq 2 ] || fail "redo clash: log count"

# I2: drop removes only the inbox copy of a processed image
K="$TMP/k"
scaffold k
echo A >"$K/assets/inbox/bed.png"
db "$K" finish "$K/assets/inbox/bed.png" skipped "$TMP/result.json"
cp "$K/assets/images.luau" "$TMP/k-log.luau"
echo A >"$K/assets/inbox/again.png"
db "$K" drop "$K/assets/inbox/again.png"
[ "$status" -eq 0 ] && [ "$out" = "dropped: again.png (already processed as bed.png)" ] || fail "drop: $status '$out'"
[ ! -e "$K/assets/inbox/again.png" ] && [ -e "$K/assets/skipped/bed.png" ] || fail "drop: files"
cmp -s "$TMP/k-log.luau" "$K/assets/images.luau" || fail "drop: log changed"
echo Z >"$K/assets/inbox/new.png"
db "$K" drop "$K/assets/inbox/new.png"
[ "$status" -eq 1 ] && [ -e "$K/assets/inbox/new.png" ] || fail "drop unknown: $status $out"
# R3: drop refuses when the stored copy is missing
rm "$K/assets/skipped/bed.png"
db "$K" drop "$K/assets/inbox/new.png"
echo A >"$K/assets/inbox/again.png"
db "$K" drop "$K/assets/inbox/again.png"
[ "$status" -eq 1 ] && [ "$out" = "asset_db: stored copy of again.png missing — not dropping" ] && [ -e "$K/assets/inbox/again.png" ] || fail "drop missing stored: $status '$out'"

# criteria + measure
M="$TMP/m"
scaffold m
echo one >"$M/assets/images/bed.png"
db "$M" add "$TMP/Bed.json"
printf '{"name":"Bed","size":[0,1,1],"prompt":"A bed.","source":"bed.png"}' >"$TMP/bad-crit.json"
db "$M" criteria "$TMP/bad-crit.json"
[ "$status" -eq 1 ] && [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "1" ] || fail "bad criteria: $status '$out'"
[ ! -e "$M/assets/criteria/Bed.json" ] || fail "bad criteria written"
printf '{"name":"Bed","size":[1,1,1],"prompt":"A bed.","source":"bed.png","notes":["too shiny"]}' >"$TMP/crit.json"
db "$M" criteria "$TMP/crit.json"
[ "$status" -eq 0 ] && [ -e "$M/assets/criteria/Bed.json" ] || fail "criteria not written: $status '$out'"
printf '{"name":"Bed","size":[1,1,1],"prompt":"A bed again.","source":"bed.png"}' >"$TMP/crit2.json"
db "$M" criteria "$TMP/crit2.json"
grep -q 'too shiny' "$M/assets/criteria/Bed.json" || fail "criteria rewrite dropped notes"
grep -q 'A bed again' "$M/assets/criteria/Bed.json" || fail "criteria not overwritten"
db "$M" measure Bed
[ "$status" -eq 0 ] || fail "measure exited $status: $out"
[ "$(printf '%s\n' "$out" | tail -1)" = "parts 1" ] || fail "measure last line: $out"
printf '%s\n' "$out" | grep -q 'PASS\|FAIL' && fail "measure still labels pass/fail: $out"
grep -q 'measure = ' "$M/assets/index.luau" || fail "measure not saved on entry"
db "$M" measure Ghost
[ "$status" -eq 1 ] || fail "measure unknown: $status"
check_clean "$M" "after measure"

# discard, regen queue, want-done refusal
N="$TMP/n"
scaffold n
echo one >"$N/assets/images/bed.png"
db "$N" add "$TMP/Bed.json"
db "$N" criteria "$TMP/crit2.json"
printf '## game-a\n- [x] Bed — built\n\n## game-b\n- [x] Bed — built\n' >"$N/assets/WANTED.md"
db "$N" review
sed -i.bak 's/verdict:$/verdict: regen: too shiny/' "$N/assets/REVIEW.md"
db "$N" review
grep -q 'review = "regen"' "$N/assets/index.luau" || fail "regen not stored"
tail -c 200 "$N/assets/criteria/Bed.json" | grep -q 'too shiny' || fail "regen note not in criteria: $(cat "$N/assets/criteria/Bed.json")"
db "$N" regen-next
[ "$out" = "Bed" ] || fail "regen-next: '$out'"
printf '{"name":"Bed","tags":["light"],"size":[1,1,1],"sources":["bed.png"],"built":"generated","review":"unreviewed"}' >"$TMP/BedGen.json"
db "$N" replace "$TMP/BedGen.json"
[ "$status" -eq 0 ] && grep -q 'review = "unreviewed"' "$N/assets/index.luau" || fail "replace regen: $status $out"
awk 'f&&/name = /{exit} /name = "Bed"/{f=1} f' "$N/assets/index.luau" | grep -q 'gens = 1' || fail "replace of a code-built asset: first generation should be 1"
printf '{"name":"Lamp","tags":["light"],"size":[1,1,1],"sources":["bed.png"],"built":"generated","review":"unreviewed"}' >"$TMP/Lamp.json"
printf 'return { parts = { { size = { 1, 1, 1 }, at = { 0, 0.5, 0 } } } }\n' >"$N/assets/library/Lamp.luau"
: >"$N/assets/thumbs/Lamp.png"
db "$N" add "$TMP/Lamp.json"
awk 'f&&/name = /{exit} /name = "Lamp"/{f=1} f' "$N/assets/index.luau" | grep -q 'gens = 1' || fail "add: gens not 1"
db "$N" review
sed -i.bak 's/^- \[ \] Lamp \(.*\) — verdict:$/- [x] Lamp \1 — verdict: regen: dim/' "$N/assets/REVIEW.md"
db "$N" review
db "$N" replace "$TMP/Lamp.json"
awk 'f&&/name = /{exit} /name = "Lamp"/{f=1} f' "$N/assets/index.luau" | grep -q 'gens = 2' || fail "replace of a generated asset: gens not 2"
db "$N" regen-next
[ -z "$out" ] || fail "regen-next after replace: '$out'"
db "$N" review
sed -i.bak 's/verdict:$/verdict: discard/' "$N/assets/REVIEW.md"
db "$N" review
printf '%s\n' "$out" | grep -qx 'discarded Bed' || fail "discard output: $out"
[ ! -e "$N/assets/library/Bed.luau" ] && [ ! -e "$N/assets/thumbs/Bed.png" ] && [ ! -e "$N/assets/criteria/Bed.json" ] || fail "discard left files"
grep -q '"Bed"' "$N/assets/index.luau" && fail "discard left the entry"
[ "$(grep -c '^- \[ \] Bed — discarded; drop a new reference image$' "$N/assets/WANTED.md")" = "2" ] || fail "discard did not untick both: $(cat "$N/assets/WANTED.md")"
check_clean "$N" "after discard"
db "$N" want-done Ghost
[ "$status" -eq 1 ] && [ "$out" = "asset_db: Ghost is not in the library" ] || fail "want-done ghost: $status '$out'"

# discard also drops the name from the image log (asset came through finish)
O="$TMP/o"
scaffold o
echo one >"$O/assets/inbox/bed.png"
db "$O" add "$TMP/Bed.json"
result
db "$O" finish "$O/assets/inbox/bed.png" done "$TMP/result.json"
check_clean "$O" "discard setup"
db "$O" review
sed -i.bak 's/verdict:$/verdict: discard/' "$O/assets/REVIEW.md"
db "$O" review
printf '%s\n' "$out" | grep -qx 'discarded Bed' || fail "image-log discard output: $out"
grep -q '"Bed"' "$O/assets/images.luau" && fail "discard left Bed in the image log"
check_clean "$O" "after discard of a finished asset"

# review heals an image log that names an asset no longer in the index
P="$TMP/p"
scaffold p
echo one >"$P/assets/images/bed.png"
db "$P" add "$TMP/Bed.json"
H1="$(shasum -a 256 "$P/assets/images/bed.png" | cut -d' ' -f1)"
printf 'return {\n\t{ file = "bed.png", hash = "%s", status = "done", built = { "Bed", "Ghost" }, skipped = {} },\n}\n' "$H1" >"$P/assets/images.luau"
db "$P" review
grep -q '"Ghost"' "$P/assets/images.luau" && fail "review did not heal stale built name"
grep -q '"Bed"' "$P/assets/images.luau" || fail "review dropped a live built name"
check_clean "$P" "after heal"

# regen-failed: a failed regen leaves the queue and comes back to the user with why
Q="$TMP/q"
scaffold q
echo one >"$Q/assets/images/bed.png"
db "$Q" add "$TMP/Bed.json"
db "$Q" review
sed -i.bak 's/verdict:$/verdict: regen/' "$Q/assets/REVIEW.md"
db "$Q" review
grep -q 'reason = "no reason given"' "$Q/assets/index.luau" || fail "bare regen reason"
db "$Q" regen-next
[ "$out" = "Bed" ] || fail "bare regen not queued: '$out'"
db "$Q" regen-failed Bed "ERROR 0 models tagged x, need exactly 1"
[ "$status" -eq 0 ] || fail "regen-failed exited $status: $out"
db "$Q" regen-next
[ -z "$out" ] || fail "failed regen still queued: '$out'"
grep -q 'review = "unreviewed"' "$Q/assets/index.luau" || fail "failed regen not back to unreviewed"
grep -q 'regen failed: ERROR 0 models tagged x' "$Q/assets/REVIEW.md" || fail "failed regen reason not shown"
db "$Q" regen-failed Ghost "x"
[ "$status" -eq 1 ] || fail "regen-failed unknown: $status"
check_clean "$Q" "after regen-failed"

# a regen note survives when the criteria file is first written during the regen
R2="$TMP/r2"
scaffold r2
echo one >"$R2/assets/images/bed.png"
db "$R2" add "$TMP/Bed.json"
db "$R2" review
sed -i.bak 's/verdict:$/verdict: regen: too shiny/' "$R2/assets/REVIEW.md"
db "$R2" review
[ ! -e "$R2/assets/criteria/Bed.json" ] || fail "setup: criteria should not exist yet"
db "$R2" criteria "$TMP/crit2.json"
grep -q 'too shiny' "$R2/assets/criteria/Bed.json" || fail "regen note lost when criteria written during regen"

[ "$fails" -eq 0 ] || exit 1
