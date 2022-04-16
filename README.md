# springone-tour-tce-workshop

## Overview
This workshop walks you through:
1. Creating a local cluster on Docker using Tanzu Community Edition
2. Installing Application Toolkit on the cluster
3. Running an example of a Software Supply Chain using Cartographer to move a developer workload through a chain of activities, comprising:
   1. Poll for new source code commits using Fluxcd Source Controller
   2. Build and publish container image using kpack
   3. Store and scan the image using Harbor
   4. Run the application using Knative Serving

## Setup
The instructor will provide a unique username and password to each workshop participant. Once you have your assigned username and password, replace "your-username" and "your-password" in the values below, and set the following environment variables.

Set the following environment variables for installstion of Application Toolkit
```shell
export KP_REPO=harbor.tanzu.coraiberkleid.site/your-username/kp
export KP_USERNAME=your-username
export KP_PASSWORD=your-password
```

Set the following environment variables to run the example 
```shell
export REGISTRY_URL=https://harbor.tanzu.coraiberkleid.site
export REGISTRY_USERNAME=your-username
export REGISTRY_PASSWORD=your-password
export IMAGE_PREFIX=harbor.tanzu.coraiberkleid.site/your-username/
```