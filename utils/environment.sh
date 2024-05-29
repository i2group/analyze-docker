#!/bin/bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)

# Runs a command, suppressing all output UNLESS the command fails
# If the command fails, it'll be reported to stderr.
# $@ = the command to run, including all arguments.
# On success, returns 0 and outputs nothing.
# On failure, returns the command's exit code and outputs to stderr.
function run_quietly() {
  local output exit_code
  if output=$("$@" 2>&1); then
    return 0
  else
    exit_code="$?"
  fi
  echo "ERROR: $* failed, exit code ${exit_code}" >&2
  if [[ -n "${output}" ]]; then
    echo "${output}" >&2
  fi
  return "${exit_code}"
}

# usage: file_env VarName [defaultValue]
#    e.g:
#       file_env 'SA_PASSWORD'
#       file_env 'SA_PASSWORD' 'aStrongPAssw0rd'
#
#    Sets and exports an environment variable.
#
#    If a matching variable is present with _FILE appended to it's name, this file's
#    contents will be used for the environment variable's value.
#    If a variable with the exact same name is set then the literal value of the variable
#    will be used.
#    If neither of the above is the case then the second argument will be used as a default
#    value. If that is absent too then a blank value will be set.
function file_env() {
  local targetVar="$1"
  local fileVar="${targetVar}_FILE"
  local def="${2:-}"
  if [ "${!targetVar:-}" ] && [ "${!fileVar:-}" ]; then
    echo >&2 "Error: both ${targetVar} and ${fileVar} are set, only one is allowed."
    exit 1
  fi
  local resolvedVal="${def}"
  if [ "${!targetVar:-}" ]; then
    resolvedVal="${!targetVar}"
  elif [ "${!fileVar:-}" ]; then
    resolvedVal="$(<"${!fileVar}")"
  fi
  export "${targetVar}"="${resolvedVal}"
  unset "${fileVar}"
}
