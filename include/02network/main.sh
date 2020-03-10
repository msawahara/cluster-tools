#!/bin/bash

function config_network ()
{
  local DEFAULT_GW_DEV=$(ip r | grep "^default" | grep -o "dev [^ ]*" | cut -d' ' -f2)
  local SECOND_DEVICE=$(ip l | grep -oe "^[0-9]*: [^:]*" | cut -d' ' -f2 | grep -v "^lo$" | grep -v "^${DEFAULT_GW_DEV}$" | head -1)
  if [ ! -z "${SECOND_DEVICE}" ] && [ -z "${CONFIG_NETWORK_IPADDR}" ]; then
    CONFIG_NETWORK_IPADDR="$(ip a show dev ${SECOND_DEVICE} | grep -o " *inet [0-9./]*" | head -1 | sed -e "s/^ *//" | cut -d' ' -f2)"
  fi
  CONFIG_NETWORK_HOSTNAME=${CONFIG_NETWORK_HOSTNAME:-$(hostname -s)}
  CONFIG_NETWORK_DOMAINNAME=${CONFIG_NETWORK_DOMAINNAME:-$(hostname -d)}

  _dialog RET --mixedform "Config/Network" 20 80 10 \
    "IP Address (w/ prefix)" 1 0 "${CONFIG_NETWORK_IPADDR}"     1 32 20 0 0 \
    "Hostname"               2 0 "${CONFIG_NETWORK_HOSTNAME}"   2 32 64 0 0 \
    "Domainname"             3 0 "${CONFIG_NETWORK_DOMAINNAME}" 3 32 64 0 0

  if [ $? -ne 0 ]; then
    return
  fi

  local LIST=($(echo "$RET" | xargs))
  CONFIG_NETWORK_IPADDR=${LIST[0]}
  CONFIG_NETWORK_HOSTNAME=${LIST[1]}
  CONFIG_NETWORK_DOMAINNAME=${LIST[2]}
}

function config_network_description () {
  echo "Cluster Network"
}

function config_network_save () {
  config_update "CONFIG_NETWORK_IPADDR" "${CONFIG_NETWORK_IPADDR}"
  config_update "CONFIG_NETWORK_HOSTNAME" "${CONFIG_NETWORK_HOSTNAME}"
  config_update "CONFIG_NETWORK_DOMAINNAME" "${CONFIG_NETWORK_DOMAINNAME}"
}

add_target config network
