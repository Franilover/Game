#!/bin/sh
printf '\033c\033]0;%s\a' Garlia
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Garlia.x86_64" "$@"
