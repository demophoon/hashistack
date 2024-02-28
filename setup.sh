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

check_tool() {
  tool=${1:?Tool name required}
  echo ${tool} is missing. Please install to continue
}

tool() {
  if which "${_context}" > /dev/null; then
    which "${_context}"
  else
    _var_name="_${_context}"
    echo "${!_var_name}"
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

with_setup() {
  context=${1:?Context required}
  with ${context:?}
  if is_running; then
    echo "${context:?} is already running."
    exit 0
  fi
}

is_running() {
  [ -f ${_pid:?} ] && ps -p $(cat ${_pid}) > /dev/null
}

template() {
  in=${1:?Input file required}
  out=${2:?Output file required}
  cat "${script_dir}/templates/${_context:?}/${in}" | envsubst > "${out}"
}

background() {
    if is_running ; then
        echo "${_context:?} is already running."
        return 0
    fi
    cmd="${*:?Command required}"
    sudo ${cmd} &> ${_logs:?} &
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
    if ! is_running; then
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
  ( with_setup "vault"
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
  ( with_setup "consul"
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
  ( with_setup "nomad"
    echo "Starting Nomad..."
    mkdir -p "data" "volumes/runner" "volumes/server"
    sudo chmod 777 -R data
    export _vault_token=$(get_vault_token)
    template nomad.hcl.tpl nomad.gen.hcl
    background $(nomad) agent -bind 0.0.0.0 -log-level DEBUG -config nomad.gen.hcl
    wait_for "http://127.0.0.1:4646/"
    echo "Nomad has been started."
  )
}

setup_test() {
  ( with_setup "consul"
    echo $(consul)
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
    echo "export _consul=$(which consul)" > "${script_dir:?}/.env"
    echo "export _nomad=$(which nomad)" >> "${script_dir:?}/.env"
    echo "export _vault=$(which vault)" >> "${script_dir:?}/.env"
    sudo "${0}"
  else
    source "${script_dir:?}/.env"
    main
  fi
fi
