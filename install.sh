#!/bin/bash

VERSION="0.0.1"


pkg_cmd(){
  if [[ -z $(which apt) ]] ; then
    PKG_CMD="yum"
  endif
}
echo $(PKG_CMD version)
