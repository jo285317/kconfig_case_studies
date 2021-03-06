#!/bin/bash

# Run clang on all .i files in a given directory, saving the
# clang output to .i.clang files for each one.

if [ $# -lt 1 ]; then
    echo "USAGE: $(basename $0) preprocessed_source_dir"
    exit 1
fi

path_to_i_files="${1}"

echo "running clang on all .i files in ${path_to_i_files}"
cd "${path_to_i_files}"
ls -d *.config | sort -h | while read config_dir; do
  cd "${config_dir}"
  # run clang from the root of the config_dir to avoid full path in error reports
  find ./ -type f -name "*.i" | while read i; do
    iout="${i%.i}.plist"
    if [[ -e "${iout}" ]]; then
       echo "skipping existing clang run: ${config_dir}/${iout}"
    else
      echo "checking ${config_dir}/${i} and writing to ${config_dir}/${iout}"
      clang-7 --analyze "${i}"
#      mv "${iout}.tmp" "${iout}"
    fi
  done
  cd ../
done
