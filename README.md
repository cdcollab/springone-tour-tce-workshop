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

## Prerequisites

- `docker` must be installed
- `carvel` must be installed
  - `ytt`, `vendir`

## Setup
The instructor will provide a unique username and password to each workshop participant. Once you have your assigned username and password, replace "your-username" and "your-password" in the values below, and set the following environment variables.

Set the following for downloading CLI tools with `vendir`
```shell
export VENDIR_GITHUB_API_TOKEN=your-personal-access-token 
```

Set the following environment variables for installation of Application Toolkit
```shell
export KP_REPO=harbor.tanzu.coraiberkleid.site/your-username/kp
export KP_USERNAME=your-username
export KP_PASSWORD=your-password
```

Set the following environment variables for the example 
```shell
export REGISTRY_URL=https://harbor.tanzu.coraiberkleid.site
export REGISTRY_USERNAME=your-username
export REGISTRY_PASSWORD=your-password
export IMAGE_PREFIX=harbor.tanzu.coraiberkleid.site/your-username/
```

```shell
# vendir workshop assets
./download-dependencies.sh
# install tce
./vendir/tce-darwin-amd64-v0.11.0/install.sh
# verify version v0.11.2
tanzu version
# Install apps plugin
tanzu plugin install apps --local ./apps-plugin --version v0.6.0
# Optional Cleanup Steps
docker kill $(docker ps -q)
docker system prune -a --volumes
# Create unmanaged cluster for workshop 6GB ram, 4cpu, 15gb disk
tanzu uc create spring-one-tour -p 80:80 -p 443:443
# Verify cni has completed install (Status Reconcile succeeded)
tanzu package installed list -A
```

## Development

```shell
dashaun@kaikaku:~/fun/cdcollab/springone-tour-tce-workshop$ git push --set-upstream origin dashaun-dev
Total 0 (delta 0), reused 0 (delta 0), pack-reused 0
remote: 
remote: Create a pull request for 'dashaun-dev' on GitHub by visiting:
remote:      https://github.com/cdcollab/springone-tour-tce-workshop/pull/new/dashaun-dev
remote: 
To github.com:cdcollab/springone-tour-tce-workshop.git
 * [new branch]      dashaun-dev -> dashaun-dev
Branch 'dashaun-dev' set up to track remote branch 'dashaun-dev' from 'origin'.
```