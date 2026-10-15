#!/usr/bin/env bash
# .claude/skills/verifying-roblox-apis/scripts/scan_deprecated_apis.sh
# Deterministically scans src/ for deprecated Roblox and legacy Lua 5.1 APIs.
# Returns exit 2 if any banned pattern is found so Claude Code self-corrects immediately.
set -u

LUAU_FILES=$(find src -name "*.luau" 2>/dev/null || true)
if [ -z "$LUAU_FILES" ]; then
  exit 0
fi

VIOLATIONS=0

check_pattern() {
  local regex="$1"
  local msg="$2"
  local matches
  matches=$(grep -rnE "$regex" src/ 2>/dev/null | grep -vE "^[^:]+:[0-9]+:[[:space:]]*--" || true)
  if [ -n "$matches" ]; then
    echo "[DEPRECATED API BLOCKED] $msg" >&2
    echo "$matches" >&2
    VIOLATIONS=1
  fi
}

check_pattern '(^|[^a-zA-Z0-9_.])wait[[:space:]]*\(' "Legacy wait() detected. Use task.wait() instead."
check_pattern '(^|[^a-zA-Z0-9_.])spawn[[:space:]]*\(' "Legacy spawn() detected. Use task.spawn() instead."
check_pattern '(^|[^a-zA-Z0-9_.])delay[[:space:]]*\(' "Legacy delay() detected. Use task.delay() instead."
check_pattern '(^|[^a-zA-Z0-9_.])tick[[:space:]]*\(' "Deprecated tick() detected. Use os.clock() or workspace:GetServerTimeNow() instead."
check_pattern 'Instance\.new[[:space:]]*\([[:space:]]*"(BodyVelocity|BodyForce|BodyGyro|BodyPosition|BodyAngularVelocity|RocketPropulsion)"' "Deprecated BodyMover detected. Use LinearVelocity, AlignPosition, AlignOrientation, or CFrame:Lerp."
check_pattern ':(FindPartOnRay|FindPartOnRayWithIgnoreList|FindPartOnRayWithWhitelist|FindPartsInRegion3)[[:space:]]*\(' "Deprecated Raycast/Region3 API detected. Use workspace:Raycast() or workspace:GetPartBoundsInBox()."
check_pattern ':SetPrimaryPartCFrame[[:space:]]*\(' "Deprecated :SetPrimaryPartCFrame() detected. Use model:PivotTo(cframe) instead."
check_pattern '\.(Velocity|RotVelocity)([^a-zA-Z0-9_]|$)' "Deprecated .Velocity/.RotVelocity property detected. Use .AssemblyLinearVelocity or .AssemblyAngularVelocity."
check_pattern 'SetCore[[:space:]]*\([[:space:]]*"ChatMakeSystemMessage"' "Legacy Chat SetCore detected. Use TextChatService.TextChannels.RBXSystem:DisplaySystemMessage() instead."

if [ $VIOLATIONS -ne 0 ]; then
  echo "[ANTI-DEPRECATION GATE REJECTED] Consult .claude/skills/enforcing-luau-standards/references/deprecated_to_modern_matrix.md and replace all deprecated APIs above." >&2
  exit 2
fi

exit 0
