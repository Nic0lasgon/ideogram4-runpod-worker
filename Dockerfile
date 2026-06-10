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

FROM runpod/worker-comfyui:5.8.5-base

# ═══════════════════════════════════════════════════════════════════════
# Build Observability:
#   Each section prints [N/5] markers visible in the RunPod Builds tab.
#   Model downloads use hf_xet (Rust, chunked parallel Xet transfer).
#   The final verification step prints file sizes so you can confirm
#   all ~29.5 GB are present before the image is shipped.
# ═══════════════════════════════════════════════════════════════════════

# ─── [1/5] Upgrade ComfyUI to latest ───
# 5.8.5-base ships ComfyUI from March 2026 (pre-Ideogram4).
# v0.24.0 (June 3, 2026) added native Ideogram4 support.
# We use git pull directly instead of 'comfy install'
# because comfy install refuses to run when ComfyUI already exists
# (the base image has it pre-installed at /comfyui).
RUN echo "╔══════════════════════════════════════════╗" && \
    echo "║ [1/5] Upgrading ComfyUI to latest      ║" && \
    echo "╚══════════════════════════════════════════╝" && \
    apt-get update -qq && apt-get install -y -qq git && \
    git config --global --add safe.directory /comfyui && \
    cd /comfyui && \
    echo "  Current ComfyUI commit:" && \
    git log -1 --oneline && \
    echo "  Fetching latest..." && \
    git fetch origin && \
    git reset --hard origin/master && \
    echo "  Updated ComfyUI commit:" && \
    git log -1 --oneline && \
    echo "  Installing dependencies..." && \
    pip install -r requirements.txt && \
    echo "=== [1/5] ComfyUI upgraded to latest ==="

# ─── [2/5] Custom nodes ───
# Must run AFTER ComfyUI upgrade.
# Addresses any custom_nodes that were wiped or need refreshing.
RUN echo "╔══════════════════════════════════════════╗" && \
    echo "║ [2/5] Installing custom nodes           ║" && \
    echo "╚══════════════════════════════════════════╝" && \
    comfy-node-install comfyui-kjnodes && \
    echo "=== [2/5] comfyui-kjnodes installed ==="

# ─── [3/5] Install hf_xet (fast downloads) ───
# Rust-based chunked parallel download via HuggingFace Xet storage.
# Auto-detected by huggingface_hub — no environment variables needed.
# No HF token required to download from public repos.
RUN echo "╔══════════════════════════════════════════╗" && \
    echo "║ [3/5] Installing hf_xet accelerator     ║" && \
    echo "╚══════════════════════════════════════════╝" && \
    uv pip install -U huggingface_hub hf-xet && \
    python3 -c "import hf_xet; print('hf_xet', hf_xet.__version__, 'ready')" && \
    echo "=== [3/5] hf_xet installed ==="

# ─── [4/5] Download Ideogram 4 models (FP8, ~29.5 GB) ───
# Uses snapshot_download with hf_xet → chunked parallel Xet transfer.
# allow_patterns filters only the FP8 files (skips NVFP4 variants).
# Progress bars visible in RunPod build logs.
RUN echo "╔══════════════════════════════════════════╗" && \
    echo "║ [4/5] Downloading Ideogram 4 models     ║" && \
    echo "║       ~29.5 GB - 30-90 min with hf_xet  ║" && \
    echo "╚══════════════════════════════════════════╝" && \
    python3 -c "
from huggingface_hub import snapshot_download
import os, shutil

snapshot_download(
    'Comfy-Org/Ideogram-4',
    allow_patterns=[
        'diffusion_models/ideogram4_fp8*',
        'diffusion_models/ideogram4_unconditional_fp8*',
        'text_encoders/qwen3vl_8b_fp8*',
        'vae/flux2-vae.safetensors',
    ],
    local_dir='/tmp/ideogram4',
    local_dir_use_symlinks=False,
)

os.makedirs('/comfyui/models/diffusion_models', exist_ok=True)
os.makedirs('/comfyui/models/text_encoders', exist_ok=True)
os.makedirs('/comfyui/models/vae', exist_ok=True)

for f in os.listdir('/tmp/ideogram4/diffusion_models'):
    src = f'/tmp/ideogram4/diffusion_models/{f}'
    dst = f'/comfyui/models/diffusion_models/{f}'
    print(f'  {f} ({os.path.getsize(src)/1e9:.2f} GB)')
    shutil.move(src, dst)

for f in os.listdir('/tmp/ideogram4/text_encoders'):
    src = f'/tmp/ideogram4/text_encoders/{f}'
    dst = f'/comfyui/models/text_encoders/{f}'
    print(f'  {f} ({os.path.getsize(src)/1e9:.2f} GB)')
    shutil.move(src, dst)

for f in os.listdir('/tmp/ideogram4/vae'):
    src = f'/tmp/ideogram4/vae/{f}'
    dst = f'/comfyui/models/vae/{f}'
    print(f'  {f} ({os.path.getsize(src)/1e6:.1f} MB)')
    shutil.move(src, dst)

shutil.rmtree('/tmp/ideogram4')
print('All models moved to /comfyui/models/')
" && \
    echo "=== [4/5] All models downloaded ==="

# ─── [5/5] Verify + cleanup ───
RUN echo "╔══════════════════════════════════════════╗" && \
    echo "║ [5/5] Verifying model files             ║" && \
    echo "╚══════════════════════════════════════════╝" && \
    echo "--- Diffusion models ---" && \
    ls -lh /comfyui/models/diffusion_models/ && \
    echo "--- Text encoders ---" && \
    ls -lh /comfyui/models/text_encoders/ && \
    echo "--- VAE ---" && \
    ls -lh /comfyui/models/vae/ && \
    echo "--- Total model size ---" && \
    du -sh /comfyui/models/diffusion_models/ && \
    du -sh /comfyui/models/text_encoders/ && \
    du -sh /comfyui/models/vae/ && \
    du -sh /comfyui/models/ && \
    echo "--- Cleaning HF cache ---" && \
    rm -rf /root/.cache/huggingface && \
    echo "╔══════════════════════════════════════════╗" && \
    echo "║ BUILD COMPLETE - Ideogram 4 ready       ║" && \
    echo "╚══════════════════════════════════════════╝"

# ---------------------------------------------------------------------------
# No HF_TOKEN needed — Comfy-Org/Ideogram-4 is a public repo and hf_xet
# handles Xet presigned URLs transparently.
#
# Deployment:
#   1. Push this repo to GitHub
#   2. RunPod Console → Serverless → New Endpoint → Import Git Repository
#   3. Select GPU: RTX 4090 (pool ADA_24, $1.10/hr)
#   4. Container Disk: 50 GB | Execution Timeout: 600s | Idle Timeout: 5s
#   5. Deploy → copy the Endpoint ID → set VITE_ENDPOINT_ID in frontend/.env
# ---------------------------------------------------------------------------
