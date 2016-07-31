#!/bin/bash

###

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/functions.sh"

### settings

PROJECT_NAME='project-again'
declare -A VM_IPS
VM_IPS[apache2]='192.168.56.210'
VM_IPS[nginx]='192.168.56.211'

function hostnames() {
  local SERVER=$1
  local NAMES=()
  local PRJ=("${PROJECT_CODENAME}")
  if [[ "${PROJECT_CODENAME}" != "${PROJECT_CODENAME//-}" ]]; then
    PRJ+=("${PROJECT_CODENAME//-}")
  fi
  for PRJ in ${PRJ[@]}; do
    NAMES+=("${PRJ}.${SERVER}.dev")
    for prefix in www\. api\.; do
      NAMES+=("${prefix}${PRJ}.${SERVER}.dev")
    done
  done
  echo "${NAMES[@]}"
}

function setup-hosts() {
    local PROJECT_CODENAME=$1
    log INFO "Setting up /etc/hosts..."
    check-sudo setup-hosts

    local LINEMARKER="###+++DEV-TOOL-ADDITION+${PROJECT_CODENAME}+++"
    local FILE=/etc/hosts
    local LINES=($(cat ${FILE} | grep "${LINEMARKER}" -n | cut -d ':' -f 1))
    local BEGIN=${LINES[0]}
    local END=${LINES[1]}

    local TMP=$(mktemp)

    if [[ ${#LINES[@]} -ge 2 ]]; then
        cat "${FILE}" | head -n $(( BEGIN - 1 )) > "${TMP}"
    else
        cat "${FILE}" > "${TMP}"
    fi

    log INFO "writing temporary hosts file ${TMP}"

    declare -a NAMES

    echo "${LINEMARKER}START###" >> "${TMP}"

    echo "${VM_IPS[nginx]}    $(hostnames 'nginx')" >> "$TMP"
    echo "${VM_IPS[apache2]}    $(hostnames 'apache')" >> "$TMP"

    echo "${LINEMARKER}END###" >> "$TMP"

    if [[ ${#LINES[@]} -ge 2 ]]; then
        cat "${FILE}" | tail -n +$(( END + 1 )) >> "${TMP}"
    fi

    ${DIFF_TOOL} "${TMP}" "${FILE}"
    local NOTSAME=$?

    if [[ ${NOTSAME} -gt 0 ]]; then

        if ask_yesno "Should apply"; then
            rm -f "${FILE}.bck"
            log BACKUP "backing up ${FILE} to ${FILE}.bck"
            mv "${FILE}" "${FILE}.bck"
            log INSTALL "installing modified ${FILE}"
            mv "${TMP}" "${FILE}"
            chmod a+r "${FILE}"
            log SUCCESS install
        else
            log ABORT "user stopped"
        fi
    else
        log INFO "Already same version installed in ${FILE}. Nothing to do."
    fi
    log CLEANUP "Cleaning up temporary files"
    rm -f "${TMP}"
    log FINISHED
}

setup-hosts "${PROJECT_NAME}"
