#!/usr/bin/env bash
# Build Kyverno's images from the upstream release tag in .chart-attributes,
# source unchanged, with GO_VERSION on BASE_IMAGE, and push them to the Upbound
# mirror. Build flags follow upstream's `make ko-publish-all` for that tag.
#
# Usage: hack/build-images.sh <tag>
#   REGISTRY (default xpkg.upbound.io/upbound) is the target repository prefix.
#   A tag that already exists is skipped, never overwritten.
set -euo pipefail

TAG="${1:?usage: build-images.sh <tag>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/.chart-attributes"
REGISTRY="${REGISTRY:-xpkg.upbound.io/upbound}"

# <cmd dir in kyverno/kyverno> <repository under REGISTRY>
IMAGES="kyverno-init kyvernopre
kyverno kyverno
cli/kubectl-kyverno kyverno-cli
background-controller kyverno-background-controller
cleanup-controller kyverno-cleanup-controller
reports-controller kyverno-reports-controller
readiness-checker kyverno-readiness-checker"

export GOTOOLCHAIN=local CGO_ENABLED=0
if [ "$(go env GOVERSION)" != "go${GO_VERSION}" ]; then
  echo "Go is $(go env GOVERSION), expected go${GO_VERSION}" >&2
  exit 1
fi
GOBIN_DIR="$(go env GOPATH)/bin"
export PATH="$GOBIN_DIR:$PATH"
command -v ko >/dev/null || go install "github.com/google/ko@${KO_VERSION}"

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
git clone --quiet --depth 1 --branch "$KYVERNO_REF" https://github.com/kyverno/kyverno.git "$SRC"
head="$(git -C "$SRC" rev-parse HEAD)"
if [ "$head" != "$KYVERNO_COMMIT" ]; then
  echo "$KYVERNO_REF is $head, expected $KYVERNO_COMMIT" >&2
  exit 1
fi

cd "$SRC"
while read -r dir repo; do
  ref="$REGISTRY/$repo:$TAG"
  if crane manifest "$ref" >/dev/null 2>&1; then
    echo "⏭️  $ref exists, not overwriting"
    continue
  fi
  echo "📦 Building ./cmd/$dir -> $ref"
  LD_FLAGS="-s -w -X github.com/kyverno/kyverno/pkg/version.BuildVersion=${KYVERNO_REF}" \
  KO_DEFAULTBASEIMAGE="$BASE_IMAGE" \
  KO_DOCKER_REPO="$REGISTRY/$repo" \
    ko build "./cmd/$dir" --bare --tags="$TAG" --platform="$PLATFORMS" \
      --image-annotation "org.opencontainers.image.source=github.com/kyverno/kyverno/commit/${KYVERNO_COMMIT}" \
      --image-annotation "org.opencontainers.image.version=${TAG}" \
      --image-annotation "org.opencontainers.image.vendor=Upbound" \
      --image-annotation "org.opencontainers.image.description=Kyverno ${KYVERNO_REF} rebuilt with Go ${GO_VERSION} on ${BASE_IMAGE}"
done <<< "$IMAGES"
