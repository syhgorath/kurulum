#!/usr/bin/env bash
# Hızlı testler: test/test_*.sh (statik denetim parmak izi için docker varsa kullanır). LAB e2e ayrıdır: bats test/e2e/lab-docker.bats test/e2e/lab-native.bats
cd "$(dirname "$0")/.." || exit 1
rc=0
for t in test/test_*.sh; do echo "=== $t"; bash "$t" || rc=1; done
echo "=== scripts/check-consistency.py"; python3 -I scripts/check-consistency.py || rc=1
exit $rc
