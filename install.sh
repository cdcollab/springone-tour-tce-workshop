##### CHECK FOR ENV VARS
if [[ -z ${KP_REPO} || -z ${KP_USERNAME} || -z ${KP_PASSWORD} ]]; then
  echo "The following environment variables must be set:"
  echo "     KP_REPO, KP_USERNAME, KP_PASSWORD"
  exit 1
fi

envsubst < install-values-REDACTED.yaml > install-values.yaml

##### INSTALL APPLICATION TOOLKIT
tanzu package install app-toolkit \
      --package-name app-toolkit.community.tanzu.vmware.com \
      --version 0.1.0 -f install-values.yaml \
      -n tanzu-package-repo-global
