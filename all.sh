#!/bin/bash

# Usage:
# . ./all.sh
# eksCreateCluster
# getOutput-all
# eksCleanup

. ./init.sh

declare -A SubnetGW

createRole() {
  echo "Creating role ${EKS_SERVICE_ROLE_NAME}..."
  aws cloudformation create-stack \
    --stack-name ${EKS_SERVICE_ROLE_NAME} \
    --template-body file://amazon-eks-service-role.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters \
    ParameterKey=RoleName,ParameterValue=${EKS_SERVICE_ROLE_NAME}

  waitCreateStack ${EKS_SERVICE_ROLE_NAME}
  getoutput-createRole
}

getoutput-createRole() {
  EKS_SERVICE_ROLE=$(aws cloudformation describe-stacks --region ${AWS_DEFAULT_REGION} --stack-name ${EKS_SERVICE_ROLE_NAME} --query Stacks[].Outputs[].OutputValue[] --output text)
  echo ${EKS_SERVICE_ROLE} | tee ${WORK_DIR}/${ENV_NAME}--EKS_SERVICE_ROLE.log
}

getStackOutput() {
    declare desc=""
    declare stack=${1:?required stackName} outputKey=${2:? required outputKey}

    aws cloudformation describe-stacks \
	--stack-name $stack \
	--query 'Stacks[].Outputs[? OutputKey==`'$outputKey'`].OutputValue' \
	--out text
}

createCluster() {
  aws eks create-cluster \
    --name ${EKS_NAME} \
    --role-arn ${EKS_SERVICE_ROLE} \
    --resources-vpc-config subnetIds=${EKS_K8S_SUBNET_IDS},securityGroupIds=${EKS_SG_CONTROLPLANE}

  echo "Creating cluster: ${EKS_NAME}. Please take your lunch."
  while ! aws eks describe-cluster --name ${EKS_NAME}  --query cluster.status --out text | grep -q ACTIVE; do
    sleep ${SLEEP:=3}
    echo -n .
  done
  sleep 3
  getoutput-createCluster
}

getoutput-createCluster() {
  EKS_ENDPOINT=$(aws eks describe-cluster --name ${EKS_NAME} --query cluster.endpoint)
  echo ${EKS_ENDPOINT} | tee ${WORK_DIR}/${ENV_NAME}--EKS_ENDPOINT.log
  EKS_ARN=$(aws eks describe-cluster --name ${EKS_NAME} --query cluster.arn)
  echo ${EKS_ARN} | tee ${WORK_DIR}/${ENV_NAME}--EKS_ARN.log
  EKS_CERT=$(aws eks describe-cluster --name ${EKS_NAME} --query cluster.certificateAuthority.data)
  echo ${EKS_CERT} | tee ${WORK_DIR}/${ENV_NAME}--EKS_CERT.log
}

createVPC2x8() {
  aws cloudformation create-stack \
    --stack-name ${ENV_NAME}-vpc \
    --parameters \
      ParameterKey=ClusterName,ParameterValue=${EKS_NAME} \
      ParameterKey=Environment,ParameterValue=${ENVIRONMENT} \
      ParameterKey=VpcBlock,ParameterValue=10.${SUBNET_ID}.0.0/16 \
      ParameterKey=Subnet2octet,ParameterValue=${SUBNET_ID} \
      ParameterKey=SubnetPublicA1block,ParameterValue=10.${SUBNET_ID}.0.0/22 \
      ParameterKey=SubnetPublicA2block,ParameterValue=10.${SUBNET_ID}.4.0/22 \
      ParameterKey=SubnetPublicA3block,ParameterValue=10.${SUBNET_ID}.8.0/22 \
      ParameterKey=SubnetPublicA4block,ParameterValue=10.${SUBNET_ID}.12.0/22 \
      ParameterKey=SubnetPublicB1block,ParameterValue=10.${SUBNET_ID}.16.0/22 \
      ParameterKey=SubnetPublicB2block,ParameterValue=10.${SUBNET_ID}.20.0/22 \
      ParameterKey=SubnetPublicB3block,ParameterValue=10.${SUBNET_ID}.24.0/22 \
      ParameterKey=SubnetPublicB4block,ParameterValue=10.${SUBNET_ID}.28.0/22 \
      ParameterKey=SubnetPrivateAblock,ParameterValue=10.${SUBNET_ID}.192.0/18 \
      ParameterKey=SubnetPrivateBblock,ParameterValue=10.${SUBNET_ID}.128.0/18 \
    --template-body file://amazon-eks-vpc-2priv-8pub-sn.yaml \
    --region ${AWS_DEFAULT_REGION}

  waitCreateStack ${ENV_NAME}-vpc
  getoutput-createVPC2x8
}

