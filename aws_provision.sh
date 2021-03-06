#!/bin/bash

### get AWS Lightsail bundles
#aws lightsail get-bundles --region ap-southeast-1 --query 'bundles[].{price:price,cpuCount:cpuCount,ramSizeInGb:ramSizeInGb,diskSizeInGb:diskSizeInGb,bundleId:bundleId,instanceType:instanceType,supportedPlatforms:supportedPlatforms[0]}' --output table  --no-cli-pager

### get AWS lightsail blueprint
#aws lightsail get-blueprints --region ap-southeast-1 --query 'blueprints[].{blueprintId:blueprintId,name:name,group:group,productUrl:productUrl,platform:platform}' --output table --no-cli-pager


# +-----------------+-----------+---------------+---------------+--------+---------------+----------------------+
# |    bundleId     | cpuCount  | diskSizeInGb  | instanceType  | price  |  ramSizeInGb  | supportedPlatforms   |
# +-----------------+-----------+---------------+---------------+--------+---------------+----------------------+
# |  nano_2_0       |  1        |  20           |  nano         |  3.5   |  0.5          |  LINUX_UNIX          |
# |  micro_2_0      |  1        |  40           |  micro        |  5.0   |  1.0          |  LINUX_UNIX          |
# |  small_2_0      |  1        |  60           |  small        |  10.0  |  2.0          |  LINUX_UNIX          |
# |  medium_2_0     |  2        |  80           |  medium       |  20.0  |  4.0          |  LINUX_UNIX          |
# |  large_2_0      |  2        |  160          |  large        |  40.0  |  8.0          |  LINUX_UNIX          |
# |  xlarge_2_0     |  4        |  320          |  xlarge       |  80.0  |  16.0         |  LINUX_UNIX          |
# |  2xlarge_2_0    |  8        |  640          |  2xlarge      |  160.0 |  32.0         |  LINUX_UNIX          | 
# +-----------------+-----------+---------------+---------------+--------+---------------+----------------------+


### main function
function main(){
local tags=$1
create-key-pair $tags
create-bucket $tags
create-instances $tags-rancher $tags medium_2_0
create-instances $tags-rke-m1 $tags large_2_0
create-instances $tags-rke-w1 $tags large_2_0
create-instances $tags-rke-w2 $tags large_2_0
create-instances $tags-rke-w3 $tags large_2_0
check-instance-state $tags
put-instance-ports $tags-rancher
put-instance-ports $tags-rke-m1
put-instance-ports $tags-rke-w1
put-instance-ports $tags-rke-w2
put-instance-ports $tags-rke-w3
ssh-file $tags $tags-rancher
ssh-file $tags $tags-rke-m1
ssh-file $tags $tags-rke-w1
ssh-file $tags $tags-rke-w2
ssh-file $tags $tags-rke-w3
html-file $tags $tags-rancher 80
html-file $tags $tags-rke-w1 30080
html-file $tags $tags-rke-w1 31080
tar-file $tags
}


### create key pair for each $tag 
function create-key-pair (){
local tags=$1
mkdir -p ~/$1-lab-info/
sleep 1
aws lightsail create-key-pair --key-pair-name $tags-default-key --output text --query privateKeyBase64 > ~/$tags-lab-info/$tags-default-key.pem
chmod 600 ~/$tags-lab-info/$tags-default-key.pem
#aws lightsail download-default-key-pair --output text --query publicKeyBase64 > ~/$1-lab-info/$1-default-key.pub
#aws lightsail download-default-key-pair --output text --query privateKeyBase64 > ~/$1-lab-info/$1-default-key.pem
}

### create AWS Lightsail VM
function create-instances(){
local VMname=$1
local tags=$2
local size=$3

sleep 3
aws lightsail create-instances \
  --region ap-southeast-1 \
  --instance-names $VMname \
  --availability-zone ap-southeast-1a \
  --blueprint-id opensuse_15_2 \
  --bundle-id $size \
  --ip-address-type ipv4 \
  --key-pair-name $tags-default-key \
  --user-data "systemctl enable docker;systemctl start docker;hostnamectl set-hostname $VMname;" \
  --tags key=$tags \
  --output table \
  --no-cli-pager
}

