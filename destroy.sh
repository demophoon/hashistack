#!/usr/bin/env sh

set -e

source ./setup.sh

wait_for_pid() {
  pid=${1:?}
  while kill -0 $pid 2> /dev/null; do
    sleep .1
  done
}

_kill() {
  if [ -f ${_pid:?} ]; then
    sudo kill $(cat ${_pid:?}) ||:
    wait_for_pid ${_pid:?}
    sudo rm -f "${_pid:?}"
    echo "${_context} killed."
  else
    echo "${_context} not running... have you ran setup.sh yet?"
  fi
}

_cleanup() {
  sudo rm -rf "${_context_dir:?}" ||:
}


if [ "$(basename $0)" = "destroy.sh" ]; then
  sudo echo "has root" > /dev/null
  services=(
    nomad
    consul
    vault
  )
  for service in "${services[@]}"; do
    ( with "${service:?}"
      _kill
      _cleanup
    )
  done
fi
