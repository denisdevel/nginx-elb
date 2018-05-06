#!/bin/bash

/usr/local/bin/docker-machine env opsworks
eval $(/usr/local/bin/docker-machine env opsworks)

echo " try to remove all containers"
for i in `docker ps -a | sed -e s/\ // | awk '{print $1}'i | sed -n '2,$p'`;do docker rm -f $i; done && 

echo "get last image"
docker pull najar/nginx

echo "running docker container"
docker run -d -p 80:80 najar/nginx

