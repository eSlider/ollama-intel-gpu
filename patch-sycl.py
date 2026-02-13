#!/usr/bin/env python3
"""
Patch upstream ggml-sycl to match ollama's modified ggml backend API.

ollama v0.15.6 vendors ggml from llama.cpp commit a5bb8ba4 but makes two
divergences from upstream:

1. graph_compute() has an extra 'int batch_size' parameter (ollama addition)
2. GGML_TENSOR_FLAG_COMPUTE enum value is removed from ollama's ggml.h,
   so the skip-check in the compute loop must be removed entirely
"""

import re
import sys

path = sys.argv[1]
with open(path, "r") as f:
    src = f.read()

original = src

# 1. Fix graph_compute signature: add 'int batch_size' parameter
# The function is defined as:
#   static ggml_status ggml_backend_sycl_graph_compute(ggml_backend_t backend, ggml_cgraph * cgraph) {
src = re.sub(
    r'(static\s+(?:enum\s+)?ggml_status\s+ggml_backend_sycl_graph_compute\s*\([^)]*cgraph)\s*\)',
    r'\1, int batch_size)',
    src,
)

# 2. Add GGML_UNUSED(batch_size) inside the function body (after the opening brace)
src = re.sub(
    r'(ggml_backend_sycl_graph_compute\([^)]*int\s+batch_size\)\s*\{)',
    r'\1\n    GGML_UNUSED(batch_size);',
    src,
)

# 3. Remove GGML_TENSOR_FLAG_COMPUTE skip-check entirely.
# In ollama's vendored ggml, this flag doesn't exist (removed from the enum).
# Since ollama never sets bit 16, ALL nodes would be skipped, producing garbage.
# The actual code looks like:
#   if ((node->flags & GGML_TENSOR_FLAG_COMPUTE) == 0) {
#       continue;
#   }
src = re.sub(
    r'\s*if\s*\(\(node->flags\s*&\s*GGML_TENSOR_FLAG_COMPUTE\)\s*==\s*0\)\s*\{\s*continue;\s*\}',
    '',
    src,
)

if src == original:
    print(f"WARNING: No changes made to {path}", file=sys.stderr)
    sys.exit(1)

with open(path, "w") as f:
    f.write(src)

# Verify patches applied
checks = [
    ("batch_size parameter", "int batch_size" in src),
    ("GGML_UNUSED(batch_size)", "GGML_UNUSED(batch_size)" in src),
    ("GGML_TENSOR_FLAG_COMPUTE removed", "GGML_TENSOR_FLAG_COMPUTE" not in src),
]
for name, ok in checks:
    status = "OK" if ok else "FAILED"
    print(f"  [{status}] {name}")

if all(ok for _, ok in checks):
    print(f"Patched {path} successfully")
else:
    print(f"ERROR: Some patches failed on {path}", file=sys.stderr)
    sys.exit(1)
