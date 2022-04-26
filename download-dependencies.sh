#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

ytt -f vendir.yml \
  --data-values-file <(envsubst < values-prerequisites.yaml) \
  | vendir sync -f-

# Soft link files for consistency into path
mkdir -p vendir/bin
mv vendir/binaries/kn/kn* vendir/bin/kn
mv vendir/binaries/kp/kp* vendir/bin/kp
mv vendir/binaries/kubectl/kubectl* vendir/bin/kubectl
mv vendir/binaries/yq/yq* vendir/bin/yq
tar -xvzf vendir/binaries/krew/*.tar.gz -C vendir/bin
mv vendir/bin/krew-* vendir/bin/krew
rm -rf vendir/binaries
chmod +x vendir/bin/*
tar -xzvf vendir/binaries-tce/*.tar.gz -C vendir
tar -xvzf vendir/binaries-tce-app-plugin/*.tar.gz -C vendir
krew install krew
kubectl krew install tree