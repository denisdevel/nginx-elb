#Dockerfile

FROM ubuntu:16.04

MAINTAINER Najar <denis.devel@gmail.com>

RUN echo "deb http://nginx.org/packages/debian/ xenial nginx" | tee  /etc/sources.list && \ 
    apt-get update && \
    apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/* && \
    echo "\ndaemon off;" >> /etc/nginx/nginx.conf

WORKDIR /etc/nginx

EXPOSE 80

CMD ["nginx"]
