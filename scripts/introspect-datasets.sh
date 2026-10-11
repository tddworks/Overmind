#!/usr/bin/env bash
# Lists Cloudflare GraphQL account datasets whose name matches a pattern, with the fields of
# their sum / max / quantiles / dimensions — names only, never a token, an id or a number.
# The token comes from the Keychain item the app keeps (CANONICAL law 15).
#
#   scripts/introspect-datasets.sh 'ai|vectorize|durableObjects'
set -euo pipefail
pattern="${1:?usage: introspect-datasets.sh <regex over dataset names>}"
token="$(security find-generic-password -s com.tddworks.overmind -a cloudflare-api-token -w)"

ask() {
  curl -sS https://api.cloudflare.com/client/v4/graphql \
    -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' \
    --data "$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1]}))' "$1")"
}

type_of='fields { name type { name kind ofType { name kind ofType { name ofType { name } } } } }'
account="$(ask "{ __type(name: \"account\") { ${type_of} } }")"

python3 -I - "$pattern" "$account" <<'EOF' > /tmp/overmind-datasets.$$
import json, re, sys
pattern, answer = sys.argv[1], json.loads(sys.argv[2])
if not answer.get("data") or not answer["data"].get("__type"):
    sys.exit("Cloudflare said: " + "; ".join(e.get("message", "?") for e in answer.get("errors") or []) or "no schema")
def name(t):
    while t and not t.get("name"): t = t.get("ofType")
    return t and t["name"]
for f in answer["data"]["__type"]["fields"]:
    if re.search(pattern, f["name"], re.I):
        print(f["name"], name(f["type"]))
EOF

while read -r dataset group; do
  echo "== ${dataset}"
  fields="$(ask "{ __type(name: \"${group}\") { ${type_of} } }")"
  python3 -I - "$fields" <<'EOF' | while read -r part sub; do
import json, sys
def name(t):
    while t and not t.get("name"): t = t.get("ofType")
    return t and t["name"]
for f in json.loads(sys.argv[1])["data"]["__type"]["fields"]:
    print(f["name"], name(f["type"]) or "-")
EOF
    case "$part" in
      sum|max|avg|quantiles|dimensions|count)
        inner="$(ask "{ __type(name: \"${sub}\") { fields { name } } }")"
        echo "  ${part}: $(python3 -I -c 'import json,sys; print(" ".join(f["name"] for f in json.loads(sys.argv[1])["data"]["__type"]["fields"] or []))' "$inner")" ;;
    esac
  done
done < /tmp/overmind-datasets.$$
rm -f /tmp/overmind-datasets.$$
