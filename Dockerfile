FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles

# Base packages
RUN apt-get update && \
    apt-get install --no-install-recommends -q -y \
      software-properties-common \
      ca-certificates \
      wget \
      ocl-icd-libopencl1 && \
    rm -rf /var/lib/apt/lists/*

# Intel GPU runtimes (release 25.18.33578.6)
RUN mkdir -p /tmp/gpu && cd /tmp/gpu && \
    wget https://github.com/oneapi-src/level-zero/releases/download/v1.22.4/level-zero_1.22.4+u24.04_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.11.7/intel-igc-core-2_2.11.7+19146_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.11.7/intel-igc-opencl-2_2.11.7+19146_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/intel-ocloc-dbgsym_25.18.33578.6-0_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/intel-ocloc_25.18.33578.6-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/intel-opencl-icd_25.18.33578.6-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/libigdgmm12_22.7.0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.18.33578.6/libze-intel-gpu1_25.18.33578.6-0_amd64.deb && \
    dpkg -i *.deb *.ddeb && rm -rf /tmp/gpu

# Install IPEX-LLM Portable Zip (ollama bundle v2.3.0-nightly)
RUN cd / && \
    wget https://github.com/ipex-llm/ipex-llm/releases/download/v2.3.0-nightly/ollama-ipex-llm-2.3.0b20250612-ubuntu.tgz && \
    tar xvf ollama-ipex-llm-2.3.0b20250612-ubuntu.tgz --strip-components=1 -C / && \
    rm ollama-ipex-llm-2.3.0b20250612-ubuntu.tgz

# Clean up any temporary files
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && find /var/log -type f -exec rm -f {} \; \
    && rm -rf /var/log/*-old \
    && rm -rf /var/log/apt/* \
    && rm -rf /var/log/dpkg.log* \
    && rm -rf /var/log/alternatives.log \
    && rm -rf /var/log/installer/* \
    && rm -rf /var/log/unattended-upgrades/* \
    && apt autoremove -y --purge \
    && apt-get autoclean -y \
    && rm -rf /tmp/* /var/tmp/*

# Best practices

# Save model for faster loading
ENV OLLAMA_DEFAULT_KEEPALIVE=6h

# Keep models loaded in memory
ENV OLLAMA_KEEP_ALIVE=24h

# Load models in parallel
ENV OLLAMA_NUM_PARALLEL=1
ENV OLLAMA_MAX_LOADED_MODELS=1

# Set bigger queue and VRAM for better performance
ENV OLLAMA_MAX_QUEUE=512
ENV OLLAMA_MAX_VRAM=0

# Serve ollama on all interfaces
ENV OLLAMA_HOST=0.0.0.0:11434

# Set ollama to use the Intel GPU
ENV OLLAMA_NUM_GPU=999


## # Available low_bit format including sym_int4, sym_int8, fp16 etc.
ENV USE_XETLA=OFF
ENV ZES_ENABLE_SYSMAN=1

# Set ollama to use the Intel GPU
# Set ollama to use the Intel GPU with IPEX-LLM
ENV OLLAMA_USE_IPEX=1
# Set ollama to use the Intel GPU with IPEX-LLM and SYCL
ENV OLLAMA_USE_IPEX_SYCL=1
# Set ollama to use the Intel GPU with IPEX-LLM and SYCL and Level Zero
ENV OLLAMA_USE_IPEX_SYCL_ZE=1
# Set ollama to use the Intel GPU with IPEX-LLM and SYCL and Level Zero and XETLA
ENV OLLAMA_USE_IPEX_SYCL_ZE_XETLA=1

# # Available low_bit format including sym_int4, sym_int8, fp16 etc.
ENV USE_XETLA=OFF
ENV ZES_ENABLE_SYSMAN=1

# Add some intel specific adjustments
#  https://github.com/intel/ipex-llm/blob/main/docs/mddocs/Quickstart/fastchat_quickstart.md

ENV SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
ENV ENABLE_SDP_FUSION=1

# [optional] under most circumstances, the following environment variable may improve performance,
# but sometimes this may also cause performance degradation
ENV SYCL_CACHE_PERSISTENT=1

# For Intel Core™ Ultra Processors (Series 2) with processor number 2xxK or 2xxH (code name Arrow Lake):
#- IPEX_LLM_NPU_ARL=1

# For Intel Core™ Ultra Processors (Series 1) with processor number 1xxH (code name Meteor Lake):
ENV IPEX_LLM_NPU_MTL=1

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
