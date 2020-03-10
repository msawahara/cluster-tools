#!/bin/bash

function build_openmpi () { 
  _chroot dnf -y install openmpi openmpi-devel
  return $?
}

add_target build openmpi
