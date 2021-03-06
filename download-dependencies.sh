#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Download dependencies
ytt -f vendir.yml \
  --data-values-file <(envsubst < values-prerequisites.yaml) \
  | vendir sync -f-

mkdir -p vendir/bin

# Extract archive files
tar -xvzf vendir/binaries/krew/*.tar.gz -C vendir/bin
tar -xzvf vendir/binaries-tce/*.tar.gz -C vendir
tar -xvzf vendir/binaries-tce-app-plugin/*.tar.gz -C vendir

# Soft link binary files for consistency into path
mv vendir/binaries/kn/kn* vendir/bin/kn
mv vendir/binaries/kp/kp* vendir/bin/kp
mv vendir/binaries/kubectl/kubectl* vendir/bin/kubectl
mv vendir/binaries/yq/yq* vendir/bin/yq
mv vendir/bin/krew-* vendir/bin/krew
rm -rf vendir/binaries

# Grant exec access to binaries
chmod +x vendir/bin/*

# Install kubectl tree plugin
krew install krew
kubectl krew install tree