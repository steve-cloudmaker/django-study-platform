#!/usr/bin/env bash
# Smoke test Study/Submission API. Requires API image built from current backend/
# and migrations applied. Set BASE_URL to your ingress (default: production API host).
set -euo pipefail
BASE_URL="${BASE_URL:-https://api.charliesystems.ai}"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "== Health (expect 200) =="
curl -fsS -o /dev/null -w "GET ${BASE_URL}/healthz/ -> %{http_code}\n" "${BASE_URL}/healthz/"

echo "== API routes present? (GET /api/studies/ expect 200 JSON list) =="
code=$(curl -sS -o "$TMPDIR/list.json" -w '%{http_code}' "${BASE_URL}/api/studies/?limit=1" || true)
if [[ "$code" != "200" ]]; then
  echo "GET /api/studies/ returned HTTP $code (body head):"
  head -c 300 "$TMPDIR/list.json" 2>/dev/null || true
  echo ""
  echo "Deploy a fresh study-platform-api image from this repo's backend/, run migrate, then retry."
  exit 1
fi

echo "== Create study =="
code=$(curl -sS -o "$TMPDIR/study.json" -w '%{http_code}' -X POST "${BASE_URL}/api/studies/" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Smoke Test Study"}')
echo "HTTP $code"
if [[ "$code" != "201" ]]; then
  cat "$TMPDIR/study.json"; echo; exit 1
fi
STUDY_ID=$(python3 -c "import json; print(json.load(open('$TMPDIR/study.json'))['id'])")
echo "study_id=$STUDY_ID"

echo "== List studies by name =="
curl -fsS "${BASE_URL}/api/studies/?name=Smoke%20Test%20Study&limit=5" | python3 -m json.tool | head -20

echo "== Create submission (expect 202) =="
code=$(curl -sS -o "$TMPDIR/sub.json" -w '%{http_code}' -X POST "${BASE_URL}/api/studies/${STUDY_ID}/submissions/" \
  -H 'Content-Type: application/json' \
  -d '{"content":"hello from smoke"}')
echo "HTTP $code"
if [[ "$code" != "202" ]]; then
  cat "$TMPDIR/sub.json"; echo; exit 1
fi
python3 -m json.tool <"$TMPDIR/sub.json"
SUBMISSION_ID=$(python3 -c "import json; print(json.load(open('$TMPDIR/sub.json'))['submission_id'])")

echo "== Get submission =="
curl -fsS "${BASE_URL}/api/studies/${STUDY_ID}/submissions/${SUBMISSION_ID}/" | python3 -m json.tool

echo "OK smoke test finished."
