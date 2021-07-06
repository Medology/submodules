#!/usr/bin/env bash

set -eu

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"

EXPECTED_VERSION=2.0.13

#############################################
# Download the sha256-sum file from composer page for the expected version
#
# Globals:
#   $EXPECTED_VERSION the expected composer version to install/validate
#   $ROOT             root project directory
#
#############################################
downloadComposerSHA() {
  # Download the original sha256 sum for the expected version
  curl -L https://getcomposer.org/download/${EXPECTED_VERSION}/composer.phar.sha256sum > "$ROOT"/bin/composer.sha256sum
}

#############################################
# Delete the downloaded sha256-sum file
#
# Globals:
#   $ROOT root project directory
#############################################
clearComposerSHA() {
  rm "$ROOT"/bin/composer.sha256sum &> /dev/null || TRUE
}

#############################################
# Validate the sha256sum against the existing composer file
#
# Globals:
#   $ROOT root project directory
#
# Returns:
#   1 when the validation pass 
#   0 when the sha validation fail
#
#############################################
isValidComposerSHA() {
  SHA256_SUM=$(cat ./bin/composer.sha256sum)
  # The file includes sha256 string and file name with phar extension
  # The next method replaces the .phar from the string
  PARSED_SHA256_SUM="${SHA256_SUM/ composer.phar/}"
  VALIDATION_RESULT=$(echo "$PARSED_SHA256_SUM ./bin/composer" | sha256sum -c) || TRUE
  if [ "$VALIDATION_RESULT" == "./bin/composer: OK" ]; then
    echo 1
  else
    echo 0
  fi
}

#############################################
# Check if the project already have a composer installed and
# if exists validates the file sha256sum match the expected version
#
# Globals:
#   $EXPECTED_VERSION the expected composer version to install/validate
#   $ROOT             root project directory
#
#############################################
checkExistingInstallation() {
  if [ -e "$ROOT"/bin/composer ]; then
    echo "Checking Composer version..."
    FOUND_VERSION=$( \
        cd "$ROOT" && \
        ./bin/composer --version | \
        tail -1 | \
        awk '{print $3}' \
    )

    if [ "$(isValidComposerSHA)" ]; then
        # Version is as expected. We're done.
        echo "Composer ${EXPECTED_VERSION} already installed."
        clearComposerSHA
        exit 0
    else
        # Version does not match. Remove it.
        echo "Removing Composer version ${FOUND_VERSION}..."
        rm "$ROOT"/bin/composer
    fi
  fi
}

#############################################
# Download the desired composer binary
#
# Globals:
#   $EXPECTED_VERSION the expected composer version to install/validate
#   $ROOT             root project directory
#
#############################################
downloadComposerBinary() {
  # Install composer
  echo "Installing Composer ${EXPECTED_VERSION}..."
  curl -L https://getcomposer.org/download/${EXPECTED_VERSION}/composer.phar > "$ROOT"/bin/composer
}

#############################################
# Validate the sha256sum of the downloaded file
#
# Globals:
#   $ROOT root project directory
#
#############################################
validateDownloadedComposer() {
  echo -n "Checking the SHA for the downloaded file..."
  if [ "$(isValidComposerSHA)" ]; then
      clearComposerSHA
      echo "passed"
  else
      echo "ERROR: composer's sha256sum doesn't match. Download it again."
      rm "$ROOT"/bin/composer
      clearComposerSHA
      exit 1
  fi
}

#############################################
# Fix execution permissions
#
# Globals:
#   $ROOT root project directory
#
#############################################
fixComposerPermissions() {
  echo "Setting composer permissions..."
  chmod 755 "$ROOT"/bin/composer
}

#############################################
# Ensure ~/.composer exists for the Docker container to mount
#############################################
initializeComposerDir() {
  echo "Initializing ~/.composer directory..."
  if [ ! -d ~/.composer ]; then
      mkdir ~/.composer
  fi
}

# Download sha256sum for the expected version
downloadComposerSHA
# Check for existing installation
checkExistingInstallation
# Download composer
downloadComposerBinary
# Validate downloaded file sha256sum match with the expected version sha256sum
validateDownloadedComposer
# Fix permissions
fixComposerPermissions
# Initialize .composer directory
initializeComposerDir

echo "Composer v${EXPECTED_VERSION} installation complete."
