FROM debian:bookworm-slim

# Set the working directory
WORKDIR /mailcow-dockerized

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    jq \
    curl \
    git \
    cron \
    nano \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Docker
RUN curl -fsSL https://get.docker.com | sh

# Clone the mailcow-dockerized repository
RUN git clone https://github.com/mailcow/mailcow-dockerized.git .

# Copy the mailcow_cert_renewal.sh file into the container
COPY mailcow_cert_renewal.sh .
RUN chmod +x /mailcow-dockerized/mailcow_cert_renewal.sh


CMD ["/bin/bash"]
