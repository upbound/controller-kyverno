#!/bin/sh
set -eo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <chart-version> <chart-url>"
  exit 1
fi

CHART_VERSION="$1"
REPO_URL="$2"
CHART="kyverno/kyverno"

helm repo add kyverno $REPO_URL

if ! helm images --help >/dev/null 2>&1; then
  echo "helm-images plugin is not installed."
  echo "Install it with: helm plugin install https://github.com/nikhilsbhat/helm-images"
  exit 1
fi

if ! command -v crane >/dev/null 2>&1; then
  echo "crane is not installed."
  exit 1
fi

MAPPINGS="bitnami/kubectl xpkg.upbound.io/upbound/kyverno-kubectl
reg.kyverno.io/kyverno/background-controller xpkg.upbound.io/upbound/kyverno-background-controller
reg.kyverno.io/kyverno/cleanup-controller xpkg.upbound.io/upbound/kyverno-cleanup-controller
reg.kyverno.io/kyverno/kyverno-cli xpkg.upbound.io/upbound/kyverno-cli
reg.kyverno.io/kyverno/kyverno xpkg.upbound.io/upbound/kyverno
reg.kyverno.io/kyverno/kyvernopre xpkg.upbound.io/upbound/kyvernopre
reg.kyverno.io/kyverno/reports-controller xpkg.upbound.io/upbound/kyverno-reports-controller
"

# Get image list from Helm chart
images=$(helm images get "$CHART" --version="$CHART_VERSION" --skip-tests | sort | uniq)

echo "$images" | while read -r image; do
  [ -z "$image" ] && continue

  repo_and_name=$(echo "$image" | sed 's/:.*$//')
  tag=$(echo "$image" | sed 's/^.*://')

  source_image="$image"
  lookup_key="$repo_and_name"

  dest_repo=$(echo "$MAPPINGS" | awk -v key="$lookup_key" '$1 == key { print $2 }')

  if [ -z "$dest_repo" ]; then
    echo "⚠️  No mapping for $lookup_key, skipping..."
    continue
  fi

  dest_image="${dest_repo}:${tag}"
  echo "📦 Copying $source_image -> $dest_image"
  crane copy "$source_image" "$dest_image"
done