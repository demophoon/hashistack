#!/usr/bin/env bash

set -e

script_file=$(readlink -f "$0")
export script_dir=$(dirname ${script_file})

uname=$(uname -m)
case $(uname -m) in
  aarch64)
    export arch='arm64'
    ;;
  x86_64)
    export arch='amd64'
    ;;
  *)
    export arch=$(uname -m)
    ;;
esac

download_tool() {
  tool=${1:?Tool name required}
  case ${tool} in
    nomad)
      version='1.4.3'
      ;;
    consul)
      version='1.14.2'
      ;;
    vault)
      version='1.12.2'
      ;;
    *)
      echo "Automatic download of ${tool} not supported on this platform."
      exit 1
      ;;
  esac
  dl_url="https://releases.hashicorp.com/${tool:?}/${version:?}/${tool:?}_${version:?}_linux_${arch}.zip"
  mkdir -p "${script_dir:?}/.cache"
  dl_location="${script_dir:?}/.cache/${tool}-.zip"
  if [ ! -f "${dl_location}" ]; then
    curl -Lo "${dl_location:?}" "${dl_url}"
  fi
  bindir="${script_dir:?}/.cache/bin/${_context}"
  if [ ! -x "${bindir}" ]; then
    mkdir "${script_dir:?}/.cache/bin"
    cd "${script_dir:?}/.cache/bin" && unzip "${dl_location:?}"
  fi
  echo ${bindir}
}

tool() {
  if which "${_context}" > /dev/null; then
    which "${_context}"
  else
    download_tool "${_context}"
  fi
}
nomad() { tool; }
consul() { tool; }
vault() { tool; }

with() {
  context=${1:?Context required}

  export _context=${context}
  export _context_dir="${script_dir:?}/services/${context}"
  export _pid=${_context_dir}/${_context}.pid
  export _logs=${_context_dir}/${_context}.log

  mkdir -p "${_context_dir}"
  cd "${_context_dir}"
}

template() {
  in=${1:?Input file required}
  out=${2:?Output file required}
  cat "${script_dir}/templates/${_context:?}/${in}" | envsubst > "${out}"
}

background() {
    if [ -f ${_pid:?} ] && ps -p $(cat ${_pid}) > /dev/null; then
        echo "${_context:?} is already running."
        return 0
    fi
    cmd="${*:?Command required}"
    ${cmd} &> ${_logs:?} &
    pid=$!
    echo $pid > ${_pid:?}
}

get_vault_token() {
  ( with "vault"
    vault_token=$(grep "Root Token" "${_logs}" | awk '{print $3}')
    echo "${vault_token:?Token not found}"
  )
}

wait_for() {
  for i in {0..10}; do
    if ! ps -p $(cat ${_pid}) > /dev/null; then
      echo "Process not running..."
      cat ${_logs}
      return 1
    fi
    if $(curl -so /dev/null ${1}); then
      return 0
    fi
    sleep 3
  done
  echo "Timed out waiting for $1"
  return 1
}

setup_vault() {
  ( with "vault"
    echo "Starting Vault..."
    template vault.hcl.tpl vault.gen.hcl
    background $(vault) server -dev -config=./vault.gen.hcl
    wait_for "http://127.0.0.1:8200/"
    echo "Vault has been started."
    echo "export VAULT_ADDR=http://127.0.0.1:8200"
    vault_token=$(get_vault_token)
    echo "${vault_token}" | vault login -address=http://127.0.0.1:8200 -
  )
}

setup_consul() {
  ( with "consul"
    echo "Starting Consul..."
    mkdir -p "data"
    mkdir -p "config"
    template consul.hcl.tpl config/consul.gen.hcl
    background $(consul) agent -data-dir=data -dev -config-dir=./config
    wait_for "http://127.0.0.1:8500/"
    $(consul) acl bootstrap
    echo "Consul has been started."
  )
}

setup_nomad() {
  ( with "nomad"
    echo "Starting Nomad..."
    mkdir -p "data" "volumes/runner" "volumes/server"
    export _vault_token=$(get_vault_token)
    template nomad.hcl.tpl nomad.gen.hcl
    download_cni_plugins
    background $(nomad) agent -dev-connect -bind 0.0.0.0 -log-level INFO -config nomad.gen.hcl
    wait_for "http://127.0.0.1:4646/"
    echo "Nomad has been started."
  )
}

download_cni_plugins() {
  cni_version="1.1.1"
  dl_location="${script_dir}/.cache/cni-plugins.tgz"
  arch=$(uname -m)
  case ${arch} in
    aarch64)
    arch="arm64"
    ;;
    x86_64)
    arch="amd64"
    ;;
  esac
  if [ ! -f "${dl_location:?}" ]; then
    echo "Downloading CNI plugins..."
    mkdir -p "${script_dir:?}/.cache"
    curl -Lo "${dl_location:?}" "https://github.com/containernetworking/plugins/releases/download/v${cni_version}/cni-plugins-linux-${arch}-v${cni_version}.tgz"
  fi
  ( with "nomad"
    mkdir -p "${_context_dir}/cni/bin"
    cd "${_context_dir}/cni/bin" && tar -xzf "${dl_location:?}" ./
  )
}

main() {
  setup_consul
  setup_vault
  setup_nomad
}

if [ "$(basename $0)" = "setup.sh" ]; then
  if [ "$EUID" -ne 0 ]; then
    echo "re-running with sudo..."
    sudo "${0}"
  else
    main
  fi
fi
