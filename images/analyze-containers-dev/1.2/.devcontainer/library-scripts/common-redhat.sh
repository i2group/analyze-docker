#!/usr/bin/env bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)
#
# SPDX short identifier: MIT
#
# Original copyright:
## -------------------------------------------------------------------------------------------------------------
## Copyright (c) Microsoft Corporation. All rights reserved.
## Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
## -------------------------------------------------------------------------------------------------------------
##
## ** This script is community supported **
## Docs: https://github.com/microsoft/vscode-dev-containers/blob/main/script-library/docs/common.md
## Maintainer: The VS Code and Codespaces Teams
##
## Syntax: ./common-redhat.sh [username] [user UID] [user GID] [upgrade packages flag]

set -e

USERNAME=${1:-"automatic"}
USER_UID=${2:-"automatic"}
USER_GID=${3:-"automatic"}
UPGRADE_PACKAGES=${4:-"true"}
SCRIPT_DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"
MARKER_FILE="/usr/local/etc/vscode-dev-containers/common"

if [ "$(id -u)" -ne 0 ]; then
  echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
  exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" >/etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# If in automatic mode, determine if a user already exists, if not use vscode
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
  USERNAME=""
  POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
  for CURRENT_USER in ${POSSIBLE_USERS[@]}; do
    if id -u ${CURRENT_USER} >/dev/null 2>&1; then
      USERNAME=${CURRENT_USER}
      break
    fi
  done
  if [ "${USERNAME}" = "" ]; then
    USERNAME=vscode
  fi
elif [ "${USERNAME}" = "none" ]; then
  USERNAME=root
  USER_UID=0
  USER_GID=0
fi

# Load markers to see which steps have already run
if [ -f "${MARKER_FILE}" ]; then
  echo "Marker file found:"
  cat "${MARKER_FILE}"
  source "${MARKER_FILE}"
fi

# Install common dependencies
if [ "${PACKAGES_ALREADY_INSTALLED}" != "true" ]; then

  package_list="\
        gnupg2 \
        procps \
        net-tools \
        curl-minimal \
        wget \
        rsync \
        less \
        jq \
        libicu \
        sudo \
        sed \
        grep \
        which \
        git"

  microdnf -y install ${package_list}

  if ! type git >/dev/null 2>&1; then
    microdnf -y install git
  fi

  PACKAGES_ALREADY_INSTALLED="true"
fi

# Update to latest versions of packages
if [ "${UPGRADE_PACKAGES}" = "true" ]; then
  microdnf upgrade -y
fi

# Create or update a non-root user to match UID/GID.
group_name="${USERNAME}"
if id -u ${USERNAME} >/dev/null 2>&1; then
  # User exists, update if needed
  if [ "${USER_GID}" != "automatic" ] && [ "$USER_GID" != "$(id -g $USERNAME)" ]; then
    group_name="$(id -gn $USERNAME)"
    groupmod --gid $USER_GID ${group_name}
    usermod --gid $USER_GID $USERNAME
  fi
  if [ "${USER_UID}" != "automatic" ] && [ "$USER_UID" != "$(id -u $USERNAME)" ]; then
    usermod --uid $USER_UID $USERNAME
  fi
else
  # Create user
  if [ "${USER_GID}" = "automatic" ]; then
    groupadd $USERNAME
  else
    groupadd --gid $USER_GID $USERNAME
  fi
  if [ "${USER_UID}" = "automatic" ]; then
    useradd -s /bin/bash --gid $USERNAME -m $USERNAME
  else
    useradd -s /bin/bash --uid $USER_UID --gid $USERNAME -m $USERNAME
  fi
fi

# Add add sudo support for non-root user
if [ "${USERNAME}" != "root" ] && [ "${EXISTING_NON_ROOT_USER}" != "${USERNAME}" ]; then
  echo $USERNAME ALL=\(root\) NOPASSWD:ALL >/etc/sudoers.d/$USERNAME
  chmod 0440 /etc/sudoers.d/$USERNAME
  EXISTING_NON_ROOT_USER="${USERNAME}"
fi

# ** Shell customization section **
if [ "${USERNAME}" = "root" ]; then
  user_rc_path="/root"
else
  user_rc_path="/home/${USERNAME}"
fi

# .bashrc/.zshrc snippet
rc_snippet="$(
  cat <<'EOF'
if [ -z "${USER}" ]; then export USER=$(whoami); fi
# Set the default git editor if not already set
if [ -z "$(git config --get core.editor)" ] && [ -z "${GIT_EDITOR}" ]; then
    if  [ "${TERM_PROGRAM}" = "vscode" ]; then
        if [[ -n $(command -v code-insiders) &&  -z $(command -v code) ]]; then 
            export GIT_EDITOR="code-insiders --wait"
        else 
            export GIT_EDITOR="code --wait"
        fi
    fi
fi
EOF
)"

# code shim, it fallbacks to code-insiders if code is not available
cat <<'EOF' >/usr/local/bin/code
#!/bin/sh
get_in_path_except_current() {
    which -a "$1" | grep -A1 "$0" | grep -v "$0"
}
code="$(get_in_path_except_current code)"
if [ -n "$code" ]; then
    exec "$code" "$@"