#   --user-data "systemctl enable docker;systemctl start docker;hostnamectl set-hostname $VMname;" \
#   cd ~/GitHub/AWS_lightsail
#   --user-data file://cloud-config.txt \
#   --bundle-id nano_2_0 \
#   --bundle-id medium_2_0 \
#   --bundle-id large_2_0 \ 

### chekc if VM provision
function check-instance-state(){
local $tags=$1
mkdir -p ~/$1-lab-info/

get-instances $tags
while :
do
  if grep -q pending ~/$tags-lab-info/$tags-get-instances.txt
  then
    echo 'pending VM provisioning...'
    get-instances $tags
    sleep 5
  else
    echo 'all VM is up and running'
    get-instances $tags
    break
  fi
done
}

### open ports for AWS Lightsail VM
function put-instance-ports(){
local VMname=$1
sleep 1
aws lightsail put-instance-public-ports \
--port-infos \
"fromPort=22,toPort=22,protocol=TCP" \
"fromPort=80,toPort=80,protocol=TCP" \
"fromPort=443,toPort=443,protocol=TCP" \
"fromPort=2376,toPort=2376,protocol=TCP" \
"fromPort=2379,toPort=2380,protocol=TCP" \
"fromPort=6443,toPort=6443,protocol=TCP" \
"fromPort=10250,toPort=10250,protocol=TCP" \
"fromPort=10254,toPort=10254,protocol=TCP" \
"fromPort=30000,toPort=32767,protocol=TCP" \
"fromPort=30000,toPort=32767,protocol=UDP" \
"fromPort=8,toPort=-1,protocol=ICMP" \
--instance-name $VMname --output table --no-cli-pager
}



#storageOS
#"fromPort=5701,toPort=5701,protocol=TCP" \
#"fromPort=5703,toPort=5705,protocol=TCP" \
#"fromPort=5711,toPort=5711,protocol=TCP" \
#"fromPort=25705,toPort=25960,protocol=TCP" \


### get AWS Lightsail instance
function get-instances(){
local tags=$1
aws lightsail get-instances --region ap-southeast-1 \
--query "instances[].{$tags:name,publicIpAddress:publicIpAddress,privateIpAddress:privateIpAddress,state:state.name}" \
--output table --no-cli-pager | grep $tags > ~/$tags-lab-info/$tags-get-instances.txt

}

### ssh command into file
function ssh-file(){
local tags=$1
local VMname=$2
local ip=`aws lightsail get-instance --instance-name $VMname --query 'instance.publicIpAddress' --output text --no-cli-pager`
echo "ssh -i ~/$tags-lab-info/$tags-default-key.pem -o StrictHostKeyChecking=no ec2-user@"$ip > ~/$tags-lab-info/ssh-$VMname.sh
chmod 755 ~/$tags-lab-info/ssh-$VMname.sh
}

### ssh command into file
function html-file(){
local tags=$1
local VMname=$2
local port=$3
local ip=`aws lightsail get-instance --instance-name $VMname --query 'instance.publicIpAddress' --output text --no-cli-pager`

cd ~/$tags-lab-info

cat > "$VMname-port-$port.html" << EOF
<html>
<head>
<meta http-equiv="refresh" content="0; url=http://$ip:$port" />
</head>
</html>
EOF

}

### tar lab folder
function tar-file(){
local tags=$1
cd ~
tar -cvzf $tags-lab-info.tar.gz $tags-lab-info
}


function create-bucket(){
local tags=$1
cd ~

aws lightsail create-bucket \
  --bucket-name $tags-s3-bucket \
  --bundle-id small_1_0 \
  --output table \
  --no-cli-pager > ~/$tags-lab-info/$tags-s3-bucket.txt
sleep 1

sed -i "" '16,$d'  ~/$tags-lab-info/$tags-s3-bucket.txt

aws lightsail create-bucket-access-key \
  --bucket-name $tags-s3-bucket \
  --output table \
  --no-cli-pager > ~/$tags-lab-info/$tags-s3-bucket-accessKeys.txt
sleep 1

sed -i "" '11,$d'  ~/$tags-lab-info/$tags-s3-bucket-accessKeys.txt
}

main $1
