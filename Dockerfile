# FROM debian:bookworm-slim

# # Set the working directory
# WORKDIR /mailcow-dockerized

# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#     git \
#     openssl \
#     curl \
#     gawk \
#     coreutils \
#     grep \
#     nano \
#     jq \
#     ca-certificates && \
#     rm -rf /var/lib/apt/lists/*

# # Install Docker
# RUN curl -fsSL https://get.docker.com | sh

# # Clone the mailcow-dockerized repository
# RUN git clone https://github.com/mailcow/mailcow-dockerized.git .
# RUN mkdir /mailcow-dockerized/data/assets/ssl/

# # Copy the mailcow_cert_renewal.sh file into the container
# COPY mailcow_cert_renewal.sh .
# RUN chmod +x /mailcow-dockerized/mailcow_cert_renewal.sh

# CMD ["/bin/bash"]





FROM alpine:3.22

# Set the working directory for all subsequent commands.
WORKDIR /opt/mailcow-dockerized

# --- Install System Packages, Docker, and Tools ---
RUN apk add --no-cache --upgrade \
    bash \
    coreutils \
    curl \
    docker \
    docker-cli-compose \
    findutils \
    gawk \
    git \
    grep \
    jq \
    nano \
    openssl \
    sed

# Clone the mailcow-dockerized repository into the current directory (/opt/mailcow-dockerized).
RUN git clone https://github.com/mailcow/mailcow-dockerized.git .

# Create the directory for SSL certificates as a prerequisite.
RUN mkdir -p /opt/mailcow-dockerized/data/assets/ssl/

# Copy your custom renewal script from the build context (your local directory)
COPY mailcow_cert_renewal.sh .

# Make the renewal script executable.
RUN chmod +x /opt/mailcow-dockerized/mailcow_cert_renewal.sh

CMD ["/bin/bash"]
