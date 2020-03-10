#!/bin/bash

CWD=$(pwd)
cd $(dirname $0)

CONFIG_FILE="${CWD}/config.env"

if [ -f "${CONFIG_FILE}" ]; then
  . ${CONFIG_FILE}
else
  touch ${CONFIG_FILE}
fi

for INCLUDE in include/*/main.sh
do
  . ${INCLUDE}
done

COMMAND=$1
shift

if [ -z  ${COMMAND} ]; then
  echo "No command."
  exit 0
fi

case "${COMMAND}" in
  "help" | "-h" | "--help")
    echo "Usage: $(basename $0) <action>"
    echo "  action = ${ACTIONS}"
    ;;
  *)
    if ! declare -f action_${COMMAND} > /dev/null 2>&1; then
      echo "unknown command: ${COMMAND}"
      exit 1
    fi
    action_${COMMAND} "$@"
    ;;
esac

exit 0
