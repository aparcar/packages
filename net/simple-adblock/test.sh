#!/bin/sh

set -x

/etc/init.d/"$1" version 2>&1 | grep "$2"
