#!/bin/bash

# This script sets up the environment veriables needed for IKOS to run

results_dir=~/varbugs/output

if [[ $# -lt 1 ]]; then
    cat <<EOF
USAGE SCHEMA: $(basename $0) action arg1 arg2 ...

ACTIONS:

list
    list the active cases

(dimacs|config|build) casename [samples]
    dimacs     - generate dimacs file
    config     - configure the system for each sampled config
    build      - build the system for each sampled config

    casename  - the subdirectory of the case in the kconfig_case_studies repo
    samples - the subdirectory containing samples, relative to case dir (default: Configs)

preprocess casename samples outdir
  preprocess each config.  due to generated headers, must also build.

    casename   - as usual
    samples    - as usual (but mandatory)
    outdir     - the path to store the preprocessed files (won't fit in github repo)

randconfigs casename out_dir num
    use kconfig's randconfig to generate a set of random .config files for the given case

NOTES:
  - Run this script from directory in which the project's root Makefile is located.
  - Be sure that KCONFIG_CASE_STUDIES has been set to the repo.
  - For 'dimacs' be sure that KMAX_ROOT has been set to the kmax repo.
EOF
    exit 1
fi

if [[ ! -e "${KCONFIG_CASE_STUDIES}" ]]; then
    echo "please set KCONFIG_CASE_STUDIES in your environment to the path of the repo"
    echo "the repo may be found at https://github.com/paulgazz/kconfig_case_studies"
    exit 1
fi

action="${1}"
casename="${2}"

if [[ $# -ge 3 ]]; then
    sample_dir="${3}"
else
  sample_dir="build/configs"
fi  

case_dir="${KCONFIG_CASE_STUDIES}/cases/${casename}"

if [[ ! -e "${case_dir}" ]]; then
    echo "${case_dir} does not exist."
    action="list"
fi

if [[ "${casename}" == "" || "${action}" == "list" ]]; then
    echo "Please choose from the following:"
    ls ${KCONFIG_CASE_STUDIES}/cases/
    exit 1
fi

if [[ "${action}" == "preprocess" ]]; then
    if [[ $# -lt 3 ]]; then
      echo "please specify the subdirectory (relative to casedir) containing the samples"
      exit 1
    fi
    if [[ $# -ge 4 ]]; then
        preprocessed_outdir="${4}"
    else
      echo "please specify outdir to store preprocessed files"
      exit 1
    fi
fi
# setup case-specific properties
config_file=""
kconfig_root=""
binaries=""
get_reverse_dep=""
check_dep_extra_args=""
dimacs_extra_args="-d"
make_extra_args=""
# dimacs_extra_args="--remove-bad-selects" # allow bad selects, since fiasco using them intentionally
echo "${casename}" | grep -i "axtls" > /dev/null
if [[ $? -eq 0 ]]; then
    config_file="config/.config"
    kconfig_root="config/Config.in"
    binaries="_stage/axhttpd"
    get_reverse_dep="true"
    # axtls variables already include the the CONFIG_ prefix and it's
    # kconfig system is modified not to.  add a flag to check_dep to
    # disable the prefix for axtls.
    check_dep_extra_args="-p"
fi
echo "${casename}" | grep -i "toybox" > /dev/null
if [[ $? -eq 0 ]]; then
    config_file=".config"
    kconfig_root="Config.in"
    binaries="toybox"
    get_reverse_dep="true"
fi
echo "${casename}" | grep -i "busybox" > /dev/null
if [[ $? -eq 0 ]]; then
    config_file=".config"
    kconfig_root="Config.in"
    binaries="busybox"
    get_reverse_dep="true"
    make_extra_args="KBUILD_VERBOSE=1"  # emit entire gcc commands
fi
echo "${casename}" | grep -i "fiasco" > /dev/null
if [[ $? -eq 0 ]]; then
    config_file="build/globalconfig.out"
    kconfig_root="build/Kconfig"
    # perhaps just use "*.{o,a}"
    binaries="build/*.o build/*.a"
    # if [[ "${action}" == "build" ]]; then
    #     # looks like boot_image.{x1,x2}
    #     echo "ERROR: please figure out what to use to measure the binary size" >&2
    #     exit 1 
    # fi
    get_reverse_dep="true"
fi
echo "${casename}" | grep -i "uClibc-ng" > /dev/null
if [[ $? -eq 0 ]]; then
    config_file=".config"
    kconfig_root="extra/Configs/Config.in"
    binaries="*"  # TODO: set binaries
    get_reverse_dep=""
    # don't add extra CONFIG_ prefix for uClibc-ng.  also set default
    # environment variables with -d.
    check_dep_extra_args="-p -d"
fi
echo "${casename}" | grep -i "buildroot" > /dev/null
if [[ $? -eq 0 ]]; then
    config_file=".config"
    kconfig_root="Config.in"
    binaries="*"  # TODO: set binaries
    get_reverse_dep=""
    # don't add CONFIG_ prefix, already uses BR2 itself.  must set a build path.
    check_dep_extra_args="-p -e BUILD_DIR=."
    touch .br2-external.in  # this file is necessary in order to process the Config.in
fi


if [[ "${config_file}" == "" || "${kconfig_root}" == "" ]]; then
    echo "unknown case '${casename}. please add it to this script '${0}'"
    exit 1
fi

experiment_dir=${case_dir}/${sample_dir}

if [[ "${action}" == "randconfigs" ]]; then
    if [[ $# -ge 4 ]]; then
        num="${4}"
        if [ -d "${experiment_dir}" ]; then
            echo "error: the out_dir '${sample_dir}' already exists.  please remove it or give a nonexistent directory"
            exit 1
        fi
        mkdir -p ${experiment_dir}
        for i in $(seq $((num - 1))); do
          make randconfig
          cp "${config_file}" "${experiment_dir}/${i}.config"
        done
        exit 0
    else
      echo "missing arguments for randconfigs"
      exit 1
    fi
fi

if [[ "${action}" == "config" || "${action}" == "build" || "${action}" == "preprocess" ]]; then
    if [[ ! -d ${experiment_dir} ]]; then
        echo "the samples directory does not exist or is not a directory"
        exit 1
    fi
    
    kconfig_out_dir="${experiment_dir}/kconfig_out"
    mkdir -p "${kconfig_out_dir}"
    build_out_dir="${experiment_dir}/build_out"
    mkdir -p "${build_out_dir}"
    preprocess_out_dir="${experiment_dir}/preprocess_out"
    mkdir -p "${preprocess_out_dir}"

    # configure or build each sample
    if [[ ! -e "${experiment_dir}" ]]; then
        echo "${experiment_dir} does not exist."
        exit 1
    fi
    
    if [[ "${action}" == "config" ]]; then
        for i_base in $(ls ${experiment_dir}/*.config | xargs -L 1 basename | sort -n); do
          i="${experiment_dir}/${i_base}"
          echo "configuring $i";
          cat $i | grep -v "SPECIAL_ROOT_VARIABLE" > "${config_file}";
          time make oldconfig;
          cp "${config_file}" "${kconfig_out_dir}/$(basename ${i})"
          cat "${config_file}" | md5sum > "${kconfig_out_dir}/$(basename ${i}).md5"
          python "${KCONFIG_CASE_STUDIES}/scripts/compare_configs.py" "${case_dir}/kconfig.kmax" "${i}" "${config_file}";
          echo "diff result: ${?}";
        done 2>&1 | tee "${experiment_dir}/config_diff_results.out" | egrep "^(configuring)"

        cat "${kconfig_out_dir}/"*.md5 | sort | uniq -d > "${experiment_dir}/uniq_config_comparison.out"

        echo "has $(cat "${experiment_dir}/uniq_config_comparison.out" | wc -l) duplicate config files" | tee -a "${experiment_dir}/config_diff_results.out"

    elif [[ "${action}" == "build" || "${action}" == "preprocess" ]]; then
        for i_base in $(ls ${experiment_dir}/*.config | xargs -L 1 basename | sort -n); do
          i="${experiment_dir}/${i_base}"
          build_out_file="${build_out_dir}/$(basename ${i}).out"
          preprocess_out_file="${preprocess_out_dir}/$(basename ${i}).preprocess.out"
          preprocess_build_out_file="${preprocess_out_dir}/$(basename ${i}).build.out"

          if [[ "${action}" == "build" ]]; then
              save_file="${build_out_file}"
          elif [[ "${action}" == "preprocess" ]]; then
              save_file="${preprocess_build_out_file}"
          else
            print "unknown action for compilation"
            exit 1
          fi
          
          for dummy in $(seq 1 1); do  # single-iteration loop to make saving output easier
            echo "configuring $i";
            cat $i | grep -v "SPECIAL_ROOT_VARIABLE" > "${config_file}";

            # case-specific build scripts
            echo "${casename}" | grep -i "axtls" > /dev/null
            if [[ $? -eq 0 ]]; then
                mkdir -p /tmp/lua
                echo 'CONFIG_HTTP_LUA_PREFIX="/tmp/lua"' >> "${config_file}";
            fi
            echo "${casename}" | egrep -i "uClibc-ng" >/dev/null
            if [[ $? -eq 0 ]]; then
                mv "${config_file}" "${config_file}.tmp"
                cat "${config_file}.tmp" | grep -v "^KERNEL_HEADERS=" > "${config_file}"; echo 'KERNEL_HEADERS="/home/vagrant/linux-headers/include"' >> "${config_file}"
            fi

            time make oldconfig;

            echo "building $i";
            make clean;
            echo "${casename}" | grep -i "axtls" > /dev/null
            if [[ $? -eq 0 ]]; then
                mkdir -p /tmp/local
                time make ${make_extra_args} PREFIX="/tmp/local"
            else
              time make ${make_extra_args};
            fi
            echo "return code $?";
            echo "binary size (in bytes): $(du -bc ${binaries} | tail -n1 | cut -f1)"

	    extract-bc ${binaries}
	    cp ${binaries}.bc ${results_dir}/${casename}/ikos_results/ikos_${i_base}.bc
	    
	    # Do IKOS processing
	    #extract-bc ${binaries}
	    #ikos --ikos-pp ${binaries}.bc -o ikos_${i_base}.db
          done 2>&1 | tee "${save_file}" | egrep "^(building)"

          if [[ "${action}" == "preprocess" ]]; then
              echo "preprocessing $i"
              python "${KCONFIG_CASE_STUDIES}/scripts/preprocess_config.py" "${build_out_file}" "${preprocessed_outdir}/${i_base}" > "${preprocess_out_file}" 2>&1
          fi
        done
    fi

elif [[ "${action}" == "dimacs" ]]; then
    if [[ ! -e "${KMAX_ROOT}" ]]; then
        echo "please set KMAX_ROOT in your environment to the path of the kmax repo"
        echo "the repo may be found at https://github.com/paulgazz/kmax"
        exit 1
    fi

    # extract kconfig constraints to kmax intermediate format
    "${KMAX_ROOT}/kconfig/check_dep" ${check_dep_extra_args} --dimacs "${kconfig_root}" | tee "${case_dir}/kconfig.kmax"

    # complete
    # time cat "${case_dir}/kconfig.kmax" | python "${KMAX_ROOT}/kconfig/dimacs.py" --remove-bad-selects --include-nonvisible-bool-defaults --remove-orphaned-nonvisibles --remove-independent-nonvisibles > "${case_dir}/kconfig.dimacs"
    # time cat "${case_dir}/kconfig.kmax" | python "${KMAX_ROOT}/kconfig/dimacs.py" --remove-bad-selects --include-nonvisible-bool-defaults --remove-orphaned-nonvisibles > "${case_dir}/kconfig.dimacs"
    time cat "${case_dir}/kconfig.kmax" | python "${KMAX_ROOT}/kconfig/dimacs.py" ${dimacs_extra_args} --include-nonvisible-bool-defaults --remove-orphaned-nonvisibles > "${case_dir}/kconfig.dimacs"
    
    # # without reverse dependencies
    # time cat "${case_dir}/kconfig.kmax" | python "${KMAX_ROOT}/kconfig/dimacs.py" --remove-reverse-dependencies --remove-all-nonvisibles > "${case_dir}/sans_reverse_sans_nonselectable.dimacs"
    # time cat "${case_dir}/kconfig.kmax" | python "${KMAX_ROOT}/kconfig/dimacs.py" --remove-reverse-dependencies > "${case_dir}/sans_reverse_with_nonselectable.dimacs"

    # # get the dimacs file by running kmax's check_dep
    # if [[ "${get_reverse_dep}" != "" ]]; then
    #     time cat "${case_dir}/kconfig.kmax" | python "${KMAX_ROOT}/kconfig/dimacs.py" --remove-bad-selects --remove-all-nonvisibles > "${case_dir}/with_reverse_sans_nonselectable.dimacs"
    #     time cat "${case_dir}/kconfig.kmax" | python "${KMAX_ROOT}/kconfig/dimacs.py" --remove-bad-selects > "${case_dir}/with_reverse_with_nonselectable.dimacs"
    # fi
else
  echo "invalid action"
  exit 1
fi
