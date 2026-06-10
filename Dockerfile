# =============================================================================
# RunPod Serverless Worker — Ideogram 4 (ComfyUI)
# =============================================================================
# Base:  runpod/worker-comfyui:5.8.5-base (RunPod handler + tools)
#        → ComfyUI reinstalled to latest for Ideogram4 support (v0.24.0+)
# GPU:   RTX 4090 (24 GB VRAM) — ComfyUI offloads to CPU RAM when needed,
#        the FP8 models (~29.5 GB total) fit comfortably in 24 GB VRAM.
#        Also works on RTX 5090 (32 GB), L4, A5000, RTX 3090.
# Image: ~35 GB (base ~12 GB + models ~29.5 GB)
# =============================================================================

FROM runpod/worker-comfyui:5.8.5-base

# ---------------------------------------------------------------------------
# 0. Reinstall ComfyUI to latest
# ---------------------------------------------------------------------------
# 5.8.5-base ships ComfyUI from March 2026 (v0.18.x era).
# Ideogram 4 native support was added in ComfyUI v0.24.0 (June 3, 2026).
# The RunPod handler (handler.py, start.sh) lives at / and survives.
# comfy-cli and comfy-node-install are at /usr/local/bin and survive too.
# ComfyUI reinstall goes first — it's the most stable layer (rarely changes).
# Custom nodes and models come after, so they can leverage Docker cache.
# ---------------------------------------------------------------------------
RUN /usr/bin/yes | comfy --workspace /comfyui install --version latest --nvidia

# ---------------------------------------------------------------------------
# 1. Custom nodes required by the Ideogram 4 workflow
# ---------------------------------------------------------------------------
# comfyui-kjnodes provides:
#   - Ideogram4PromptBuilderKJ   (structured prompt builder)
#   - Ideogram4Scheduler          (Euler + custom sigma schedule)
#   - CFGOverride                 (CFG for DualModelGuider)
#   - ComfyMathExpression         (resolution rounding to 16px)
#   - EmptyFlux2LatentImage       (Flux 2 latent creation)
#
# NOTE: Installed AFTER ComfyUI reinstall because comfy install --version
#       wipes /comfyui/custom_nodes/.
# ---------------------------------------------------------------------------
RUN comfy-node-install comfyui-kjnodes

# ---------------------------------------------------------------------------
# 2. Ideogram 4 models — FP8 (~29.5 GB total)
# ---------------------------------------------------------------------------
# Source: https://huggingface.co/Comfy-Org/Ideogram-4
# License: ideogram-non-commercial-model-agreement (NON-COMMERCIAL USE ONLY)
# ---------------------------------------------------------------------------

# Main conditional UNet (9.28 GB)
RUN comfy model download \
  --url "https://huggingface.co/Comfy-Org/Ideogram-4/resolve/main/diffusion_models/ideogram4_fp8_scaled.safetensors" \
  --relative-path models/diffusion_models \
  --filename ideogram4_fp8_scaled.safetensors

# Unconditional UNet (9.28 GB)
RUN comfy model download \
  --url "https://huggingface.co/Comfy-Org/Ideogram-4/resolve/main/diffusion_models/ideogram4_unconditional_fp8_scaled.safetensors" \
  --relative-path models/diffusion_models \
  --filename ideogram4_unconditional_fp8_scaled.safetensors

# Text encoder — Qwen3-VL 8B quantized FP8 (10.6 GB)
RUN comfy model download \
  --url "https://huggingface.co/Comfy-Org/Ideogram-4/resolve/main/text_encoders/qwen3vl_8b_fp8_scaled.safetensors" \
  --relative-path models/text_encoders \
  --filename qwen3vl_8b_fp8_scaled.safetensors

# VAE — Flux 2 VAE (336 MB)
RUN comfy model download \
  --url "https://huggingface.co/Comfy-Org/Ideogram-4/resolve/main/vae/flux2-vae.safetensors" \
  --relative-path models/vae \
  --filename flux2-vae.safetensors

# ---------------------------------------------------------------------------
# Deployment:
#   1. Push this repo to GitHub
#   2. RunPod Console → Serverless → New Endpoint → Import Git Repository
#   3. Select GPU: RTX 4090 (pool ADA_24, $1.10/hr)
#   4. Container Disk: 50 GB | Execution Timeout: 600s | Idle Timeout: 5s
#   5. Deploy → copy the Endpoint ID → set VITE_ENDPOINT_ID in frontend/.env
# ---------------------------------------------------------------------------
