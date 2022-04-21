#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

ytt -f vendir.yml \
  --data-values-file values-prerequisites.yaml \
  | vendir sync -f-

tar -xzvf vendir/binaries-tce/*.tar.gz -C vendir