import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import file

version = file.read_env("UP_CHART_VERSION")
_items = [
    metav1alpha1.E2ETest{
        metadata.name: "controller-kyverno"
        spec= {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Installed", "Healthy"]
            manifests: [
                {
                    apiVersion: "pkg.upbound.io/v1alpha1"
                    kind: "Controller"
                    metadata: {
                        name: "pkg-controller-kyverno"
                    }
                    spec: {
                        package: "xpkg.upbound.io/upbound/controller-kyverno:"+ version
                    }
                }
            ]
            extraResources: []
            skipDelete: False
            timeoutSeconds: 4500
        }
    }
]
items= _items
