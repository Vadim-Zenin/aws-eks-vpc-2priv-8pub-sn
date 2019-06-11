#!/bin/bash
# === SSH keys generation
# Tested on Ubuntu 14.04, 16.04, 18.04
# Version=201906031602

# Mac OS: bash ant-ssh-keys-generation.sh


# MYLOGIN="<user_login>"
MYLOGIN="testadmin"
SHORTCOMPANY="my"
EMAIL="${MYLOGIN}@example.com"
pushd ${HOME}/.ssh
# declare -a ENVLIST=("dev" "qa" "stg" "uat" "prd" "biz" "dop")
declare -a ENVLIST=("test")
for MYENV in "${ENVLIST[@]}"; do
	KEYNAME="${SHORTCOMPANY}-${MYENV}-${MYLOGIN}"
  if [[ -f ${HOME}/.ssh/${KEYNAME} ]]; then
    echo "ERROR: file ${HOME}/.ssh/${KEYNAME} exists."
  else
  	ssh-keygen -t rsa -b 4096 -f ${KEYNAME}.priv.key -N '' -C "${KEYNAME}__${EMAIL}"
  	mv ${KEYNAME}.priv.key.pub ${KEYNAME}.pub.key
  	chmod 400 ${KEYNAME}.priv.key
  	chmod 444 ${KEYNAME}.pub.key
  	ls -la ${KEYNAME}*
  	cat ${KEYNAME}*
  fi
done
popd

# Environments:
# prd - Production
# stg - Staging
# uat - User Acceptance Test
# qa  - QA
# dev - Development
# dop - DevOps
# biz - Business, office
# git - GitLab

#== Public key text inside file must start from ssh-rsa 
