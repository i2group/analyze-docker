#!/bin/bash
# i2, i2 Group, the i2 Group logo, and i2group.com are trademarks of N.Harris Computer Corporation.
# © N.Harris Computer Corporation (2022-2024)

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
file_env() {
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
