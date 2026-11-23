#!/bin/bash
# Robust ranged download of the LifeSnaps zip (Zenodo record 7229547, v4): 12 parts in parallel,
# each part resumed from its current size until complete, then concatenated and md5-checked.
set -u
DEST=/private/tmp/claude-501/-Users-clement-Hanyang-Harmony/c2063cc9-8a1d-4a62-98ec-d0a36282975d/scratchpad/ext/lifesnaps
URL="https://zenodo.org/records/7229547/files/rais_anonymized.zip?download=1"
SIZE=615037493
MD5=726afe263ab4b900a721eac19b2ca13a
N=12
CH=$(( (SIZE + N - 1) / N ))
mkdir -p "$DEST/parts"
rm -f "$DEST/rais_anonymized.zip"
part() {
  local i=$1 S=$(( $1 * CH )) E=$(( $1 * CH + CH - 1 ))
  [ $E -ge $SIZE ] && E=$(( SIZE - 1 ))
  local want=$(( E - S + 1 )) f="$DEST/parts/p$(printf %02d $i)" tries=0
  touch "$f"
  while :; do
    local have=$(stat -f %z "$f")
    [ "$have" -ge "$want" ] && break
    tries=$(( tries + 1 )); [ $tries -gt 40 ] && { echo "part $i gave up at $have/$want"; return 1; }
    curl -sS -f -L -A "dataset-research-client" --max-time 900 -r $(( S + have ))-$E "$URL" >> "$f" 2>/dev/null
  done
  echo "part $i ok ($tries tries)"
}
for i in $(seq 0 $((N-1))); do part $i & done
wait
cat "$DEST"/parts/p* > "$DEST/rais_anonymized.zip"
GOT=$(md5 -q "$DEST/rais_anonymized.zip")
ls -la "$DEST/rais_anonymized.zip"
if [ "$GOT" = "$MD5" ]; then echo "MD5 OK"; rm -rf "$DEST/parts"; else echo "MD5 MISMATCH $GOT"; fi
