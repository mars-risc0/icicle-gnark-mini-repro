# Use nvidia's base image for Ubuntu
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS cuda-base

# Install basic development tools
RUN apt-get update && apt-get install -yq \
    build-essential \
    clang \
    cmake \
    curl \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Go
ENV GOLANG_VERSION=1.23.0
RUN curl -L https://go.dev/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz | tar -xz -C /usr/local
ENV PATH="/usr/local/go/bin:${PATH}"
RUN go version

# Copy the prover source code we are later going to build
COPY ./circom-compat /circom-compat
WORKDIR /circom-compat

# See whether anything in this container, anywhere, is related to icicle
# We expect to find nothing.
RUN find / -name "*icicle*"

# Update the mod file and download all the dependencies
RUN go mod tidy

# See whether we have any icicle libraries hanging around already
# We expect to find nothing.
RUN find / -name "libicicle*"

# Compile icicle-gnark
RUN go get github.com/ingonyama-zk/icicle-gnark/v3; \
    cd $(go env GOMODCACHE)/github.com/ingonyama-zk/icicle-gnark/v3@v3.2.2/wrappers/golang; \
    /bin/bash build.sh -curve=bn254;

# See where we now have icicle libraries, after building
# We expect:
# /usr/local/lib/libicicle_curve_bn254.so
# /usr/local/lib/libicicle_field_bn254.so
# /usr/local/lib/libicicle_device.so
# /usr/local/lib/backend/cuda/libicicle_backend_cuda_device.so
# /usr/local/lib/backend/bn254/cuda/libicicle_backend_cuda_curve_bn254.so
# /usr/local/lib/backend/bn254/cuda/libicicle_backend_cuda_field_bn254.so
RUN find / -name "libicicle*"

# Export environment variable locating the backend libs
ENV ICICLE_BACKEND_INSTALL_DIR=/usr/local/lib/backend

# Compile the prover, linking it against icicle
RUN go build -tags=icicle /circom-compat/cmd/prover



