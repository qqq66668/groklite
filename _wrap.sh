set -u
PY=/e/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/python/python.exe
NODE=/d/DeepSeekHarness/resources/runtime/primary-runtime/dependencies/node/bin/node.exe
CLI=/d/DeepSeekHarness/resources/app.asar.unpacked/dsh/node_modules/@deepseek-ai/libreoffice-kit/lib/cli.js
echo PWD=$(pwd)
echo MODV=$(grep -E "^version" moon.mod)
gh auth switch --user qqq66668 > /dev/null 2>&1 || true
echo ===gates===
moon fmt > /dev/null 2>&1; echo fmt=$?
moon check --deny-warn > /tmp/wa.log 2>&1; echo check=$?
grep -F -e "╭─[" -e "╰────" /tmp/wa.log | sed "s/^ *//" | head -12
moon test > /tmp/wb.log 2>&1; echo test=$?
grep -F "Total tests" /tmp/wb.log | head -1
moon test --target wasm-gc > /tmp/wc.log 2>&1; echo wasmgc=$?
moon test --target js > /tmp/wd.log 2>&1; echo js=$?
for ex in nginx_to_json syslog_to_json record_pipeline; do moon run examples/$ex > /dev/null 2>&1; echo example_$ex=$?; done
bash tools/check_no_pii.sh > /tmp/we.log 2>&1; echo hygiene=$?
tail -2 /tmp/we.log
echo ===bench-smoke===
moon run benchmarks -- noop > /tmp/wf.log 2>&1; echo bench_noop=$?
moon run benchmarks -- validate > /tmp/wg.log 2>&1; echo bench_validate=$?
tail -2 /tmp/wg.log
echo ===commit===
git status --short | head -8
git add -A
git commit -q -m "benchmarks: add a stage harness and document how it is read"; echo commit=$?
git log --oneline -1
echo commits=$(git rev-list --count HEAD)
echo ===push===
pushed=0
for i in 1 2 3; do
  if timeout 45 git push -u origin main > /tmp/wh.log 2>&1; then pushed=1; echo push_ok=$i; break; fi
  echo push_fail=$i; tail -1 /tmp/wh.log; sleep 8
done
echo pushed=$pushed
head=$(git rev-parse --short HEAD); echo head=$head
if [ "$pushed" = "1" ]; then
  for i in 1 2 3 4 5 6; do
    row=$(gh run list --repo qqq66668/groklite --limit 3 2>&1 | grep -F "$head" | head -1)
    echo "poll_$i ::${row}"
    case "$row" in *completed*) break ;; esac
    sleep 20
  done
fi
echo ===proposal===
cd ..
f=groklite_申报书.md
echo commits_marker=$(grep -c -F "28 条 commit" "$f" || true)
echo tests_marker=$(grep -c -F "110 个测试" "$f" || true)
echo rules_marker=$(grep -c -F "40 条内置规则" "$f" || true)
echo bench_marker=$(grep -c -F "可复现基准" "$f" || true)
rm -f _vt/c.pdf _vt/c.docx
"$PY" _vt/mk.py "$f" _vt/c.docx 10.5 > /tmp/wi.log 2>&1; echo mk=$?
"$NODE" "$CLI" convert --input _vt/c.docx --output _vt/c.pdf > /tmp/wj.log 2>&1; echo convert=$?
"$PY" _vt/cnt.py _vt/c.pdf
"$PY" _vt/cjkc.py "$f"
echo ===state===
cd groklite
echo commits=$(git rev-list --count HEAD)
echo head=$(git rev-parse --short HEAD)
echo dirty=$(git status --short | wc -l)
echo rules=$(grep -c "registry.add(" src/registry/builtin.mbt)
echo modv=$(grep -E "^version" moon.mod)
echo authors=$(git log --all --format=%ae | sort -u | wc -l)