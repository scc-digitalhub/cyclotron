FROM node

ARG USER=node
ARG USER_HOME=/home/${USER}

COPY --chown=node:node ./cyclotron-site/ ${USER_HOME}/cyclotron-site/
COPY --chown=node:node ./cyclotron-svc/ ${USER_HOME}/cyclotron-svc/

RUN apt-get update -q && \
    apt-get install supervisor nginx -qy && \
    npm install --global gulp && \
    apt-get clean && \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /root/.cache

WORKDIR ${USER_HOME}
RUN cd ${USER_HOME}/cyclotron-svc && npm install && \
    cd ${USER_HOME}/cyclotron-site && npm install && gulp build && \
    cp ${USER_HOME}/cyclotron-site/nginx.conf /etc/nginx/conf.d/cyclotron-site.conf

ADD supervisord.conf ${USER_HOME}/supervisord.conf
    

EXPOSE 777 8077 8088

CMD ["supervisord", "-c", "supervisord.conf"]
