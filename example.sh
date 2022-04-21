##### CHECK FOR ENV VARS
if [[ -z ${REGISTRY_URL} || -z ${REGISTRY_USERNAME} || -z ${REGISTRY_PASSWORD} || -z ${IMAGE_PREFIX} ]]; then
  echo "The following environment variables must be set:"
  echo "     REGISTRY_URL, REGISTRY_USERNAME, REGISTRY_PASSWORD, IMAGE_PREFIX"
  exit 1
fi

##### CLUSTER OPERATOR PERSPECTIVE
# Log in to docker locally
echo $REGISTRY_PASSWORD | docker login -u ${REGISTRY_USERNAME} --password-stdin ${REGISTRY_URL}

# kpack configuration: create a stack, store and builder for kpack
kp clusterstack save base \
    --build-image paketobuildpacks/build:base-cnb \
    --run-image paketobuildpacks/run:base-cnb

kp clusterstore save default \
    -b gcr.io/paketo-buildpacks/java \
    -b gcr.io/paketo-buildpacks/go

kp clusterbuilder save builder \
    --tag ${IMAGE_PREFIX}builder \
    --stack base \
    --store default \
    --order example/kpack-builder-order.yaml

###### APP OPERATOR PERSPECTIVE
envsubst < values-example-template.yaml > values-example.yaml

# Cartographer access control configuration:
kapp deploy --yes -a example-rbac \
    -f <(ytt --ignore-unknown-comments -f example/cluster/ -f values-example.yaml)

# Create templates and supply chain
kapp deploy --yes -a example-sc \
    -f <(ytt --ignore-unknown-comments -f example/app-operator/ -f values-example.yaml)

###### DEVELOPER PERSPECTIVE
# Apply workload
kubectl apply -f example/developer/workload.yaml

# Check the status
# Note: "waiting to read value [.status.latestImage] from resource [image.kpack.io/hello-tanzu]"
# means kpack has not finished building the image
kubectl get workload hello-tanzu -o yaml

# You can check on how the build is going
kp build logs hello-tanzu

# Or, you can watch status, wait for "Unknown  MissingValueAtPath" to
# become "True   Ready", then hit Ctrl+C
watch kubectl tree workload hello-tanzu

# Get all - click on URL to test app
kubectl get all

# Make sure app is working:
http://hello-tanzu.kpack.127-0-0-1.sslip.io
