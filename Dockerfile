# =============================================================================
# RunPod Serverless Worker — Ideogram 4 (ComfyUI)
# =============================================================================
# Base:  runpod/worker-comfyui:5.8.5-base (ComfyUI 0.6.x + RunPod handler)
# GPU:   RTX 4090 (24 GB VRAM) — ComfyUI offloads to CPU RAM when needed,
#        the FP8 models (~29.5 GB total) fit comfortably in 24 GB VRAM.
#        Also works on RTX 5090 (32 GB), L4, A5000, RTX 3090.
# Image: ~35 GB (base ~12 GB + models ~29.5 GB)
# =============================================================================

FROM runpod/worker-comfyui:5.8.5-base

# ---------------------------------------------------------------------------
# 1. Custom nodes required by the Ideogram 4 workflow
# ---------------------------------------------------------------------------
# comfyui-kjnodes provides:
#   - Ideogram4PromptBuilderKJ   (structured prompt builder)
#   - Ideogram4Scheduler          (Euler + custom sigma schedule)
#   - CFGOverride                 (CFG for DualModelGuider)
#   - ComfyMathExpression         (resolution rounding to 16px)
#   - EmptyFlux2LatentImage       (Flux 2 latent creation)
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
