FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles

# Base packages + Intel Vulkan ICD (ANV driver)
RUN apt-get update && \
    apt-get install --no-install-recommends -q -y \
      ca-certificates \
      wget \
      zstd \
      mesa-vulkan-drivers \
      ocl-icd-libopencl1 && \
    rm -rf /var/lib/apt/lists/*

# Intel GPU runtimes (release 26.05.37020.3)
# Provides level-zero, IGC, compute-runtime for Intel GPU kernel support
RUN mkdir -p /tmp/gpu && cd /tmp/gpu && \
    wget https://github.com/oneapi-src/level-zero/releases/download/v1.28.0/level-zero_1.28.0+u24.04_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.28.4/intel-igc-core-2_2.28.4+20760_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.28.4/intel-igc-opencl-2_2.28.4+20760_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.05.37020.3/intel-ocloc-dbgsym_26.05.37020.3-0_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.05.37020.3/intel-ocloc_26.05.37020.3-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.05.37020.3/intel-opencl-icd_26.05.37020.3-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.05.37020.3/libigdgmm12_22.9.0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/26.05.37020.3/libze-intel-gpu1_26.05.37020.3-0_amd64.deb && \
    dpkg -i *.deb *.ddeb && rm -rf /tmp/gpu

# Install official ollama (Vulkan runner provides Intel GPU acceleration)
ARG OLLAMA_VERSION=0.15.6
RUN wget -qO- "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" | \
    zstd -d | tar -xf - -C /usr && \
    # Remove CUDA and MLX runners — we only need CPU + Vulkan
    rm -rf /usr/lib/ollama/cuda_* /usr/lib/ollama/mlx_*

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get autoremove -y --purge 2>/dev/null; \
    apt-get autoclean -y 2>/dev/null; true

# Serve ollama on all interfaces
ENV OLLAMA_HOST=0.0.0.0:11434

# Keep models loaded in memory
ENV OLLAMA_KEEP_ALIVE=24h
ENV OLLAMA_DEFAULT_KEEPALIVE=6h

# Concurrency and resource limits
ENV OLLAMA_NUM_PARALLEL=1
ENV OLLAMA_MAX_LOADED_MODELS=1
ENV OLLAMA_MAX_QUEUE=512
ENV OLLAMA_MAX_VRAM=0

# Enable Vulkan backend for Intel GPU acceleration
ENV OLLAMA_VULKAN=1

# Use all GPU layers
ENV OLLAMA_NUM_GPU=999

# Intel GPU tuning
ENV ZES_ENABLE_SYSMAN=1

# For Intel Core Ultra Processors (Series 1), code name Meteor Lake
ENV IPEX_LLM_NPU_MTL=1

EXPOSE 11434
ENTRYPOINT ["/usr/bin/ollama"]
CMD ["serve"]
