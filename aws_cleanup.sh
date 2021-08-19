#!/bin/bash -ex

### delete AWS Lightsail VM
function delete-instance(){

local tags=$1
rm -f ~/$tags-lab-info/*
rm -f ~/$tags-lab-info.tar.gz
rmdir ~/$tags-lab-info

aws lightsail delete-key-pair --key-pair-name $tags-default-key --output text --no-cli-pager

aws lightsail delete-instance --region ap-southeast-1  --instance-name $tags-rancher --output text --no-cli-pager

aws lightsail delete-instance --region ap-southeast-1  --instance-name $tags-rke-m1 --output text --no-cli-pager

aws lightsail delete-instance --region ap-southeast-1  --instance-name $tags-rke-w1 --output text --no-cli-pager

aws lightsail delete-instance --region ap-southeast-1  --instance-name $tags-rke-w2 --output text --no-cli-pager

aws lightsail delete-instance --region ap-southeast-1  --instance-name $tags-rke-w3 --output text --no-cli-pager
}

delete-instance $1
