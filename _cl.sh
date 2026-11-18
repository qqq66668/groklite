set -u
echo PWD=$(pwd)
gh auth switch --user qqq66668 > /dev/null 2>&1 || true
echo ===scratch-in-head===
git ls-files _wrap.sh
git log --oneline -2
echo ===stage-removal===
git add -A
git status --short | head -6
git commit -q -m "chore: drop a scratch script committed by mistake"; echo commit=$?
git log --oneline -1
echo commits=$(git rev-list --count HEAD)
echo ===push===
pushed=0
for i in 1 2 3; do
  if timeout 45 git push -u origin main > /tmp/cl_push.log 2>&1; then pushed=1; echo push_ok=$i; break; fi
  echo push_fail=$i; tail -1 /tmp/cl_push.log; sleep 8
done
echo pushed=$pushed
head=$(git rev-parse --short HEAD); echo head=$head
if [ "$pushed" = "1" ]; then
  for i in 1 2 3 4 5 6; do
    row=$(gh run list --repo qqq66668/groklite --limit 3 2>&1 | grep -F "$head" | head -1)
    echo poll_$i :: $row
    case "$row" in *completed*) break ;; esac
    sleep 20
  done
fi
echo ===state===
echo dirty=$(git status --short | wc -l)
echo modv=$(grep -E "^version" moon.mod)
echo rules=$(grep -c "registry.add(" src/registry/builtin.mbt)
echo authors=$(git log --all --format=%ae | sort -u | wc -l)
echo tests=$(moon test 2>&1 | grep -F "Total tests" | head -1)
bash tools/check_no_pii.sh > /tmp/cl_h.log 2>&1; echo hygiene=$?
echo whoami=$(moon whoami 2>&1 | head -1)