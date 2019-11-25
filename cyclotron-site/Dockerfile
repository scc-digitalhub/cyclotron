FROM node:11.15-alpine as build
COPY . /tmp/cyclotron-site
RUN apk add --no-cache git
RUN npm install --global gulp
WORKDIR /tmp/cyclotron-site
RUN npm install
RUN gulp build

FROM nginx:alpine
# ARG VER=0.1
ARG USER=cyclotron
ARG USER_ID=3010
ARG USER_GROUP=cyclotron
ARG USER_GROUP_ID=3010
ARG USER_HOME=/home/${USER}
# RUN npm install --global gulp
# create a user group and a user
RUN  addgroup -g ${USER_GROUP_ID} ${USER_GROUP}; \
     adduser -u ${USER_ID} -D -g '' -h ${USER_HOME} -G ${USER_GROUP} ${USER} ;

COPY --chown=cyclotron:cyclotron --from=build /tmp/cyclotron-site/_public/ /usr/share/nginx/html
COPY nginx-docker.conf /etc/nginx/nginx.conf
WORKDIR ${USER_HOME}/cyclotron-site
#ENTRYPOINT ["/usr/local/bin/gulp","webserver"]
