#!/bin/bash

var="bla-bla-bla"
#create Route53 traffic policy file
sed -i "s/elb1/$var/g" ./traffic-policy.json


