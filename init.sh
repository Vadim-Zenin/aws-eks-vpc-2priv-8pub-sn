#!/bin/bash
# Usage:
# . ./init.sh

################################################################################
# Functions
################################################################################
. ./lib.sh

################################################################################
# MAIN
################################################################################

f_check_if_installed aws
f_check_if_installed aws-iam-authenticator
f_check_if_installed kubectl
echo "kubectl version"
kubectl version

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-eu-west-1}"
export ENVIRONMENT="${ENVIRONMENT:-test}"
SUBNET_ID="12"
# AWS_KEY_PAIR_NAME="my-${ENVIRONMENT}-aws-system.pub.key"
AWS_KEY_PAIR_NAME="my-test-testadmin"
export ENV_NAME="${ENVIRONMENT}${SUBNET_ID}"
export EKS_NAME="${ENV_NAME}-eks"
EKS_SERVICE_ROLE_NAME="${EKS_NAME}-service-role"
EKS_NODE_GROUP01_NAME="nodes-main"
EKS_NODE_GROUP02_NAME="nodes-web"
EKS_ARN="arn:aws:eks:eu-west-1:579786142581:cluster/${EKS_NAME}"
NODE_DATADOG_MONITORING="false"
AUTOSCALING_GROUP_MONITORING_DETAILED="false"

# https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html
# Kubernetes version 1.12.7
EKS_WORKER_AMI="ami-08716b70cac884aaa"
EKS_NODE_TYPE=t3.small
EKS_NODE_GROUP01_MIN=2
EKS_NODE_GROUP01_MAX=2
EKS_NODE_GROUP02_MIN=1
EKS_NODE_GROUP02_MAX=2
# Size in GB for persistent volume on EBS
NODE_MAIN_VOLUME_SIZE=50
NODE_GROUP02_VOLUME_SIZE=50
DATADOG_MONITORING="false"

LOGS_DIR="$(pwd)/logs"
DEPLOYMENT_LOG="${LOGS_DIR}/deployment-$(date +%Y%m%d-%H%M).log"
WORK_DIR="$(pwd)/work"

mkdir -p ${LOGS_DIR}
mkdir -p ${WORK_DIR}

f_log "INFO: \${ENVIRONMENT}: ${ENVIRONMENT}"

# aws eks update-kubeconfig --name ${EKS_NAME}
# kubectl config use-context arn:aws:eks:${AWS_DEFAULT_REGION}:579786142581:cluster/${EKS_NAME}
