#!/bin/bash

function build_infiniband () { 
  _chroot dnf -y groupinstall "Infiniband Support"
  return $?
}

add_target build infiniband
