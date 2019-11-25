FROM node:lts-alpine
ARG VER=0.1
ARG USER=cyclotron
ARG USER_ID=3010
ARG USER_GROUP=cyclotron
ARG USER_GROUP_ID=3010
ARG USER_HOME=/home/${USER}
# create a user group and a user
RUN  addgroup -g ${USER_GROUP_ID} ${USER_GROUP}; \
     adduser -u ${USER_ID} -D -g '' -h ${USER_HOME} -G ${USER_GROUP} ${USER} ;

COPY --chown=cyclotron:cyclotron . ${USER_HOME}/cyclotron-svc
USER cyclotron
WORKDIR ${USER_HOME}/cyclotron-svc
RUN npm install 
ENTRYPOINT ["/usr/local/bin/node","app.js"]
