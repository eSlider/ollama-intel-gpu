# Ollama for Intel GPU (SYCL)

> Run LLMs on Intel GPUs at full speed — no NVIDIA required.

A Docker-based setup that pairs [Ollama](https://github.com/ollama/ollama) **v0.15.6** with a custom-built **SYCL backend** for Intel GPU acceleration, plus [Open WebUI](https://github.com/open-webui/open-webui) for a browser chat interface. Three commands to go from zero to local AI.

**Why this exists:** Ollama's official release ships only a Vulkan backend for Intel GPUs, leaving significant performance on the table. This repo builds the `ggml-sycl` backend from source with Intel oneAPI, unlocking oneMKL, oneDNN, and Level-Zero direct GPU access.


---

## Quick start

### Option A: Build from source

```shell
git clone https://github.com/mattcurf/ollama-intel-gpu
cd ollama-intel-gpu
docker compose up
```

The first `docker compose up` builds the SYCL backend from source (~2 min on a modern CPU). Subsequent starts are instant.

### Option B: Use the pre-built image

```shell
docker run -d \
  --device /dev/dri:/dev/dri \
  --shm-size 16G \
  -p 11434:11434 \
  -v ollama-data:/root/.ollama \
  ghcr.io/mattcurf/ollama-intel-gpu:latest
```

Open **http://localhost:3000** (with WebUI) or use the API directly at `http://localhost:11434`.

> **Multiple GPUs?** Set `ONEAPI_DEVICE_SELECTOR=level_zero:0` in `docker-compose.yml` to pick the right device.

---

## Tested hardware

| Intel GPU | Status |
|-----------|--------|
| Core Ultra 7 155H integrated Arc (Meteor Lake) | Verified |
| Arc A-series (A770, A750, A380) | Expected compatible |
| Data Center Flex / Max | Expected compatible |

**Requirements:** Ubuntu 24.04+, Docker with Compose, Intel GPU with Level-Zero driver support.

---

## SYCL vs Vulkan performance

Both backends run on Intel GPUs. This repo defaults to SYCL for the speed advantage.

| Intel GPU | Vulkan | SYCL | Gain |
|---|---|---|---|
| MTL iGPU (155H) | ~8-11 tok/s | **~16 tok/s** | +45-100% |
| ARL-H iGPU | ~10-12 tok/s | **~17 tok/s** | +40-70% |
| Arc A770 | ~30-35 tok/s | **~55 tok/s** | +57-83% |
| Flex 170 | ~30-35 tok/s | **~50 tok/s** | +43-67% |
| Data Center Max 1550 | — | **~73 tok/s** | — |

*Benchmarks: llama-2-7b Q4_0, llama.cpp, community-reported.*

**What makes SYCL faster:**

- **oneMKL / oneDNN** — Intel's optimized math and neural network libraries
- **Level-Zero** — direct GPU communication, lower overhead than Vulkan
- **Intel-tuned kernels** — MUL_MAT hand-optimized per architecture (MTL, ARL, Arc, Flex, PVC)

**When Vulkan makes sense:** no build step, cross-vendor support (AMD/NVIDIA), smaller image. Use the official Ollama Docker image with `OLLAMA_VULKAN=1`.

---

## How it works

Ollama ships the `ggml-sycl.h` header but intentionally excludes the SYCL implementation from its vendored ggml. This repo fills that gap:

```
┌─────────────────────────────────────────────────────────┐
│  Stage 1: Build  (intel/oneapi-basekit:2025.1.1)        │
│                                                         │
│  ollama v0.15.6 source ──┐                              │
│                          ├── cmake + icpx ── libggml-sycl.so
│  ggml-sycl @ a5bb8ba4 ──┘                               │
│        ▲                                                │
│        └── patch-sycl.py (2 API fixes)                  │
├─────────────────────────────────────────────────────────┤
│  Stage 2: Runtime  (ubuntu:24.04)                       │
│                                                         │
│  ollama binary (official v0.15.6)                       │
│  + libggml-sycl.so + oneAPI runtime libs                │
│  + Intel GPU drivers (Level-Zero, IGC, compute-runtime) │
│  + Open WebUI (separate container)                      │
└─────────────────────────────────────────────────────────┘
```

The `ggml-sycl` source is fetched from the **exact llama.cpp commit** (`a5bb8ba4`) that ollama vendors, ensuring ABI compatibility. Two small patches are applied by `patch-sycl.py`:

1. **`graph_compute` signature** — ollama adds an `int batch_size` parameter not present upstream
2. **`GGML_TENSOR_FLAG_COMPUTE` removal** — ollama drops this enum; without the patch, every compute node gets skipped, producing garbage output

---

## Configuration

Environment variables in `docker-compose.yml`:

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_HOST` | `0.0.0.0` | Listen address |
| `OLLAMA_KEEP_ALIVE` | `24h` | How long models stay loaded in memory |
| `OLLAMA_NUM_PARALLEL` | `1` | Concurrent request slots |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models in VRAM simultaneously |
| `ONEAPI_DEVICE_SELECTOR` | `level_zero:0` | Which Intel GPU to use |
| `ZES_ENABLE_SYSMAN` | `1` | Enable Level-Zero system management |
| `OLLAMA_DEBUG` | `1` | Verbose logging (disable in production) |

---

## Project structure

```
.
├── Dockerfile           # Multi-stage build: oneAPI SYCL → minimal runtime
├── docker-compose.yml   # ollama + Open WebUI services
├── patch-sycl.py        # Patches ggml-sycl for ollama API compatibility
├── start-ollama.sh      # Custom entrypoint (legacy, from IPEX-LLM era)
└── doc/
    └── screenshot.png
```

---

## Troubleshooting

**SYCL device not detected** — Ensure `/dev/dri` is accessible. Check `docker compose logs ollama-intel-gpu` for `SYCL0` in the device list.

**"failed to sample token"** — Usually means an ABI mismatch between ggml-sycl and ollama's vendored ggml. The `GGML_COMMIT` ARG in the Dockerfile must match the ggml version ollama vendors.

**Model too large for VRAM** — Intel integrated GPUs share system memory. Increase `shm_size` in `docker-compose.yml` or use a smaller quantization (Q4_0, Q4_K_M).

**Slow first inference** — SYCL JIT-compiles GPU kernels on first run. Subsequent inferences are faster.

---

## References

- [Ollama](https://github.com/ollama/ollama)
- [Open WebUI](https://github.com/open-webui/open-webui)
- [llama.cpp SYCL backend](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md)
- [Intel oneAPI base toolkit](https://www.intel.com/content/www/us/en/developer/tools/oneapi/base-toolkit.html)
- [Intel GPU driver installation](https://dgpu-docs.intel.com/driver/client/overview.html)

---

## License

See [LICENSE](LICENSE) for details.
