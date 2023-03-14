#!/bin/bash

VERSION="0.0.1"

OS=$(grep "^NAME=" /etc/os-release | cut -d "=" -f 2)