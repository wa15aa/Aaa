#!/bin/bash
# e2e_run.sh — Steady Maestro E2E 套件（带崩溃自发现，2026-09-19 复盘固化）
# 三级结果：PASS / FAILED / CRASHED
#   - CRASHED 判定①：跑前快照 DiagnosticReports，跑完 diff 出新 Steady-*.ips
#   - CRASHED 判定②：每个流程结束后 App 进程存活检查（launchctl list）
# 退出码：有 CRASHED → 2；有 FAILED → 1；全 PASS → 0
set -u
cd "$(dirname "$0")/.."
export PATH="$HOME/.maestro/maestro/bin:$PATH" MAESTRO_CLI_NO_ANALYTICS=1
BUNDLE="sh.steadyhabit.Steady"
REPORTS_DIR="$HOME/Library/Logs/DiagnosticReports"
REPORT=/tmp/e2e_report.txt
: > "$REPORT"

# 哨兵①：跑前快照崩溃报告清单
ls "$REPORTS_DIR"/Steady-*.ips 2>/dev/null | sort > /tmp/e2e_ips_before.txt

crashed_flows=""; failed_flows=""
for f in e2e/*.yaml; do
    name=$(basename "$f" .yaml)
    out=$(maestro test "$f" 2>&1)
    rc=$?
    # 哨兵②：流程后进程存活检查
    sleep 1
    if ! xcrun simctl spawn booted launchctl list 2>/dev/null | grep -q "$BUNDLE"; then
        alive=0
    else
        alive=1
    fi
    if echo "$out" | grep -q "Assertion is false\|Element not found\|FAILED"; then
        if [ "$alive" = "0" ]; then
            crashed_flows="$crashed_flows $name"
            echo "CRASHED $name" >> "$REPORT"
        else
            failed_flows="$failed_flows $name"
            echo "FAILED  $name :: $(echo "$out" | grep -oE '(Assertion is false|Element not found).*' | head -1)" >> "$REPORT"
        fi
    else
        echo "PASS    $name" >> "$REPORT"
    fi
done

# 哨兵①结算：diff 崩溃目录
ls "$REPORTS_DIR"/Steady-*.ips 2>/dev/null | sort > /tmp/e2e_ips_after.txt
new_ips=$(comm -13 /tmp/e2e_ips_before.txt /tmp/e2e_ips_after.txt)

{
    echo "=== Steady E2E 报告 $(date '+%Y-%m-%d %H:%M') ==="
    if [ -n "$new_ips" ]; then
        echo ""
        echo "⛔ CRASH 检出（上架红线）："
        for ips in $new_ips; do
            echo "--- $ips"
            python3 - "$ips" <<'PYEOF'
import json, sys
raw = open(sys.argv[1]).read().split('\n', 1)
try:
    body = json.loads(raw[1])
    print("Exception:", body.get('exception'))
    ct = body['faultingThread']
    imgs = body['usedImages']
    for fr in body['threads'][ct]['frames'][:10]:
        print(" ", imgs[fr['imageIndex']].get('name'), fr.get('symbol', hex(fr.get('imageOffset', 0))))
except Exception as e:
    print("(ips 解析失败:", e, ")")
PYEOF
        done
    fi
    echo ""
    sort -t' ' -k1,1 "$REPORT" | grep -E "^CRASHED" || true
    grep -E "^(FAILED|PASS)" "$REPORT"
} | tee /tmp/e2e_report_full.txt

n_crash=$(grep -c "^CRASHED" "$REPORT" || true)
n_fail=$(grep -c "^FAILED" "$REPORT" || true)
n_pass=$(grep -c "^PASS" "$REPORT" || true)
echo ""
echo "汇总: PASS=$n_pass FAILED=$n_fail CRASHED=$n_crash（含新 ips: $(echo $new_ips | wc -w | tr -d ' ')）"

if [ -n "$new_ips" ] || [ "$n_crash" -gt 0 ]; then exit 2; fi
if [ "$n_fail" -gt 0 ]; then exit 1; fi
exit 0
