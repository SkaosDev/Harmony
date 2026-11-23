#!/bin/bash
# Runs every configuration in parallel (aggregates only are written to ../out).
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1 OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
PY=/Users/clement/Hanyang/Harmony/.venv/bin/python
{
for t in arousal valence; do for l in full past; do for r in 4 2 1; do echo "$t $l $r"; done; done; done
echo "stress full 2"; echo "stress past 2"
} | xargs -P 7 -L 1 sh -c "$PY sim.py --target \$0 --label \$1 --rate \$2 --seeds 3 > ../out/log_\$0_\$1_r\$2.txt 2>&1"
echo ALL DONE
# optional: uncertainty-based timing (after the main runs)
export PYTHONDONTWRITEBYTECODE=1 OMP_NUM_THREADS=1
{ echo "arousal past m1d"; echo "arousal full m1d"; echo "arousal past m3"; echo "valence past m1d"; } | \
  xargs -P 4 -L 1 sh -c "$PY uncert.py --target \$0 --label \$1 --rate 2 --which \$2 > ../out/log_uncert_\$0_\$1_\$2.txt 2>&1"
echo UNCERT DONE
