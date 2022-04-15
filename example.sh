# Configure cluster tooling (rbac and kpack)

# Apply Acccess Control
kapp deploy --yes -a example-rbac -f <(ytt --ignore-unknown-comments -f example/cluster/ -f example-values.yaml)

# Create a stack, store and builder
kp clusterstack save base --build-image paketobuildpacks/build:base-cnb --run-image paketobuildpacks/run:base-cnb
kp clusterstore save default -b gcr.io/paketo-buildpacks/java -b gcr.io/paketo-buildpacks/go
kp clusterbuilder save builder --tag harbor.tanzu.coraiberkleid.site/demo/builder --stack base --store default --order cfg/kpack-builder-order.yaml

# Install Cartographer templates and supply chain
kapp deploy --yes -a example -f <(ytt --ignore-unknown-comments -f example/app-operator/ -f example-values.yaml)

# Apply workload
kubectl apply -f example/developer/workload.yaml

# Watch status, wait for it to be Ready then hit Ctrl+C
watch kubectl tree workload hello-tanzu

# Get all - click on URL to test app
kubectl get all

