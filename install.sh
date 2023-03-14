#!/bin/bash

VERSION="0.0.1"

OS=$(grep "^NAME=" /etc/os-release | awk -F '[="]' "{print $2}")
OS_VERSION=$(grep "^VERSION_ID=" /etc/os-release |  awk -F '[="]' "{print $2}")
echo $OS
echo $OS_VERSION
