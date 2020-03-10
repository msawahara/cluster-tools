#!/bin/bash

function add_actions () {
  while [ ! -z "$1" ]; do
    echo ${ACTIONS} | tr " " "\n" | grep "^$1$" > /dev/null 2>&1
    if [ $? -eq 1 ]; then
      ACTIONS="${ACTIONS} $1"
    fi
    shift
  done
}

function add_target () {
  NAME="TARGETS_${1^^}"
  VALUE=$2
  export ${NAME}="$(echo ${!NAME} ${VALUE})"
}

function action_prepare () {
  for target in ${TARGETS_PREPARE}
  do
    prepare_${target}
  done
}

function action_check () {
  for target in ${TARGETS_CHECK}
  do
    check_${target}
  done
}

function action_build () {
  if [ -z "$1" ]; then
    echo "Usage: $(basename $0) build <targets> ..."
    echo "  targets = all ${TARGETS_BUILD}"
    return
  fi

  while [ "$1" != "" ]; do
    case "$1" in
      "all" )
        build_all
        ;;
      * )
        if $(echo "${TARGETS_BUILD}" | tr " " "\n" | grep "^$1$" > /dev/null 2>&1); then
          build_$1
          RET=$?
          if [ ${RET} -ne 0 ]; then
            echo "Failed to build target (target=$1, ret=${RET})" >&2
            return 1
          fi
        else
          echo "Unknown build target: $1"
        fi
        ;;
    esac
    shift
  done
}

function build_all () {
  for target in ${TARGETS_BUILD}
  do
    build_${target}
    RET=$?
    if [ ${RET} -ne 0 ]; then
      echo "Failed to build all (target=${target}, ret=${RET})" >&2
      return 1
    fi
  done
}

function _dialog () {
  VARNAME=$1
  shift
  TEMPFILE=$(mktemp)
  dialog "$@" 2> ${TEMPFILE}
  EXITSTATUS=$?
  export ${VARNAME}="$(cat ${TEMPFILE})"
  rm ${TEMPFILE}
  return ${EXITSTATUS}
}

function action_config () {
  while true
  do
    list=()
    for target in ${TARGETS_CONFIG}
    do
      list+=("${target}")
      list+=("$(eval config_${target}_description)")
    done
    _dialog SELECT --menu "select configure target" 20 60 10 "${list[@]}" save "" exit ""
    case "${SELECT}" in
      "exit" )
        break
        ;;
      "save" )
        echo Save...
        dialog --yesno "Save configuration to file?" 7 60
        if [ $? == 1 ]; then
          continue
        fi
        config_save
        dialog --msgbox "Saved" 7 60
        ;;
      * )
        config_${SELECT}
        ;;
    esac
  done
}

function config_update () {
  local NAME=$1
  local VALUE=$2

  if cat ${CONFIG_FILE} | grep "^${NAME}=" > /dev/null; then
    sed -i -e "s|^${NAME}=.*$|${NAME}=\"${VALUE}\"|" ${CONFIG_FILE}
  else
    echo "${NAME}=\"${VALUE}\"" >> ${CONFIG_FILE}
  fi
}

function config_save () {
  for target in ${TARGETS_CONFIG}
  do
    config_${target}_save
  done
}

function prepare_tools () {
  dnf -y install dialog
}

# initialize actions list
ACTIONS=
add_actions prepare config build check

# initialize target list
TARGETS_PREPARE=
TARGETS_CHECK=
TARGETS_CONFIG=
TARGETS_BUILD=

add_target prepare tools
