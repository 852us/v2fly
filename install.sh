#!/bin/bash

VERSION="0.0.1"

OS=$(grep "^NAME=" /etc/os-release | cut -d "=" -f 2)
OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d "=" -f 2)
echo $OS
echo $OS_VERSION
