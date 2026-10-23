#!/usr/bin/env bash
set -euo pipefail

report_dir="$PWD/out/device-tests"
mkdir -p "$report_dir"
trap 'adb logcat -d > "$report_dir/logcat.txt" 2>&1 || true' EXIT

abis=$(adb shell getprop ro.product.cpu.abilist | tr -d '\r')
printf 'Emulator ABIs: %s\n' "$abis" | tee "$report_dir/emulator.txt"
adb shell getprop ro.dalvik.vm.native.bridge >> "$report_dir/emulator.txt"
case ",$abis," in
  *,arm64-v8a,*) ;;
  *) echo 'The emulator does not advertise ARM64 support.' >&2; exit 1 ;;
esac

cd worktree
./gradlew --no-daemon :TMessagesProj:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=desu.inugram.helpers.plugins.PluginReposTest

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET

reports = Path('TMessagesProj/build/outputs/androidTest-results/connected')
cases = [case for path in reports.rglob('*.xml')
         for case in ET.parse(path).getroot().iter('testcase')]
assert len(cases) == 7, f'Expected seven executed tests, found {len(cases)}'
for case in cases:
    assert case.get('classname') == 'desu.inugram.helpers.plugins.PluginReposTest'
    assert not any(case.find(tag) is not None for tag in ('failure', 'error', 'skipped'))
print('Verified: all seven repository regression tests executed and passed.')
PY
