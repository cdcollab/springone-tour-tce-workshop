# springone-tour-tce-workshop

## Overview
This workshop walks you through:
1. Installing prerequisites
2. Creating a local cluster on Docker using Tanzu Community Edition
3. Installing Application Toolkit on the cluster
4. Running an example Software Supply Chain using Cartographer to move a developer workload from source to deployment. The chain uses:
   1. Fluxcd - to poll for new source code commits 
   2. kpack - to build and publish container images
   3. Harbor - to store and scan container images
   4. Knative Serving - to run the application 

## Pre-requisites

- Docker
- vendir

OR

- Docker
- kubectl
- ytt
- tanzu
- kp

## Setup

1. Clone the sample repository and `cd` into the parent directory. The rest of the instructions assume you are running commands from this directory.
```shell
git clone https://github.com/cdcollab/springone-tour-tce-workshop.git
cd springone-tour-tce-workshop
```

2. The instructor will provide you with credentials (username and password) for Harbor container registry. Make sure you can log into Harbor at [https://harbor.tanzu.coraiberkleid.site](https://harbor.tanzu.coraiberkleid.site) using these credentials.


3. Set the following environment variables. Note that you need to replace "your-username" and "your-password" in the code blocks below using your assigned Harbor credentials before running the commands.
```shell
# For installation of Application Toolkit
export KP_REPO=harbor.tanzu.coraiberkleid.site/your-username/kp
export KP_USERNAME=your-username
export KP_PASSWORD=your-password

# For the example Supply Chain:
export REGISTRY_URL=https://harbor.tanzu.coraiberkleid.site
export REGISTRY_USERNAME=your-username
export REGISTRY_PASSWORD=your-password
export IMAGE_PREFIX=harbor.tanzu.coraiberkleid.site/your-username/
```

## Install Tanzu Community Edition CLI

1. Run the following command to install the `tanzu` CLI.
```shell
brew install vmware-tanzu/tanzu/tanzu-community-edition
```

2. To initialize default `tanzu` CLI plugins, run the command that appears in the output of the CLI installation from the previous step (look inside the box formed by asterisks). The command should look something like this:
```shell
{INSTALL-LOCATION}/configure-tce.sh
```

3. To install the additional `apps` plugin, run the following commands.
```shell
wget -P apps-plugin https://github.com/vmware-tanzu/apps-cli-plugin/releases/download/v0.6.0/tanzu-apps-plugin-darwin-amd64-v0.6.0.tar.gz
cd apps-plugin
tar -xvf  tanzu-apps-plugin-darwin-amd64-v0.6.0.tar.gz
cd ..
tanzu plugin install apps --local ./apps-plugin --version v0.6.0
```

## Create a cluster

1. Create a cluster on the local machine using Docker as the infrastructure provider.
```shell
tanzu unmanaged-cluster create tce-local -p 80:80 -p 443:443
```

You can look through the output to get a better sense for the components included in the cluster, namely:
- Package repositories, for simple installation of a curated set of Kubernetes OSS tooling
- kapp-controller, for package lifecycle management
- Calico Container Network Interface (CNI) for container and pod networking

When the cluster has been created, you can list the package repositories in all namespaces.
```shell
tanzu package repository list -A
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

Three of these packages require configuration. You can see the configuration here: [values-install-template.yaml](./values-install-template.yaml).

Notice that the configuration file contains some of the environment variables you set earlier. Run the following command to create a final values file with the proper values in place of the variables:
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

You will automate the workflow using Cartographer to create a software _Supply Chain_.


### Operator perspective, part 1: configure kpack builder

kpack needs a _builder_ in order to turn application source code into OCI images. A builder is an image, compliant with [Cloud Native Buildpacks](buildpacks.io), that provides the base OS images necessary to build and run the application (the "stack"), as well as buildpacks to handle application compilation, dependencies, and other language-specific details (the "store").

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

4. Create a ClusterBuilder. Notice that it uses a configuration, [kpack-builder-order.yaml](example/kpack-builder-order.yaml), file to set the order in which buildpacks will evaluate the application code.
```shell
kp clusterbuilder save builder --tag ${IMAGE_PREFIX}builder --stack base --store default --order example/kpack-builder-order.yaml
```

Check the Harbor UI. You will see 4 images under the path `your-username/kp`—these correspond to the build image and the run image in the stack, as well as the go and java buildpacks in the store. You will also see the builder image under the path `cloud-native-crew/builder`. This builder includes the stack and store, and it is the image that kpack will use to build images from application source code.

## Operator perspective, part 2: configure Cartographer rbac and supply chain

```shell
envsubst < values-example-template.yaml > values-example.yaml
kapp deploy --yes -a example-rbac -f <(ytt --ignore-unknown-comments -f example/cluster/ -f values-example.yaml)
kapp deploy --yes -a example-sc -f <(ytt --ignore-unknown-comments -f example/app-operator/ -f values-example.yaml)
```

## Developer perspective: create workload

```shell
tanzu apps workload create hello-crew --type web --git-repo https://github.com/ciberkleid/hello-go.git --git-branch main --app cloud-native-crew --env "HELLO_MSG=crew" --yes
```

```shell
tanzu apps workload get hello-crew        # Alt: kubectl get workload hello-crew -o yaml | yq
```

```shell
kp build logs hello-crew        # Also: tanzu apps workload tail hello-crew
```

```shell
kubectl tree workload hello-crew
```

```shell
kubectl tree kservice hello-crew
```

```shell
kubectl get kservice hello-crew
```

Click on route:
```shell
open http://hello-crew.default.127-0-0-1.sslip.io
```

## Cleanup
```shell
tanzu unmanaged-cluster delete tce-local
```

# Reference
https://tanzucommunityedition.io
https://tanzucommunityedition.io/docs/v0.11/package-readme-app-toolkit-0.1.0
https://tanzucommunityedition.io/docs/v0.11/getting-started-unmanaged
