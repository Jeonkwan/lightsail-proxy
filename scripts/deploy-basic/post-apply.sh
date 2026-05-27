#!/usr/bin/env bash
set -euo pipefail
set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

TF_ROOT="${TF_ROOT:-${ROOT_DIR}}"
TF_PLAN_DIR="${TF_PLAN_DIR:-${ROOT_DIR}/artifacts/terraform}"
SUMMARY_FILE="${SUMMARY_FILE:-${TF_PLAN_DIR}/summary.md}"
OUTPUT_JSON="${OUTPUT_JSON:-${TF_PLAN_DIR}/outputs.json}"
export SUMMARY_FILE OUTPUT_JSON

mkdir -p "${TF_PLAN_DIR}"

pushd "${TF_ROOT}" >/dev/null

if ! terraform output -json > "${OUTPUT_JSON}"; then
  echo "{}" > "${OUTPUT_JSON}"
fi

popd >/dev/null

python3 - <<'PY'
import json
import os

summary_file = os.environ.get("SUMMARY_FILE")
output_json = os.environ.get("OUTPUT_JSON")

with open(output_json, "r", encoding="utf-8") as fh:
    try:
        outputs = json.load(fh)
        if not isinstance(outputs, dict):
            outputs = {}
    except json.JSONDecodeError:
        outputs = {}

lines = ["## Terraform Outputs", "", "| Name | Value |", "| --- | --- |"]
if outputs:
    for name in sorted(outputs):
        payload = outputs.get(name, {})
        if isinstance(payload, dict):
            value = payload.get("value")
        else:
            value = payload
        lines.append(f"| {name} | `{value}` |")
else:
    lines.append("| _No outputs_ |  |")

with open(summary_file, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
PY

echo "Wrote Terraform output summary to ${SUMMARY_FILE}"
