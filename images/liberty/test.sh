# shellcheck shell=bash
# Called by top-level test.sh file to test the Docker image
# All functions in the top-level test.sh file are available for use.
# $IMAGE is the name of the Docker image under test, including the tag
# $IMAGE_NAME is the name of the folder in the images/ directory for the image under test
# $VERSION is the name of the folder in the IMAGE_NAME folder for the image under test

if [[ "${IMAGE}" == "i2group/i2eng-liberty:22-"* ]]; then
  server_path="/opt/ibm/wlp"
else
  server_path="/opt/ol/wlp"
fi

test_docker_image_using_bash_command "\
  openssl version; \
  jq --version; \
  ${server_path}/bin/server version;
  [[ -f '${server_path}/usr/servers/defaultServer/configDropins/defaults/keystore.xml' ]] \
    && echo 'ERROR: Default keystore exists' && exit 1 || echo 'Default keystore not in image'; \
  "