updateVPC2x8() {
  aws cloudformation update-stack \
    --stack-name ${ENV_NAME}-vpc \
    --parameters \
      ParameterKey=ClusterName,ParameterValue=${EKS_NAME} \
      ParameterKey=Environment,ParameterValue=${ENVIRONMENT} \
      ParameterKey=VpcBlock,ParameterValue=10.${SUBNET_ID}.0.0/16 \
      ParameterKey=Subnet2octet,ParameterValue=${SUBNET_ID} \
      ParameterKey=SubnetPublicA1block,ParameterValue=10.${SUBNET_ID}.0.0/22 \
      ParameterKey=SubnetPublicA2block,ParameterValue=10.${SUBNET_ID}.4.0/22 \
      ParameterKey=SubnetPublicA3block,ParameterValue=10.${SUBNET_ID}.8.0/22 \
      ParameterKey=SubnetPublicA4block,ParameterValue=10.${SUBNET_ID}.12.0/22 \
      ParameterKey=SubnetPublicB1block,ParameterValue=10.${SUBNET_ID}.16.0/22 \
      ParameterKey=SubnetPublicB2block,ParameterValue=10.${SUBNET_ID}.20.0/22 \
      ParameterKey=SubnetPublicB3block,ParameterValue=10.${SUBNET_ID}.24.0/22 \
      ParameterKey=SubnetPublicB4block,ParameterValue=10.${SUBNET_ID}.28.0/22 \
      ParameterKey=SubnetPrivateAblock,ParameterValue=10.${SUBNET_ID}.192.0/18 \
      ParameterKey=SubnetPrivateBblock,ParameterValue=10.${SUBNET_ID}.128.0/18 \
    --template-body file://amazon-eks-vpc-2priv-8pub-sn.yaml \
    --region ${AWS_DEFAULT_REGION}

  waitUpdateStack ${ENV_NAME}-vpc
  getoutput-createVPC2x8
}

