# Changelog

## 2026-02-12 — Switch to SYCL backend

### GPU backend: Vulkan -> SYCL

- Replaced Vulkan GPU backend with custom-built SYCL backend for ~2x inference
  speed on Intel GPUs
- Multi-stage Dockerfile: builds `libggml-sycl.so` from upstream llama.cpp
  (commit `a5bb8ba4`) using Intel oneAPI 2025.1.1
- Added `patch-sycl.py` to fix two ollama-specific API divergences:
  - `graph_compute` signature (`int batch_size` parameter)
  - `GGML_TENSOR_FLAG_COMPUTE` removal (critical — without this patch all
    compute nodes are skipped, producing garbage output)
- Bundled oneAPI runtime libraries (SYCL, oneMKL, oneDNN, TBB, Level-Zero)
  into the runtime image

### Ollama upgrade: 0.9.3 -> 0.15.6

- Upgraded from IPEX-LLM bundled ollama 0.9.3 to official ollama v0.15.6
- Switched from IPEX-LLM portable zip to official ollama binary
- Removed CUDA/MLX/Vulkan runners from image to reduce size

### Intel GPU runtime stack

- **level-zero**: v1.22.4 -> v1.28.0
- **intel-graphics-compiler (IGC)**: v2.11.7 -> v2.28.4
- **compute-runtime**: 25.18.33578.6 -> 26.05.37020.3
- **libigdgmm**: 22.7.0 -> 22.9.0

### Docker Compose

- Device mapping changed to full `/dev/dri` access for SYCL/Level-Zero
- Added `ONEAPI_DEVICE_SELECTOR=level_zero:0` and `ZES_ENABLE_SYSMAN=1`
- Removed `OLLAMA_VULKAN=1`
- Disabled web UI authentication (`WEBUI_AUTH=False`)
