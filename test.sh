#!/bin/bash


base_dir="$HOME/desktop/projects"

get_subdirs() {
  local base_dir="$1"
  local -n result_array="$2"  # Use nameref to return array by name

  result_array=()  # Clear the output array

  for dir in "$base_dir"/*/; do
    [ -d "$dir" ] || continue
    result_array+=("$(basename "$dir")")
  done
}

get_subdirs "$base_dir" my_dirs

for dir in "${my_dirs[@]}"; do
  echo "📁 $dir"
done

for dir in "$base_dir"/*/; do
  [ -d "$dir" ] || continue
  dir_name="${dir%/}"        # remove trailing slash
  last_part="${dir_name##*/}" # extract last folder
  echo "$last_part"
done
#📁 