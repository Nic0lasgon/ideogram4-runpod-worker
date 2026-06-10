# =============================================================================
# RunPod Serverless Worker — Ideogram 4 (ComfyUI)
# =============================================================================
# Base:  runpod/worker-comfyui:5.8.5-base (RunPod handler + tools)
#        → ComfyUI upgraded to latest via git pull for Ideogram4 (v0.24.0+)
# GPU:   RTX 4090 (24 GB VRAM) — ComfyUI offloads to CPU RAM when needed,
#        the FP8 models (~29.5 GB total) fit comfortably in 24 GB VRAM.
#        Also works on RTX 5090 (32 GB), L4, A5000, RTX 3090.
# Image: ~35 GB (base ~12 GB + models ~29.5 GB)
# =============================================================================

# syntax=docker/dockerfile:1
FROM runpod/worker-comfyui:5.8.5-base

# ═══════════════════════════════════════════════════════════════════════
# Build Observability: [1/5] → [5/5] banners visible in RunPod Builds tab.
# Python code uses RUN heredoc (<<'PYEOF') — Docker does NOT parse the
# heredoc body for instructions, so "from huggingface_hub" is safe.
# ═══════════════════════════════════════════════════════════════════════

# ─── [1/5] Upgrade ComfyUI to latest ───
# 5.8.5-base ships ComfyUI from March 2026 (pre-Ideogram4 native support).
# Using git pull directly because comfy install refuses overwrite.
RUN echo "╔══════════════════════════════════════════╗" \
 && echo "║ [1/5] Upgrading ComfyUI to latest      ║" \
 && echo "╚══════════════════════════════════════════╝" \
 && apt-get update -qq \
 && apt-get install -y -qq git \
 && rm -rf /var/lib/apt/lists/* \
 && git config --global --add safe.directory /comfyui \
 && cd /comfyui \
 && echo "  Current commit: $(git log -1 --oneline)" \
 && echo "  Fetching latest..." \
 && git fetch origin \
 && git reset --hard origin/master \
 && echo "  Updated commit:  $(git log -1 --oneline)" \
 && echo "  Installing pip dependencies..." \
 && pip install -r requirements.txt \
 && echo "=== [1/5] ComfyUI upgraded to latest ==="

# ─── [2/5] Custom nodes ───
RUN echo "╔══════════════════════════════════════════╗" \
 && echo "║ [2/5] Installing custom nodes           ║" \
 && echo "╚══════════════════════════════════════════╝" \
 && comfy-node-install comfyui-kjnodes \
 && echo "=== [2/5] comfyui-kjnodes installed ==="

# ─── [3/5] Install hf_xet ───
# Rust-based chunked parallel download via HuggingFace Xet storage.
# Comfy-Org/Ideogram-4 is public — no HF_TOKEN needed.
RUN echo "╔══════════════════════════════════════════╗" \
 && echo "║ [3/5] Installing hf_xet accelerator     ║" \
 && echo "╚══════════════════════════════════════════╝" \
 && uv pip install -U huggingface_hub hf-xet \
 && python3 -c "import hf_xet; print('hf_xet', hf_xet.__version__, 'ready')" \
 && echo "=== [3/5] hf_xet installed ==="

# ─── [4/5] Download Ideogram 4 models (FP8, ~29.5 GB) ───
# Uses the Docker BuildKit RUN heredoc. Everything between <<'PYEOF' and
# the closing PYEOF at column 0 is passed verbatim to python3 via stdin.
# Docker does NOT parse this body for FROM/COPY/etc.
RUN echo "╔══════════════════════════════════════════╗" \
 && echo "║ [4/5] Downloading Ideogram 4 models     ║" \
 && echo "║       ~29.5 GB - 30-90 min with hf_xet  ║" \
 && echo "╚══════════════════════════════════════════╝" \
 && python3 <<'PYEOF'
import os, shutil
from huggingface_hub import snapshot_download

snapshot_download(
    "Comfy-Org/Ideogram-4",
    allow_patterns=[
        "diffusion_models/ideogram4_fp8*",
        "diffusion_models/ideogram4_unconditional_fp8*",
        "text_encoders/qwen3vl_8b_fp8*",
        "vae/flux2-vae.safetensors",
    ],
    local_dir="/tmp/ideogram4",
    local_dir_use_symlinks=False,
)

os.makedirs("/comfyui/models/diffusion_models", exist_ok=True)
os.makedirs("/comfyui/models/text_encoders", exist_ok=True)
os.makedirs("/comfyui/models/vae", exist_ok=True)

for d in ["diffusion_models", "text_encoders", "vae"]:
    src_dir = os.path.join("/tmp/ideogram4", d)
    dst_dir = os.path.join("/comfyui/models", d)
    if os.path.isdir(src_dir):
        for f in sorted(os.listdir(src_dir)):
            src = os.path.join(src_dir, f)
            dst = os.path.join(dst_dir, f)
            size_mb = os.path.getsize(src) / 1e6
            print(f"  {f} ({size_mb:.0f} MB)")
            shutil.move(src, dst)

shutil.rmtree("/tmp/ideogram4", ignore_errors=True)
print("All models moved to /comfyui/models/")
PYEOF
RUN echo "=== [4/5] All models downloaded ==="

# ─── [5/5] Verify + cleanup ───
RUN echo "╔══════════════════════════════════════════╗" \
 && echo "║ [5/5] Verifying model files             ║" \
 && echo "╚══════════════════════════════════════════╝" \
 && echo "--- Diffusion models ---" \
 && ls -lh /comfyui/models/diffusion_models/ \
 && echo "--- Text encoders ---" \
 && ls -lh /comfyui/models/text_encoders/ \
 && echo "--- VAE ---" \
 && ls -lh /comfyui/models/vae/ \
 && echo "--- Total model size ---" \
 && du -sh /comfyui/models/diffusion_models/ \
 && du -sh /comfyui/models/text_encoders/ \
 && du -sh /comfyui/models/vae/ \
 && du -sh /comfyui/models/ \
 && echo "--- Cleaning HF cache ---" \
 && rm -rf /root/.cache/huggingface \
 && echo "╔══════════════════════════════════════════╗" \
 && echo "║ BUILD COMPLETE - Ideogram 4 ready       ║" \
 && echo "╚══════════════════════════════════════════╝"

# ---------------------------------------------------------------------------
# No HF_TOKEN needed — Comfy-Org/Ideogram-4 is a public repo and hf_xet
# handles Xet presigned URLs transparently.
#
# Deployment:
#   RunPod Console → Serverless → New Endpoint → Import Git Repository
#   GPU: RTX 4090 (ADA_24, $1.10/hr) | Disk: 50 GB
#   Execution Timeout: 600s | Idle Timeout: 5s
# ---------------------------------------------------------------------------
