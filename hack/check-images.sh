#!/usr/bin/env bash
# Check the rebuilt images: every binary is built with GO_VERSION, the CA
# bundle has none of the roots distrusted for CVE-2026-111943, and the image
# says it was built on BASE_IMAGE. Checks every platform in PLATFORMS.
#
# Usage: hack/check-images.sh <tag>
set -euo pipefail

TAG="${1:?usage: check-images.sh <tag>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.chart-attributes"
REGISTRY="${REGISTRY:-xpkg.upbound.io/upbound}"
REPOS="kyvernopre kyverno kyverno-cli kyverno-background-controller kyverno-cleanup-controller kyverno-reports-controller kyverno-readiness-checker"
BAD_ROOTS=("emSign ECC Root CA - G3" "AAA Certificate Services")

rc=0
for repo in $REPOS; do
  for platform in ${PLATFORMS//,/ }; do
    ref="$REGISTRY/$repo:$TAG"
    d="$(mktemp -d)"
    crane export --platform "$platform" "$ref" - | tar -x -C "$d" --exclude 'dev/*' 2>/dev/null || true
    gov="$(find "$d/ko-app" -type f 2>/dev/null | while read -r f; do go version "$f" 2>/dev/null; done | awk '{print $NF}' | sort -u | tr '\n' ' ')"
    bundle="$(openssl crl2pkcs7 -nocrl -certfile "$d/etc/ssl/certs/ca-certificates.crt" 2>/dev/null \
      | openssl pkcs7 -print_certs -noout 2>/dev/null | grep -i '^subject' || true)"
    bad=""
    for r in "${BAD_ROOTS[@]}"; do grep -q "$r" <<< "$bundle" && bad+="[$r] "; done
    base="$(crane manifest --platform "$platform" "$ref" | jq -r '.annotations["org.opencontainers.image.base.name"] // ""')"
    chmod -R u+w "$d" 2>/dev/null; rm -rf "$d"

    problems=""
    [ "${gov% }" = "go${GO_VERSION}" ] || problems+=" go=${gov:-none}"
    [ -n "$bundle" ] || problems+=" no-ca-bundle"
    [ -z "$bad" ] || problems+=" bad-roots=${bad% }"
    # ko records the base as <repo>@<digest>, dropping the tag.
    [ "${base##*@}" = "${BASE_IMAGE##*@}" ] || problems+=" base=${base:-unknown}"
    if [ -n "$problems" ]; then
      echo "❌ $ref ($platform):$problems"
      rc=1
    else
      echo "✅ $ref ($platform): go${GO_VERSION}, no distrusted roots, base pinned"
    fi
  done
done
exit $rc
