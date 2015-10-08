# Dockerfile for the PDC's Gateway service, part of an Endpoint deployment
#
#
# Modify default settings at runtime with environment files and/or variables.
# - Set Gateway ID#: -e gID=####
# - Set Hub IP addr: -e IP_HUB=#.#.#.#
# - Use an env file: --env-file=/path/to/file.env
#
# Samples at https://github.com/physiciansdatacollaborative/endpoint.git


# Base image
#
FROM phusion/passenger-ruby19
MAINTAINER derek.roberts@gmail.com


# Update system and packages
#
ENV DEBIAN_FRONTEND noninteractive
RUN echo 'Dpkg::Options{ "--force-confdef"; "--force-confold" }' \
      >> /etc/apt/apt.conf.d/local; \
    apt-get update; \
    apt-get install -y \
      autossh \
      git; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Prepare /app/ folder
#
WORKDIR /app/
#RUN git clone https://github.com/physiciansdatacollaborative/endpoint.git -b dev .; \
COPY . .
RUN mkdir -p ./tmp/pids ./util/files; \
    gem install multipart-post; \
    sed -i -e "s/localhost:27017/database:27017/" config/mongoid.yml; \
    chown -R app:app /app/; \
    /sbin/setuser app bundle install --path vendor/bundle


# Create AutoSSH User
#
RUN adduser --disabled-password --gecos '' --home /home/autossh autossh; \
    chown -R autossh:autossh /home/autossh


# Startup script for Gateway tunnel
#
RUN SRV=autossh; \
    mkdir -p /etc/service/${SRV}/; \
    ( \
      echo "#!/bin/bash"; \
      echo ""; \
      echo ""; \
      echo "# Set variable defaults"; \
      echo "#"; \
      echo "gID=\${gID:-0}"; \
      echo "IP_HUB=\${IP_HUB:-10.0.2.2}"; \
      echo "PORT_AUTOSSH=\${PORT_AUTOSSH:-22}"; \
      echo "PORT_START_GATEWAY=\${PORT_START_GATEWAY:-40000}"; \
      echo ""; \
      echo ""; \
      echo "# Start tunnels"; \
      echo "#"; \
      echo "export AUTOSSH_PIDFILE=/home/autossh/autossh_gateway.pid"; \
      echo "PORT_REMOTE=\`expr \${PORT_START_GATEWAY} + \${gID}\`"; \
      echo "#"; \
      echo "sleep 30"; \
      echo "chown -R autossh:autossh /home/autossh"; \
      echo "exec /sbin/setuser autossh /usr/bin/autossh -M0 -p \${PORT_AUTOSSH} -N -R \\"; \
      echo "  \${PORT_REMOTE}:localhost:3001 autossh@\${IP_HUB} -o ServerAliveInterval=15 \\"; \
      echo "  -o ServerAliveCountMax=3 -o Protocol=2 -o ExitOnForwardFailure=yes -v"; \
    )  \
      >> /etc/service/${SRV}/run; \
    chmod +x /etc/service/${SRV}/run


# Startup script for Gateway app
#
RUN SRV=app; \
    mkdir -p /etc/service/${SRV}/; \
    ( \
      echo "#!/bin/bash"; \
      echo ""; \
      echo ""; \
      echo "# Start Endpoint"; \
      echo "#"; \
      echo "sleep 15"; \
      echo "cd /app/"; \
      echo "/sbin/setuser app bundle exec script/delayed_job stop"; \
      echo "/sbin/setuser app bundle exec script/delayed_job start"; \
      echo "exec /sbin/setuser app bundle exec rails server -p 3001"; \
    )  \
      >> /etc/service/${SRV}/run; \
    chmod +x /etc/service/${SRV}/run


# Run initialization command
#
CMD ["/sbin/my_init"]
