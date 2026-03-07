#!/bin/bash

function fancy_echo {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

function fancy_echo_line {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt" "$@"
}
