# controller-kyverno

This repository provides a controller that enables declarative installation of
Kyverno within an Upbound control plane.

## Overview

Kyverno is a cloud native policy engine.

## Usage

### Prerequisites

- Upbound account with appropriate permissions
- kubectl CLI installed and configured
- Upbound CLI (`up`) installed

### Installation

1. Create a control plane in Upbound

```bash
UPBOUND_ORG="your_upbound_org"
# Other spaces are available, check with `up ctx`
# you need a space with enabled controller feature
UPBOUND_SPACE="space-the-final-frontier"
UPBOUND_GROUP="your_group_name"
UPBOUND_CTP="your_controlplane_name"

# Create Profile
up profile create $UPBOUND_ORG --organization $UPBOUND_ORG
up profile use $UPBOUND_ORG

# Login and switch context
up login -a $UPBOUND_ORG --profile $UPBOUND_ORG
up ctx "${UPBOUND_ORG}/${UPBOUND_SPACE}"

# Create group
up group create "${UPBOUND_GROUP}"

# Switch context to group
up ctx "${UPBOUND_ORG}/${UPBOUND_SPACE}/${UPBOUND_GROUP}"

# Create control plane
up ctp create "${UPBOUND_CTP}" --crossplane-channel="Rapid"

# Check status of control plane (should show Healthy: True)
up ctp list

# Switch context to control plane (might take a minute to become ready)
up ctx "${UPBOUND_ORG}/${UPBOUND_SPACE}/${UPBOUND_GROUP}/${UPBOUND_CTP}"
```

2. Install Kyverno:

   This repository publishes two package flavors built from the same Helm chart.
   Pick the one that matches where your control plane runs:

   | Host | Kind | Package |
   |------|------|---------|
   | Upbound Spaces | `Controller` | `xpkg.upbound.io/upbound/controller-kyverno` |
   | Upbound Crossplane (UXP) v2 | `AddOn` | `xpkg.upbound.io/upbound/addon-kyverno` |

   `AddOn` requires UXP v2. On Spaces control planes, use the `Controller`
   package instead.

   **Spaces (`Controller`)**

```bash
UP_CHART_VERSION="3.9.0"

cat <<EOF | kubectl apply -f -
apiVersion: pkg.upbound.io/v1alpha1
kind: Controller
metadata:
  name: controller-kyverno
spec:
  package: xpkg.upbound.io/upbound/controller-kyverno:${UP_CHART_VERSION}
EOF
```

   **UXP v2 (`AddOn`)**

```bash
UP_CHART_VERSION="3.9.0"

cat <<EOF | kubectl apply -f -
apiVersion: pkg.upbound.io/v1beta1
kind: AddOn
metadata:
  name: addon-kyverno
spec:
  package: xpkg.upbound.io/upbound/addon-kyverno:${UP_CHART_VERSION}
EOF
```

## Development

### Testing

The repository includes test configurations:

- Basic e2e test: `tests/e2etest-kyverno`

To run tests:

```bash
UP_CHART_VERSION="" up test run tests/* --e2e
```
