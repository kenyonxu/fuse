#!/usr/bin/env bash
# deep_tests 四查流水线——headless 运行日志的统一验收口径
# 用法: ./check_log.sh <log> [期望唯一PASS数]
# 四查（M3 起标准，源自 OnOverlappingBodies 信号参数类型错误的盲区教训）:
#   1. SCRIPT ERROR / push_error 计数 = 0
#   2. FAIL: 计数 = 0
#   3. PASS 唯一标记数达标（Fuse INFO 日志回显带 ANSI 色码会双计，须 sort -u 去重）
#   4. "Error calling from signal" 计数 = 0（Godot 信号参数类型不匹配不走 push_error 通道）
set -u
LOG="${1:?用法: check_log.sh <log> [期望唯一PASS数]}"
EXPECT="${2:-}"

err=$(grep -cE 'SCRIPT ERROR|push_error' "$LOG")
fail=$(grep -c 'FAIL:' "$LOG")
sig=$(grep -c 'Error calling from signal' "$LOG")
pass=$(grep -o 'PASS[^<]*' "$LOG" | sort -u | wc -l)

echo "log      : $LOG"
echo "errors   : $err (期望 0)"
echo "fails    : $fail (期望 0)"
echo "signal_err: $sig (期望 0)"
echo "pass_uniq: $pass${EXPECT:+ (期望 >= $EXPECT)}"

ok=1
[ "$err" -ne 0 ] && ok=0
[ "$fail" -ne 0 ] && ok=0
[ "$sig" -ne 0 ] && ok=0
if [ -n "$EXPECT" ] && [ "$pass" -lt "$EXPECT" ]; then ok=0; fi

if [ "$ok" -eq 1 ]; then
  echo "RESULT   : PASS"
else
  echo "RESULT   : FAIL"
fi
exit $((1 - ok))
