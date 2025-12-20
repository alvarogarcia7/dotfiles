#!/bin/bash

set -euo pipefail

for dir in */; do
  # Remove trailing slash
  dir=${dir%/}
  # Match DD-MM-YYYY
  if [[ $dir =~ ^([0-9]{2})-([0-9]{2})-([0-9]{4})$ ]]; then
    newname="${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}"
    echo mv "'$dir'" "'$newname'"
    echo "#Renamed '$dir' -> '$newname'"
  fi
done

