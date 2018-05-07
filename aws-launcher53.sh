#!/bin/bash

ROUTE53_INSTANCE_NAME='nginx.cluster-2.co.uk'

#create instances
ecs-cli  up --keypair main --capability-iam --size 2 --instance-type t2.micro --force

#build docker image
docker build -t 653152952980.dkr.ecr.us-east-1.amazonaws.com/ubuntu-nginx:latest .

#create aws registry
aws ecr create-repository --repository-name ubuntu-nginx

#push image to the aws registry
ecs-cli push 653152952980.dkr.ecr.us-east-1.amazonaws.com/ubuntu-nginx

#create task
aws ecs register-task-definition --cli-input-json file://nginx-task.json

aws ecs run-task --task-definition nginx --cluster nginx2 --count 2

#get subnets from running ecs instances
SUBNET1=`aws ec2 describe-instances --filters "Name=tag:Name, Values=nginx1" | grep SubnetId | cut -d ":" -f 2 | sed 'n;d;' | tr '\n' ' ' | tr --delete , | tr --delete \"`
SUBNET2=`aws ec2 describe-instances --filters "Name=tag:Name, Values=nginx2" | grep SubnetId | cut -d ":" -f 2 | sed 'n;d;' | tr '\n' ' ' | tr --delete , | tr --delete \"`
echo $SUBNET1
echo $SUBNET2

#get  security group
SECURITY_GROUPS=`aws ec2 describe-security-groups --filters Name=group-name,Values='*ecs*' --query 'SecurityGroups[*].{ID:GroupId}' | sed -n '3p' | cut -d ":" -f 2 | tr --delete \"`
#echo $SECURITY_GROUPS

INSTANCE1=`aws ec2 describe-instances --filters "Name=tag:Name, Values=nginx1" | grep -i instanceId | cut -d ":" -f 2 | tr --delete \" | tr --delete , | tr '\n' ' '`
#echo $INSTANCE1
INSTANCE2=`aws ec2 describe-instances --filters "Name=tag:Name, Values=nginx2" | grep -i instanceId | cut -d ":" -f 2 | tr --delete \" | tr --delete , | tr '\n' ' '`
#echo $INSTANCE2

#create load balancer and store dns name in special variable for further checking actions
BALANCER_DNS_NAME1=`aws elb create-load-balancer --load-balancer-name nginx-elb1 --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $SUBNET1 --security-groups $SECURITY_GROUPS`
BALANCER_DNS_NAME2=`aws elb create-load-balancer --load-balancer-name nginx-elb2 --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $SUBNET2 --security-groups $SECURITY_GROUPS`

#register instances in load balancer
aws elb register-instances-with-load-balancer --load-balancer-name nginx-elb1 --instances $INSTANCE1
aws elb register-instances-with-load-balancer --load-balancer-name nginx-elb2 --instances $INSTANCE2

#try to check that ELB working properly
STRIPED_BALANCER_DNS_NAME1=`echo $BALANCER_DNS_NAME1 | grep -i dns | cut -d ":" -f 2 | tr --delete } | tr --delete \"`
STRIPED_BALANCER_DNS_NAME2=`echo $BALANCER_DNS_NAME2 | grep -i dns | cut -d ":" -f 2 | tr --delete } | tr --delete \"`
echo $STRIPED_BALANCER_DNS_NAME1
echo $STRIPED_BALANCER_DNS_NAME2
#create Route53 traffic policy json-file
sed -i "s/elb1/$STRIPED_BALANCER_DNS_NAME1/g" ./traffic-policy-failover.json
sed -i "s/elb2/$STRIPED_BALANCER_DNS_NAME2/g" ./traffic-policy-failover.json

#create active-passive scheme policy
aws route53 create-traffic-policy --name nginx-failover --document file://traffic-policy-failover.json

TRAFFIC_POLICY=`aws route53 list-traffic-policies | grep Id | cut -d ":" -f 2 | tr --delete \" | tr --delete \,`
echo $TRAFFIC_POLICY

HOSTED_ZONE=`aws route53 list-hosted-zones | grep Id | cut -d ":" -f 2 | tr --delete \" | tr --delete \,`
echo $HOSTED_ZONE

#create instance nginx.cluster-2.co.uk
aws route53 create-traffic-policy-instance --hosted-zone-id $HOSTED_ZONE --name $ROUTE53_INSTANCE_NAME --ttl 3600 --traffic-policy-id $TRAFFIC_POLICY --traffic-policy-version 1

for (( a = 1; a < 25; a++ ))
        do
                ANSWER=`curl $ROUTE53_INSTANCE_NAME 2>&1`
                echo $ANSWER
                if [[ $ANSWER = *"Welcome to nginx"* ]]; then
                        echo "test passed successfully"
                        break
                else
                        echo "trying to check again"
                        sleep 6
                fi
        done


#set traffic policy file to initial state
#sed -i "s/$STRIPED_BALANCER_DNS_NAME1/elb1/g" ./traffic-policy-failover.json
#sed -i "s/$STRIPED_BALANCER_DNS_NAME2/elb2/g" ./traffic-policy-failover.json
