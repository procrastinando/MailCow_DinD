FROM docker:28.4-dind
# FROM docker:dind

# Set a working directory inside the image
WORKDIR /opt/mailcow-dockerized

# Update Alpine Linux's package index and install all required packages
# The 'docker' and 'docker-cli-compose' tools are already part of the base image.
RUN apk update && apk add --no-cache \
    bash \
    coreutils \
    curl \
    findutils \
    gawk \
    git \
    grep \
    jq \
    nano \
    openssl \
    sed

# Clone the mailcow repository into the working directory
RUN git clone https://github.com/mailcow/mailcow-dockerized.git .
# Copy your custom renewal script from the build context (your local directory)
COPY mailcow_cert_renewal.sh .
# Make the renewal script executable.
RUN chmod +x /opt/mailcow-dockerized/mailcow_cert_renewal.sh

CMD ["dockerd-entrypoint.sh"]