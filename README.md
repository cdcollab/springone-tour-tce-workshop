# springone-tour-tce-workshop

## Overview
This workshop walks you through:
1. Installing prerequisites
2. Creating a local cluster on Docker using Tanzu Community Edition
3. Installing Application Toolkit on the cluster
4. Running an example software supply chain using Cartographer to move a developer workload from source to deployment.
  The chain uses:
   1. Fluxcd - to poll for new source code commits 
   2. kpack - to build and publish container images
   3. Harbor - to store and scan container images
   4. Knative Serving - to run the application 

## Prerequisites

- `docker` must be installed
- `carvel` must be installed
  - `ytt`, `vendir`, `kapp`
- `krew`
- `kubectl tree` plugin


## Setup

Clone the repo to your VM:
```shell
git clone https://github.com/cdcollab/springone-tour-tce-workshop
```

2. The instructor will provide you with credentials (username and password) for Harbor container registry.
Make sure you can log into Harbor at [https://harbor.tanzu.coraiberkleid.site](https://harbor.tanzu.coraiberkleid.site) using these credentials.


3. Set the following environment variables.
Note that you need to replace "your-username" and "your-password" in the code blocks below using your assigned Harbor credentials before running the commands.

```shell
# For installation of Application Toolkit
export KP_REPO=harbor.tanzu.coraiberkleid.site/your-username/kp
export KP_USERNAME=your-username
export KP_PASSWORD=your-password

# For the example supply chain:
export REGISTRY_URL=https://harbor.tanzu.coraiberkleid.site
export REGISTRY_USERNAME=your-username
export REGISTRY_PASSWORD=your-password
export IMAGE_PREFIX=harbor.tanzu.coraiberkleid.site/your-username/
```


```shell
# vendir workshop assets
./download-dependencies.sh
# install tce
./vendir/tce-linux-amd64-v0.11.0/install.sh
# verify version v0.11.2
tanzu version
# Install apps plugin :: https://github.com/vmware-tanzu/apps-cli-plugin#getting-started
tanzu plugin install apps --local ./vendir --version v0.6.0
# Create unmanaged cluster for workshop 6GB ram, 4cpu, 15gb disk
tanzu uc create spring-one-tour -p 80:80 -p 443:443
```


You can look through the output to get a better sense for the components included in the cluster, namely:
- Package repositories, for simple installation of a curated set of Kubernetes OSS tooling
- kapp-controller, for package lifecycle management
- Calico Container Network Interface (CNI) for container and pod networking

```shell
# When the cluster has been created, you can list the package repositories in all namespaces.
# Verify cni has completed install (Status Reconcile succeeded)
tanzu package installed list -A
```

You can also list the available packages in the `tanzu-package-repo-global` namespace (no need to specify this namespace).
```shell
tanzu package available list
```

## Install Application Toolkit

Application Toolkit is a meta-package that contains 6 packages:

| Name | Package                                             |
|--------------|-----------------------------------------------------|
| Cartographer | cartographer.community.tanzu.vmware.com             |
|cert-manager| cert-manager.community.tanzu.vmware.com             |
|Contour| contour.community.tanzu.vmware.com                  |
|Flux CD Source Controller| fluxcd-source-controller.community.tanzu.vmware.com |
|Knative Serving| knative-serving.community.tanzu.vmware.com          |
|kpack| kpack.community.tanzu.vmware.com                    |

Three of these packages require configuration.
You can see the configuration here: [values-install-template.yaml](./values-install-template.yaml).

Notice that the configuration file contains some of the environment variables you set earlier.
Run the following command to create a final values file with the proper values in place of the variables:
```shell
envsubst < values-install-template.yaml > values-install.yaml
```

Make sure the new [values-install.yaml](./values-install.yaml) contains the proper replacement values.

Then, install Application Toolkit.
```shell
tanzu package install app-toolkit --package-name app-toolkit.community.tanzu.vmware.com --version 0.1.0 -f values-install.yaml -n tanzu-package-repo-global
```

When the installation is complete, verify that all packages were installed and that their status is "Reconcile succeeded."
```shell
tanzu package installed list -n tanzu-package-repo-global
```

## Example application deployment workflow

In this section, you will create a basic workflow to move an application from source code to deployment, as follows:

_get source (fluxcd) --> build image (kpack) --> run (knative serving)_

You will automate the workflow using Cartographer to create a software _supply chain_.


### Operator perspective, part 1: configure kpack builder

kpack needs a _builder_ in order to turn application source code into OCI images.
A builder is an image, compliant with [Cloud Native Buildpacks](buildpacks.io), that provides the base OS images necessary to build and run the application (the "stack"), as well as buildpacks to handle application compilation, dependencies, and other language-specific details (the "store").

You can create the stack, store, and builder using `kubectl` and YAML configuration, but in this example, we will use `kp`, the kpack CLI.

1. Log in to Harbor using the `docker `CLI so that `kp` has access to Harbor credentials.
```shell
echo $REGISTRY_PASSWORD | docker login -u ${REGISTRY_USERNAME} --password-stdin ${REGISTRY_URL}
```

2. Create the ClusterStack.
```shell
kp clusterstack save base --build-image paketobuildpacks/build:base-cnb --run-image paketobuildpacks/run:base-cnb
```

3. Create the ClusterStore.
```shell
kp clusterstore save default -b gcr.io/paketo-buildpacks/java -b gcr.io/paketo-buildpacks/go
```

4. Create a ClusterBuilder.
Notice that it uses a configuration file, [kpack-builder-order.yaml](example/kpack-builder-order.yaml), to set the order in which buildpacks will evaluate the application code.
```shell
kp clusterbuilder save builder --tag ${IMAGE_PREFIX}builder --stack base --store default --order example/kpack-builder-order.yaml
```

Check the [Harbor UI](https://harbor.tanzu.coraiberkleid.site).
You will see 4 images under the path `your-username/kp`—these correspond to the build image and the run image in the stack, as well as the go and java buildpacks in the store.
You will also see the builder image under the path `your-username/builder`.
This builder includes the stack and store, and it is the image that kpack will use to build images from application source code.

## Operator perspective, part 2: configure Cartographer RBAC

The supply chain will require read/write access to Harbor and to various cluster resources needed to process the workflow.
Hence, you need to create proper role-based access control (RBAC) resources first.
Take a look at the RBAC configuration provided in the example: [./example/cluster](./example/cluster).
In this example, the default service account will be granted permission to create the necessary cluster resources, and a separate service account will be used to protect Harbor credentials separately.

Run the following command to apply the RBAC configuration to the cluster.
```shell
envsubst < values-example-template.yaml > values-example.yaml
kapp deploy --yes -a example-rbac -f <(ytt --ignore-unknown-comments -f example/cluster/ -f values-example.yaml)
```

## Operator perspective, part 3: create Cartographer templates and supply chain

Cartographer will automate the flow of applications from source code to deployment using Cartographer-specific resources.
In this example, you will use:
- **ClusterSupplyChain** - to define the sequence of the flow from FluxCD to kpack to Knative Serving, and to map output of one resource as input to the next
- **Templates (ClusterSourceTemplate, ClusterImageTemplate, and ClusterTemplate)** - to give Cartographer the ability to instantiate and monitor FluxCD, kpack, and Knative Serving resources for each application submitted to the supply chain

Review the templates and the supply chain defined in [./example/app-operator](./example/app-operator).
Notice that:
- Each template contains a parameterized configuration for one of the resources in the example workflow (FluxCD GitRepository, kpack Image, and Knative Serving Service).
- The parameterized values will be injected from a "workload"—this refers to the resource the developer will submit with application-specific details
- Templates differ based on the outputs they produce:
  - ClusterSourceTemplate produces a url and revision
  - ClusterImageTemplate produces an image (tag)
  - ClusterTemplate does not produce any output
- The template configuration does not set the output value; rather, it sets the path to the output value in the corresponding resource's status (e.g. urlPath, not url).
  Cartographer will take care of retrieving this value and assigning it to the output field.
- The ClusterSupplyChain defines the order of the resources and maps the ouput of one as input to the next.
- The templates (specifically ClusterSourceTemplate for the kpack Image and ClusterTemplate for Knative Serving Service) assign specific output values to keys in the resource configuration.

Run the following command to apply the template and supply chain configurations to the cluster.
```shell
kapp deploy --yes -a example-sc -f <(ytt --ignore-unknown-comments -f example/app-operator/ -f values-example.yaml)
```

## Developer perspective: create workload

With the supply chain fully configured in the cluster, developers can begin to deploy applications using the Cartographer Workload resource. Workloads help provide a clean separation of concerns beteen developers and application operators and focus on isolating the information unique to a developer workload.

You can create Workloads imperatively using the `tanzu` CLI, or declaraitvely using `kubectl` and YAML configuration.
In this example, you will use the imperative approach.
Run the following command to create a Workload.
Notice that the "type" (web) matches the selector value in the ClusterSupplyChain.
```shell
tanzu apps workload create hello-chicago --type web --git-repo https://github.com/ciberkleid/hello-go.git --git-branch main --app hello-chicago --env "HELLO_MSG=crew" --yes
```

> Note:
> The supply chain will likely take a few minutes to deploy the application the first time, as kpack needs to download dependencies to build and publish the image.
> Subsequent runs will leverage cached dependencies and other optimizations to build the image more quickly.

Track the progress of the supply chain workflow.
```shell
tanzu apps workload get hello-chicago        # Alt: kubectl get workload hello-chicago -o yaml | yq
```

If the build is still running, you can optionally use the kpack CLI, `kp`, to check the progress of the build.
```shell
kp build logs hello-chicago        # Also: tanzu apps workload tail hello-chicago
```

You can use the `kubectl tree` plugin to see the dependent resources spawned for the Workload.
You should see an App, Image, and GitRepository. The latter two will each have dependent resources as well.
```shell
kubectl tree workload hello-chicago
```

If the Workload status is "Ready," you can check on the Knative Serving Service resource.
```shell
kubectl get kservice hello-chicago
```

Click on the route to make sure the application is working:
```shell
open http://hello-chicago.default.127-0-0-1.sslip.io
```

To learn more about the resource Knative Serving creates automatically, run `kubectl get all` or use the `kubectl tree` plugin as follows.
Knative Serving provides additional functionality (e.g. auto-scaling, ingress configuration and routing, revision management) over and above a simple Deployment and Service, without requiring complex configuration.
```shell
kubectl tree kservice hello-chicago
```

## Conclusion

Congratulations! You have installed a Kubernetes cluster with elevated developer-centric platform capabilities and deployed a path to production for a variety of applications!

To learn more, visit the following resources:
- [Tanzu Community Edition](https://tanzucommunityedition.io)
- [Application Toolkit](https://tanzucommunityedition.io/docs/v0.11/package-readme-app-toolkit-0.1.0)
- [Cartographer](https://cartographer.sh)
- [Cartographer examples](https://github.com/vmware-tanzu/cartographer/tree/main/examples)
- [FluxCD Source Controller](https://fluxcd.io/docs/components/source)
- [Cloud Native Buildpacks](https://buildpacks.io)
- [kpack](https://github.com/pivotal/kpack)
- [Knative Serving](https://knative.dev/docs/serving)

## Cleanup

To delete the cluster, run:
```shell
tanzu unmanaged-cluster delete tce-local
```
