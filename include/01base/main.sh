#!/bin/bash

function config_base ()
{
  BASEDIR=$(cd "$(dirname $0)"; pwd)
  CONFIG_BASE_PATH=${CONFIG_BASE_PATH:-${BASEDIR}}

  _dialog RET --mixedform "Base profile" 20 80 10 \
    "Cluster name"   1 0 "${CONFIG_BASE_NAME}" 1 32 32 0 0 \
    "Base directory" 2 0 "${CONFIG_BASE_PATH}" 2 32 128 0 0

  if [ $? -ne 0 ]; then
    return
  fi

  local LIST=($(echo "$RET" | xargs))
  CONFIG_BASE_NAME=${LIST[0]}
  CONFIG_BASE_PATH=${LIST[1]}
}

function config_base_description () {
  echo "Base profile"
}

function config_base_save () {
  config_update "CONFIG_BASE_NAME" "${CONFIG_BASE_NAME}"
  config_update "CONFIG_BASE_PATH" "${CONFIG_BASE_PATH}"
}

add_target config base