getoutput-createVPC2x8() {
  EKS_SG_CONTROLPLANE=$(getStackOutput ${ENV_NAME}-vpc ControlPlaneSecurityGroup)
  echo ${EKS_SG_CONTROLPLANE} | tee ${WORK_DIR}/${ENV_NAME}-VPC--EKS_SG_CONTROLPLANE.log
  # EKS_SG_EKS_ACCESS=$(getStackOutput ${ENV_NAME}-vpc EksAccessSecurityGroup)
  # echo ${EKS_SG_EKS_ACCESS} | tee ${WORK_DIR}/${ENV_NAME}-VPC--EKS_SG_EKS_ACCESS.log
  EKS_SG_ADMIN_ACCESS=$(getStackOutput ${ENV_NAME}-vpc AdminAccessSecurityGroup)
  echo ${EKS_SG_ADMIN_ACCESS} | tee ${WORK_DIR}/${ENV_NAME}-VPC--EKS_SG_ADMIN_ACCESS.log
  EKS_SG_OFFICES_ACCESS=$(getStackOutput ${ENV_NAME}-vpc OfficesAccessSecurityGroup)
  echo ${EKS_SG_OFFICES_ACCESS} | tee ${WORK_DIR}/${ENV_NAME}-VPC--EKS_SG_OFFICES_ACCESS.log
  EKS_SG_WEB_ACCESS=$(getStackOutput ${ENV_NAME}-vpc WebAccessSecurityGroup)
  echo ${EKS_SG_WEB_ACCESS} | tee ${WORK_DIR}/${ENV_NAME}-VPC--EKS_SG_WEB_ACCESS.log
  EKS_VPC_ID=$(getStackOutput ${ENV_NAME}-vpc VpcId)
  echo ${EKS_VPC_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_VPC_ID.log
  EKS_K8S_SUBNET_IDS=$(getStackOutput ${ENV_NAME}-vpc K8sSubnetIds)
  echo ${EKS_K8S_SUBNET_IDS} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_K8S_SUBNET_IDS.log
  EKS_ALL_SUBNET_IDS=$(getStackOutput ${ENV_NAME}-vpc AllSubnetIds)
  echo ${EKS_ALL_SUBNET_IDS} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_ALL_SUBNET_IDS.log
  EKS_PRIVATE_IDS=$(getStackOutput ${ENV_NAME}-vpc PrivateSubnetIds)
  echo ${EKS_PRIVATE_IDS} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_PRIVATE_IDS.log
  EKS_PUBLIC_IDS=$(getStackOutput ${ENV_NAME}-vpc PublicSubnetIds)
  echo ${EKS_PUBLIC_IDS} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_PUBLIC_IDS.log
  EKS_SUBNET_PRIVATE_A_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPrivateA)
  echo ${EKS_SUBNET_PRIVATE_A_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PRIVATE_A_ID.log
  EKS_SUBNET_PRIVATE_B_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPrivateB)
  echo ${EKS_SUBNET_PRIVATE_B_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PRIVATE_B_ID.log

  EKS_SUBNET_PUBLIC_A1_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicA1)
  echo ${EKS_SUBNET_PUBLIC_A1_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_A1_ID.log
  EKS_SUBNET_PUBLIC_A2_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicA2)
  echo ${EKS_SUBNET_PUBLIC_A2_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_A2_ID.log
  EKS_SUBNET_PUBLIC_A3_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicA3)
  echo ${EKS_SUBNET_PUBLIC_A3_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_A3_ID.log
  EKS_SUBNET_PUBLIC_A4_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicA4)
  echo ${EKS_SUBNET_PUBLIC_A4_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_A4_ID.log
  
  EKS_SUBNET_PUBLIC_B1_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicB1)
  echo ${EKS_SUBNET_PUBLIC_B1_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_B1_ID.log
  EKS_SUBNET_PUBLIC_B2_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicB2)
  echo ${EKS_SUBNET_PUBLIC_B2_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_B2_ID.log
  EKS_SUBNET_PUBLIC_B3_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicB3)
  echo ${EKS_SUBNET_PUBLIC_B3_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_B3_ID.log
  EKS_SUBNET_PUBLIC_B4_ID=$(getStackOutput ${ENV_NAME}-vpc SubnetPublicB4)
  echo ${EKS_SUBNET_PUBLIC_B4_ID} | tee ${WORK_DIR}/${ENV_NAME}-vpc--EKS_SUBNET_PUBLIC_B4_ID.log

}

createNodesGroup01() {
  aws cloudformation create-stack \
    --stack-name ${EKS_NAME}-${EKS_NODE_GROUP01_NAME}  \
    --template-body file://amazon-eks-nodegroup.yaml \
    --capabilities CAPABILITY_IAM \
    --parameters \
      ParameterKey=NodeInstanceType,ParameterValue=${EKS_NODE_TYPE} \
      ParameterKey=NodeImageId,ParameterValue=${EKS_WORKER_AMI} \
      ParameterKey=NodeGroupName,ParameterValue=${EKS_NODE_GROUP01_NAME} \
      ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=${EKS_NODE_GROUP01_MIN} \
      ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=${EKS_NODE_GROUP01_MAX} \
      ParameterKey=NodeVolumeSize,ParameterValue=${NODE_MAIN_VOLUME_SIZE} \
      ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=${EKS_SG_CONTROLPLANE} \
      ParameterKey=ClusterName,ParameterValue=${EKS_NAME} \
      ParameterKey=Subnets,ParameterValue=${EKS_PRIVATE_IDS//,/\\,} \
      ParameterKey=VpcId,ParameterValue=${EKS_VPC_ID} \
      ParameterKey=KeyName,ParameterValue=${AWS_KEY_PAIR_NAME}.pub.key \
      ParameterKey=VpcEnvironment,ParameterValue=${ENV_NAME} \
      ParameterKey=NodeDatadogMonitoring,ParameterValue=${NODE_DATADOG_MONITORING} \
      ParameterKey=AutoScalingGroupMonitoringDetailed,ParameterValue=${AUTOSCALING_GROUP_MONITORING_DETAILED} \
      ParameterKey=BootstrapArguments,ParameterValue="--kubelet-extra-args --node-labels=nodesgroup=main"

  waitCreateStack ${EKS_NAME}-${EKS_NODE_GROUP01_NAME}
  getoutput-createNodesGroup01
}

getoutput-createNodesGroup01() {
  EKS_NODE_GROUP01_INSTANCE_ROLE=$(getStackOutput ${EKS_NAME}-${EKS_NODE_GROUP01_NAME} NodeInstanceRole)
  echo ${EKS_NODE_GROUP01_INSTANCE_ROLE} | tee ${WORK_DIR}/${ENV_NAME}--EKS_NODE_GROUP01_INSTANCE_ROLE.log
  EKS_NODE_GROUP01_SECURITY_GROUP=$(getStackOutput ${EKS_NAME}-${EKS_NODE_GROUP01_NAME} NodeSecurityGroup)
  echo ${EKS_NODE_GROUP01_SECURITY_GROUP} | tee ${WORK_DIR}/${ENV_NAME}--EKS_NODE_GROUP01_SECURITY_GROUP.log
}

createNodesGroup02() {
  aws cloudformation create-stack \
    --stack-name ${EKS_NAME}-${EKS_NODE_GROUP02_NAME}  \
    --template-body file://amazon-eks-nodegroup-02.yaml \
    --capabilities CAPABILITY_IAM \
    --parameters \
      ParameterKey=NodeInstanceType,ParameterValue=${EKS_NODE_TYPE} \
      ParameterKey=NodeImageId,ParameterValue=${EKS_WORKER_AMI} \
      ParameterKey=NodeGroupName,ParameterValue=${EKS_NODE_GROUP02_NAME} \
      ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=${EKS_NODE_GROUP02_MIN} \
      ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=${EKS_NODE_GROUP02_MAX} \
      ParameterKey=NodeVolumeSize,ParameterValue=${NODE_GROUP02_VOLUME_SIZE} \
      ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=${EKS_SG_CONTROLPLANE} \
      ParameterKey=ClusterName,ParameterValue=${EKS_NAME} \
      ParameterKey=Subnets,ParameterValue=${EKS_PRIVATE_IDS//,/\\,} \
      ParameterKey=VpcId,ParameterValue=${EKS_VPC_ID} \
      ParameterKey=KeyName,ParameterValue=${AWS_KEY_PAIR_NAME}.pub.key \
      ParameterKey=Subnet2octet,ParameterValue=${SUBNET_ID} \
      ParameterKey=VpcEnvironment,ParameterValue=${ENV_NAME} \
      ParameterKey=NodeDatadogMonitoring,ParameterValue=${NODE_DATADOG_MONITORING} \
      ParameterKey=AutoScalingGroupMonitoringDetailed,ParameterValue=${AUTOSCALING_GROUP_MONITORING_DETAILED} \
      ParameterKey=BootstrapArguments,ParameterValue="--kubelet-extra-args --node-labels=nodesgroup=websites" \
      ParameterKey=NodeGroup01SecurityGroup,ParameterValue=${EKS_NODE_GROUP01_SECURITY_GROUP}

  waitCreateStack ${EKS_NAME}-${EKS_NODE_GROUP02_NAME}
  getoutput-createNodesGroup02
}

getoutput-createNodesGroup02() {
  EKS_NODE_GROUP02_INSTANCE_ROLE=$(getStackOutput ${EKS_NAME}-${EKS_NODE_GROUP02_NAME} NodeInstanceRole)
  echo ${EKS_NODE_GROUP02_INSTANCE_ROLE} | tee ${WORK_DIR}/${ENV_NAME}--EKS_NODE_GROUP02_INSTANCE_ROLE.log
  EKS_NODE_GROUP02_SECURITY_GROUP=$(getStackOutput ${EKS_NAME}-${EKS_NODE_GROUP02_NAME} NodeSecurityGroup)
  echo ${EKS_NODE_GROUP02_SECURITY_GROUP} | tee ${WORK_DIR}/${ENV_NAME}--EKS_NODE_GROUP02_SECURITY_GROUP.log
}

authNodesGroup01() {
  cat > ${WORK_DIR}/aws-auth-cm-group01.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${EKS_NODE_GROUP01_INSTANCE_ROLE}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF
  cat ${WORK_DIR}/aws-auth-cm-group01.yaml
  kubectl apply -f ${WORK_DIR}/aws-auth-cm-group01.yaml
}

authNodesGroupAll() {
  aws eks update-kubeconfig --name ${EKS_NAME}
  cat > ${WORK_DIR}/aws-auth-cm-all.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${EKS_NODE_GROUP02_INSTANCE_ROLE}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${EKS_NODE_GROUP01_INSTANCE_ROLE}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF
  cat ${WORK_DIR}/aws-auth-cm-all.yaml
  kubectl apply -f ${WORK_DIR}/aws-auth-cm-all.yaml
}

waitStackState() {
  declare desc=""
  declare stack=${1:? required stackName} state=${2:? required stackStatePattern}

  echo "Deleting stack: ${stack}. Please take cup of tea."
  while ! aws cloudformation describe-stacks --stack-name ${stack} --query  Stacks[].StackStatus --out text | grep -q "${state}"; do
  	sleep ${SLEEP:=3}
  	echo -n .
  done
}

waitCreateStack() {
  declare stack=${1:? required stackName}
  echo "Creating stack: ${stack}. Please take cup of tea."
  aws cloudformation wait stack-create-complete --stack-name $stack
}

waitUpdateStack() {
  declare stack=${1:? required stackName}
  echo "Updating stack: ${stack}. Please wait."
  aws cloudformation wait stack-update-complete --stack-name $stack
}

deleteStackWait() {
  declare stack=${1:? required stackName}
  aws cloudformation delete-stack --stack-name $stack
  echo "Deleting stack: ${stack}. Please take cup of tea."
  aws cloudformation wait stack-delete-complete --stack-name $stack
}

eksCleanup() {
  echo "$(date +%Y%m%d-%H%M)"
  deleteStackWait ${EKS_NAME}-${EKS_NODE_GROUP02_NAME}
  deleteStackWait ${EKS_NAME}-${EKS_NODE_GROUP01_NAME}
  echo "Deleting EKS cluster: ${EKS_NAME}. Please take your lunch."
  aws eks delete-cluster --name ${EKS_NAME}
  deleteStackWait ${ENV_NAME}-vpc
  deleteStackWait ${EKS_SERVICE_ROLE_NAME}
  echo "$(date +%Y%m%d-%H%M)"
}

eksCreateCluster() {

echo "INFO: Deploying stack name: ${ENV_NAME} ..."
echo "$(date +%Y%m%d-%H%M)"

  if ! aws iam get-role --role-name ${EKS_SERVICE_ROLE_NAME} 2> /dev/null ; then
    echo "INFO: Creating role: ${ENV_NAME} ..."
    createRole
  fi

  createVPC2x8

  createCluster

  aws eks update-kubeconfig --name ${EKS_NAME}
  kubectl config use-context ${EKS_ARN}

  f_awsKeyPair

  createNodesGroup01
  authNodesGroup01

  sleep 20
  kubectl get nodes --show-labels
  sleep 5
  kubectl get nodes

  createNodesGroup02
  authNodesGroupAll
  echo "Add AIM users by command kubectl edit -n kube-system configmap/aws-auth"
  echo "example \
  mapUsers: |
    - userarn: arn:aws:iam::123456789012:user/vadim
      username: vadim
      groups:
        - system:masters
    - userarn: arn:aws:iam::123456789012:user/zenin
      username: zenin
      groups:
        - system:masters"
  sleep 20
  kubectl get nodes
  sleep 20
  kubectl get nodes --show-labels

  echo "$(date +%Y%m%d-%H%M)"

}

getOutput-all() {
  getoutput-createRole
  getoutput-createCluster
  getoutput-createVPC2x8
  getoutput-createNodesGroup01
  getoutput-createNodesGroup02
}
