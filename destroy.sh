#!/usr/bin/env bash

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

main() {
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
}

if [ "$(basename $0)" = "destroy.sh" ]; then
  if [ "$EUID" -ne 0 ]; then
    echo "re-running with sudo..."
    sudo "${0}"
  else
    main
  fi
fi