elif [ "$(command -v code-insiders)" ]; then
    exec code-insiders "$@"
else
    echo "code or code-insiders is not installed" >&2
    exit 127
fi
EOF
chmod +x /usr/local/bin/code

# Codespaces bash and OMZ themes - partly inspired by https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme
codespaces_bash="$(
  cat \
    <<'EOF'
# Codespaces bash prompt theme
__bash_prompt() {
    local userpart='`export XIT=$? \
        && [ ! -z "${GITHUB_USER}" ] && echo -n "\[\033[0;32m\]@${GITHUB_USER} " || echo -n "\[\033[0;32m\]\u " \
        && [ "$XIT" -ne "0" ] && echo -n "\[\033[1;31m\]➜" || echo -n "\[\033[0m\]➜"`'
    local gitbranch='`\
        if [ "$(git config --get codespaces-theme.hide-status 2>/dev/null)" != 1 ]; then \
            export BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null); \
            if [ "${BRANCH}" != "" ]; then \
                echo -n "\[\033[0;36m\](\[\033[1;31m\]${BRANCH}" \
                && if git ls-files --error-unmatch -m --directory --no-empty-directory -o --exclude-standard ":/*" > /dev/null 2>&1; then \
                        echo -n " \[\033[1;33m\]✗"; \
                fi \
                && echo -n "\[\033[0;36m\]) "; \
            fi; \
        fi`'
    local lightblue='\[\033[1;34m\]'
    local removecolor='\[\033[0m\]'
    PS1="${userpart} ${lightblue}\w ${gitbranch}${removecolor}\$ "
    unset -f __bash_prompt
}
__bash_prompt
EOF
)"

# Add RC snippet and custom bash prompt
if [ "${RC_SNIPPET_ALREADY_ADDED}" != "true" ]; then
  echo "${rc_snippet}" >>/etc/bashrc
  echo "${codespaces_bash}" >>"${user_rc_path}/.bashrc"
  if [ "${USERNAME}" != "root" ]; then
    echo "${codespaces_bash}" >>"/root/.bashrc"
  fi
  chown ${USERNAME}:${group_name} "${user_rc_path}/.bashrc"
  RC_SNIPPET_ALREADY_ADDED="true"
fi

# Persist image metadata info, script if meta.env found in same directory
meta_info_script="$(
  cat <<'EOF'
#!/bin/sh
. /usr/local/etc/vscode-dev-containers/meta.env
# Minimal output
if [ "$1" = "version" ] || [ "$1" = "image-version" ]; then
    echo "${VERSION}"
    exit 0
elif [ "$1" = "release" ]; then
    echo "${GIT_REPOSITORY_RELEASE}"
    exit 0
elif [ "$1" = "content" ] || [ "$1" = "content-url" ] || [ "$1" = "contents" ] || [ "$1" = "contents-url" ]; then
    echo "${CONTENTS_URL}"
    exit 0
fi
#Full output
echo
echo "Development container image information"
echo
if [ ! -z "${VERSION}" ]; then echo "- Image version: ${VERSION}"; fi
if [ ! -z "${DEFINITION_ID}" ]; then echo "- Definition ID: ${DEFINITION_ID}"; fi
if [ ! -z "${VARIANT}" ]; then echo "- Variant: ${VARIANT}"; fi
if [ ! -z "${GIT_REPOSITORY}" ]; then echo "- Source code repository: ${GIT_REPOSITORY}"; fi
if [ ! -z "${GIT_REPOSITORY_RELEASE}" ]; then echo "- Source code release/branch: ${GIT_REPOSITORY_RELEASE}"; fi
if [ ! -z "${BUILD_TIMESTAMP}" ]; then echo "- Timestamp: ${BUILD_TIMESTAMP}"; fi
if [ ! -z "${CONTENTS_URL}" ]; then echo && echo "More info: ${CONTENTS_URL}"; fi
echo
EOF
)"
if [ -f "${SCRIPT_DIR}/meta.env" ]; then
  mkdir -p /usr/local/etc/vscode-dev-containers/
  cp -f "${SCRIPT_DIR}/meta.env" /usr/local/etc/vscode-dev-containers/meta.env
  echo "${meta_info_script}" >/usr/local/bin/devcontainer-info
  chmod +x /usr/local/bin/devcontainer-info
fi
# Ensure shasum is available in the expected path
ln -s /usr/bin/sha256sum /usr/bin/shasum
ln -s /usr/bin/gpg /usr/local/bin/gpg

# Write marker file
mkdir -p "$(dirname "${MARKER_FILE}")"
echo -e "\
    PACKAGES_ALREADY_INSTALLED=${PACKAGES_ALREADY_INSTALLED}\n\
    EXISTING_NON_ROOT_USER=${EXISTING_NON_ROOT_USER}\n\
    RC_SNIPPET_ALREADY_ADDED=${RC_SNIPPET_ALREADY_ADDED}" >"${MARKER_FILE}"

echo "Done!"
