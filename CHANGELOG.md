# Changelog

## 2026-02-12

### Fix: Ollama not reachable from host via Docker port mapping

The bundled IPEX-LLM `/start-ollama.sh` entrypoint hardcodes
`OLLAMA_HOST='127.0.0.1:11434'` and `OLLAMA_KEEP_ALIVE=10m`, overriding any
values set through Docker Compose environment variables.

- Added a custom `start-ollama.sh` that respects environment variables
  (`${OLLAMA_HOST:-0.0.0.0:11434}`, `${OLLAMA_KEEP_ALIVE:-24h}`) instead of
  hardcoding them
- Mounted the script into the container as a read-only volume
  (`./start-ollama.sh:/start-ollama.sh:ro`)
- Fixed `LD_LIBRARY_PATH` env var syntax in docker-compose.yml (`:` -> `=`)

### Updated Intel GPU runtime stack to latest releases

- **level-zero**: v1.22.4 -> v1.28.0
  - Loader based on oneAPI Level Zero Specification v1.15.31
  - Memory leak fixes, expanded multidriver teardown support
- **intel-graphics-compiler (IGC)**: v2.11.7 (build 19146) -> v2.28.4 (build 20760)
  - Built with LLVM 16.0.6, opaque pointers support
- **compute-runtime**: 25.18.33578.6 -> 26.05.37020.3
  - Built with IGC v2.28.4 and level-zero v1.27.0
  - Panther Lake production support, Wildcat Lake pre-release
- **libigdgmm**: 22.7.0 -> 22.9.0
- **ipex-llm ollama** (nightly): 2.3.0b20250612 -> 2.3.0b20250725
  - Latest available nightly Ubuntu ollama portable zip

### Docker Compose adjustments

- Disabled persistent webui volume for stateless restarts
- Disabled web UI authentication (`WEBUI_AUTH=False`)

### README

- Formatting and heading structure improvements
- Updated tested GPU model to Intel Core Ultra 5 155H
