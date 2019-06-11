#!/bin/bash
# Usage:
# . ./lib.sh

################################################################################
# Functions
################################################################################
function f_echoerr() { 
  echo "$@" 1>&2 | tee -a $DEPLOYMENT_LOG
}

function f_log() {
  logger "${PROGNAME}: $1 $2 $3 $4 $5 $6 $7 $8"
  if [[ "${QUIET}" == "" ]] || [[ ${QUIET} -eq 0 ]]; then
    echo "$1 $2 $3 $4 $5 $6 $7 $8"
  fi
}

function f_check_if_installed_2() {
  # Arguments
  # ${1} program name
  # ${2} package name, that contain the program
  if [ $(which ${1}) ]; then
    f_log "INFO: ${1} found: $(whereis ${1})"
  else
    sudo apt-get update -qq && apt-get install -y ${2}
    if [ $? -ne 0 ] || [ ! $(which ${1}) ]; then
      f_echoerr "ERROR: missing ${1} in PATH" | f_log
      exit 16
    else
      f_log "INFO: ${1} found: $(whereis ${1})"
    fi
  fi
}

function f_check_if_installed() {
  if [ $(which ${1}) ]; then
    echo "INFO: ${1} found: $(whereis ${1})" | tee -a $DEPLOYMENT_LOG
  else
    f_echoerr "ERROR: missing ${1} in PATH" | f_log
    exit 1
  fi
}

f_installAwsEksCli() {
  curl -LO https://s3-us-west-2.amazonaws.com/amazon-eks/1.10.3/2018-06-05/eks-2017-11-01.normal.json
  mkdir -p $HOME/.aws/models/eks/2017-11-01/
  mv eks-2017-11-01.normal.json $HOME/.aws/models/eks/2017-11-01/
  aws configure add-model  --service-name eks --service-model file://$HOME/.aws/models/eks/2017-11-01/eks-2017-11-01.normal.json
}

function f_setKubeconfig() {
  aws eks update-kubeconfig --name ${EKS_NAME}
  kubectl config use-context ${EKS_ARN}
  kubectl config view | grep current-context:
}

function f_awsKeyPair() {
  if [[ -f "${HOME}/.ssh/${AWS_KEY_PAIR_NAME}.pub.key" ]]; then
    echo "Reusing key-pair ${AWS_KEY_PAIR_NAME}.pub.key"
  else
    echo "Creating key-pair ${AWS_KEY_PAIR_NAME}.pub.key"
    f_mySshKeysGeneration ${AWS_KEY_PAIR_NAME}
  fi

  if ! aws ec2 describe-key-pairs | grep ${AWS_KEY_PAIR_NAME}.pub.key > /dev/null; then
    echo "Uploading key to AWS"
    aws ec2 import-key-pair --key-name ${AWS_KEY_PAIR_NAME}.pub.key --public-key-material file://${HOME}/.ssh/${AWS_KEY_PAIR_NAME}.pub.key
  fi
}

function f_mySshKeysGeneration() {
  # Arguments
  # ${1} SSH key name
  KEYNAME="${1}"
  if [[ ! -z ${KEYNAME} ]]; then
    EMAIL="${1}@example.com"
    pushd ${HOME}/.ssh
      if [[ -f ${HOME}/.ssh/${KEYNAME} ]]; then
        f_echoerr "ERROR: file ${HOME}/.ssh/${KEYNAME} exists." | f_log
      else
        ssh-keygen -t rsa -b 4096 -f ${KEYNAME}.priv.key -N '' -C "${KEYNAME}__${EMAIL}"
        mv ${KEYNAME}.priv.key.pub ${KEYNAME}.pub.key
        chmod 400 ${KEYNAME}.priv.key
        chmod 444 ${KEYNAME}.pub.key
        ls -la ${KEYNAME}*
        cat ${KEYNAME}*
      fi
    popd
  else
    f_echoerr "ERROR: f_mySshKeysGeneration argument is empty." | f_log
  fi
}
