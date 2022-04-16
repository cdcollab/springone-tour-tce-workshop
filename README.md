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

## Setup
The instructor will provide a unique username and password to each workshop participant. Once you have your assigned username and password, replace "your-username" and "your-password" in the values below, and set the following environment variables.

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