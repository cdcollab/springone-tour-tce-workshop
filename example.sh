##### CLUSTER OPERATOR PERSPECTIVE
if [[ -z ${REGISTRY_URL} || -z ${REGISTRY_USERNAME} || -z ${REGISTRY_PASSWORD} || ${IMAGE_PREFIX} ]]; then
  echo "The following environment variables must be set:"
  echo "     REGISTRY_URL, REGISTRY_USERNAME, REGISTRY_PASSWORD, IMAGE_PREFIX"
  exit 1
fi

##### CLUSTER OPERATOR PERSPECTIVE
# Log in to docker locally
echo $REGISTRY_PASSWORD | docker login -u ${REGISTRY_USERNAME} --password-stdin ${REGISTRY_URL}

# kpack configuration: create a stack, store and builder for kpack
kp clusterstack save base --build-image paketobuildpacks/build:base-cnb --run-image paketobuildpacks/run:base-cnb
kp clusterstore save default -b gcr.io/paketo-buildpacks/java -b gcr.io/paketo-buildpacks/go
kp clusterbuilder save builder --tag ${IMAGE_PREFIX}builder --stack base --store default --order example/cluster/kpack-builder-order.yaml

##### APP OPERATOR PERSPECTIVE
# Cartographer configuration:
# Apply Acccess Control
kapp deploy --yes -a example-rbac -f <(ytt --ignore-unknown-comments -f example/cluster/ -f example-values.yaml)
# Create templates and supply chain
kapp deploy --yes -a example -f <(ytt --ignore-unknown-comments -f example/app-operator/ -f example-values.yaml)


##### DEVELOPER PERSPECTIVE
# Apply workload
kubectl apply -f example/developer/workload.yaml

# Watch status, wait for it to be Ready then hit Ctrl+C
watch kubectl tree workload hello-tanzu

# Get all - click on URL to test app
kubectl get all

