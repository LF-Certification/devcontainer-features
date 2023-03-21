#!/usr/bin/env bash

set -euo pipefail

# Constants
USER_BASHRC_PATH="${_REMOTE_USER_HOME}/.bashrc"
PASSWORD_STORE_DIR="/home/${_CONTAINER_USER}/.password-store"

# Functions
cleanup_apt_cache() {
    rm -rf /var/lib/apt/lists/*
}

ensure_dependencies() {
    local dependencies=("curl" "jq")
    local to_install=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep}" > /dev/null; then
            to_install+=("${dep}")
        fi
    done

    if [ "${#to_install[@]}" -ne 0 ]; then
        apt-get update
        apt-get install -y "${to_install[@]}"
        cleanup_apt_cache
    fi
}

install_aws_vault() {
    local release_url="https://api.github.com/repos/99designs/aws-vault/releases/latest"
    local asset_name
    asset_name=$(curl -sSL -H "Accept: application/vnd.github+json" "${release_url}" | jq -r '.assets[].name | select(test("linux-amd64"))')

    local download_url
    download_url=$(curl -sSL -H "Accept: application/vnd.github+json" "${release_url}" | jq -r --arg asset_name "${asset_name}" '.assets[] | select(.name == $asset_name) | .browser_download_url')

    curl -sSL -o /tmp/aws-vault "${download_url}"
    mv /tmp/aws-vault /usr/local/bin
    chmod +x /usr/local/bin/aws-vault
}

add_env_vars_to_bashrc() {
    echo "Adding aws-vault env vars to ${USER_BASHRC_PATH}"
    local env_vars=("AWS_VAULT_PASS_PASSWORD_STORE_DIR=${PASSWORD_STORE_DIR}" "AWS_VAULT_BACKEND=pass")

    for env_var in "${env_vars[@]}"; do
      echo "export ${env_var}" >> "${USER_BASHRC_PATH}"
    done
}

# Main script
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

ensure_dependencies
cleanup_apt_cache
install_aws_vault
add_env_vars_to_bashrc
cleanup_apt_cache

echo "Done!"
