#!/bin/bash

#create instances
#ecs-cli  up --keypair main --capability-iam --size 2 --instance-type t2.micro --force

#build docker image
#docker build -t 653152952980.dkr.ecr.us-east-1.amazonaws.com/ubuntu-nginx:latest .

#create aws registry
#aws ecr create-repository --repository-name ubuntu-nginx

#push image to the aws registry
#ecs-cli push 653152952980.dkr.ecr.us-east-1.amazonaws.com/ubuntu-nginx

#create task
#aws ecs register-task-definition --cli-input-json file://nginx-task.json

#aws ecs run-task --task-definition nginx --cluster nginx2 --count 2

#get subnets from running ecs instances
SUBNETS=`aws ec2 describe-instances --filters "Name=tag:Name, Values=ECS Instance - amazon-ecs-cli-setup-nginx2" | grep SubnetId | cut -d ":" -f 2 | sed 'n;d;' | tr '\n' ' ' | tr --delete , | tr --delete \"`
echo $SUBNETS

#get  security group
SECURITY_GROUPS=`aws ec2 describe-security-groups --filters Name=group-name,Values='*ecs*' --query 'SecurityGroups[*].{ID:GroupId}' | sed -n '3p' | cut -d ":" -f 2 | tr --delete \"`
echo $SECURITY_GROUPS

INSTANCES=`aws ec2 describe-instances --filters "Name=tag:Name, Values=ECS Instance - amazon-ecs-cli-setup-nginx2" | grep -i instanceId | cut -d ":" -f 2 | tr --delete \" | tr --delete , | tr '\n' ' '`
echo $INSTANCES

#create load balancer and store dns name in special variable for further checking actions
BALANCER_DNS_NAME=`aws elb create-load-balancer --load-balancer-name nginx-elb --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $SUBNETS --security-groups $SECURITY_GROUPS`


#register instances in load balancer
aws elb register-instances-with-load-balancer --load-balancer-name nginx-elb --instances $INSTANCES

#try to check that ELB working properly
CLEAR_BALANCER_DNS_NAME=`echo $BALANCER_DNS_NAME | grep -i dns | cut -d ":" -f 2 | tr --delete } | tr --delete \"`

#waiting for A-record and check tcp/80 port
for (( a = 1; a < 25; a++ ))
	do
		ANSWER=`curl $CLEAR_BALANCER_DNS_NAME 2>&1`
		echo $ANSWER
		if [[ $ANSWER = *"Welcome to nginx"* ]]; then
		        echo "test passed successfully"	
			break
		else
			echo "trying to check again"
			sleep 6
		fi
	done

