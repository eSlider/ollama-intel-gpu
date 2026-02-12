# Ollama for Intel GPU

[![GitHub license](https://img.shields.io/github/license/mattcurf/ollama-intel-gpu)](

Run LLM models on your local Intel GPU using Ollama with Docker.
Includes [Open WebUI](https://github.com/open-webui/open-webui) for a
browser-based chat interface.

## Screenshot

![screenshot](doc/screenshot.png)

## Prerequisites

* Ubuntu 24.04 or newer
* Docker and Docker Compose
* Intel GPU (tested with Intel Core Ultra 7 155H integrated Arc Graphics — Meteor Lake)

## Quick start

```shell
git clone https://github.com/mattcurf/ollama-intel-gpu
cd ollama-intel-gpu
docker compose up
```

Then open http://localhost:3000 in your browser.

> If you have multiple GPUs (integrated + discrete), set
> `ONEAPI_DEVICE_SELECTOR=level_zero:0` in the docker-compose environment
> to select the intended device.

## GPU backend: SYCL vs Vulkan

Ollama can accelerate inference on Intel GPUs via two backends.
This repo defaults to **SYCL** (built from upstream llama.cpp's ggml-sycl
with Intel oneAPI) for best Intel GPU performance.

### Performance comparison (llama-2-7b Q4_0, llama.cpp benchmarks)

| Intel GPU | Vulkan tok/s | SYCL tok/s | SYCL advantage |
|---------------------|-------------|------------|----------------|
| MTL iGPU (155H) | ~8-11 | **16** | +45-100% |
| ARL-H iGPU | ~10-12 | **17** | +40-70% |
| Arc A770 | ~30-35 | **55** | +57-83% |
| Flex 170 | ~30-35 | **50** | +43-67% |
| Data Center Max 1550| — | **73** | — |

### Why SYCL is faster

* **oneDNN** — Intel's Deep Neural Network Library for optimized GEMM (matrix multiply)
* **oneMKL** — Intel Math Kernel Library for optimized math operations
* **Level-zero direct access** — lower-overhead GPU communication than Vulkan
* **Intel-specific MUL_MAT kernels** — hand-tuned for MTL, ARL, Arc, Flex, PVC architectures
* **FP16 compute path** — optional `GGML_SYCL_F16=ON` for faster compute
* **Multi-GPU support** — `--split-mode layer` across multiple Intel GPUs

### Why you might still use Vulkan

* Shipped in official ollama releases — no build step required
* Cross-vendor (Intel, AMD, NVIDIA)
* Simpler deployment, smaller image

To switch to Vulkan, see the `Dockerfile.vulkan` (if provided) or use the
official ollama Docker image with `OLLAMA_VULKAN=1`.

## Architecture

The Docker image builds in two stages:

1. **Build stage** (`intel/oneapi-basekit:2025.1.1`) — clones ollama v0.15.6
   source, fetches the matching `ggml-sycl` backend from upstream llama.cpp
   (commit `a5bb8ba4`, the exact ggml version ollama vendors), patches two
   ollama-specific API divergences (`batch_size` parameter, `GGML_TENSOR_FLAG_COMPUTE`
   removal), and compiles `libggml-sycl.so` with `icpx` + oneAPI.
2. **Runtime stage** (`ubuntu:24.04`) — minimal image with Intel GPU drivers,
   the official ollama binary, and the SYCL runner + oneAPI runtime libraries.

### Key components

| Component | Source | Purpose |
|-----------|--------|---------|
| ollama binary | Official v0.15.6 release | Go server, API, model management |
| ggml-sycl backend | llama.cpp @ `a5bb8ba4` | `libggml-sycl.so` compiled with oneAPI |
| oneAPI runtime | Intel oneAPI 2025.1.1 | SYCL runtime, oneMKL, oneDNN, TBB |
| GPU drivers | Intel compute-runtime 26.05 | Level-zero, IGC, OpenCL ICD |
| patch-sycl.py | This repo | Patches ggml-sycl for ollama API compat |
| Web UI | Open WebUI | Browser-based chat interface |

## Configuration

Key environment variables in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `0.0.0.0` | Listen address |
| `OLLAMA_KEEP_ALIVE` | `24h` | Keep models loaded in memory |
| `OLLAMA_NUM_PARALLEL` | `1` | Parallel request handling |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models in memory |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:0` | Select Intel GPU device |

## How the SYCL build works

Ollama intentionally excludes `ggml-sycl` from its vendored ggml source tree
(it keeps the header `ggml-sycl.h` but not the implementation). This repo
rebuilds it by:

1. Cloning the ollama source (for the ggml build system and headers)
2. Fetching `ggml-sycl` from the **exact llama.cpp commit** that ollama
   vendors (`a5bb8ba4`) to ensure ABI compatibility
3. Applying two patches via `patch-sycl.py`:
   - **`graph_compute` signature**: ollama adds an `int batch_size` parameter
   - **`GGML_TENSOR_FLAG_COMPUTE`**: ollama removes this enum value, so the
     skip-check in the compute loop must be removed (otherwise ALL nodes
     get skipped, producing garbage output)
4. Building with Intel oneAPI `icpx` compiler, linking oneMKL and oneDNN

## References

* [Intel GPU driver installation](https://dgpu-docs.intel.com/driver/client/overview.html)
* [llama.cpp SYCL backend docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md)
* [Intel oneAPI base toolkit](https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit.html)
* [ollama GitHub](https://github.com/ollama/ollama)
* [Open WebUI](https://github.com/open-webui/open-webui)
