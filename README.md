# Ideogram 4 — RunPod Serverless Worker

This repository contains a custom Docker image for running [Ideogram 4](https://huggingface.co/Comfy-Org/Ideogram-4) (ComfyUI workflow) on **RunPod Serverless**.

## Quick Deploy

1. **Go to [RunPod Console → Serverless → New Endpoint](https://console.runpod.io)**
2. **Import Git Repository** → select this repo
3. Configure:
   - **GPU**: RTX 4090 (24 GB VRAM, $1.10/hr)
   - **Container Disk**: 50 GB
   - **Execution Timeout**: 600 seconds
   - **Idle Timeout**: 5 seconds
4. **Deploy Endpoint**
5. Copy the **Endpoint ID** into your frontend's `.env`:
   ```env
   VITE_ENDPOINT_ID=<your-endpoint-id>
   ```

## What's Inside

| Component | Details |
|---|---|
| **ComfyUI** | Latest (reinstalled on top of base — needs ≥ v0.24.0 for Ideogram4 native) |
| **Download** | `hf_xet` (Rust, chunked parallel Xet transfer) — 2–5× faster than wget |
| **Custom Nodes** | `comfyui-kjnodes` (Ideogram4PromptBuilderKJ, Ideogram4Scheduler, CFGOverride, etc.) |
| **UNet (conditional)** | `ideogram4_fp8_scaled.safetensors` — 9.28 GB |
| **UNet (unconditional)** | `ideogram4_unconditional_fp8_scaled.safetensors` — 9.28 GB |
| **Text Encoder** | `qwen3vl_8b_fp8_scaled.safetensors` — 10.6 GB |
| **VAE** | `flux2-vae.safetensors` — 336 MB |

## Performance (RTX 4090)

| Metric | Value |
|---|---|
| **Cold start** | 2–5 min (model loading) |
| **Turbo preset** (12 steps) | ~30–40 sec |
| **Default preset** (20 steps) | ~45–60 sec |
| **Quality preset** (48 steps) | ~90–120 sec |
| **Cost per image** (warm) | ~$0.009–$0.037 |

## Build Time & Observability

The Docker build uses `[N/5]` markers and verbose progress output visible in the **RunPod Console → Endpoint → Builds** tab:

```
╔══════════════════════════════════════════╗
║ [1/5] Installing ComfyUI latest         ║
╚══════════════════════════════════════════╝
... → Done

║ [2/5] Installing custom nodes           ║
... → Done

║ [3/5] Installing hf_xet accelerator     ║
... → hf_xet 1.5.1 ready

║ [4/5] Downloading Ideogram 4 models     ║   ← ~20–30 min
║       ~29.5 GB - this will take a while ║
  ideogram4_fp8_scaled.safetensors (9.28 GB)
  ideogram4_unconditional_fp8_scaled (9.28 GB)
  qwen3vl_8b_fp8_scaled.safetensors (10.6 GB)
  flux2-vae.safetensors (336 MB)
... → Done

║ [5/5] Verifying model files             ║
  9.3G  diffusion_models/
  11G   text_encoders/
  336M  vae/
║ BUILD COMPLETE - Ideogram 4 ready       ║
```

## Download Acceleration (hf_xet)

Models are downloaded via `hf_xet`, a Rust-based backend that uses HuggingFace's Xet storage for **chunked parallel downloads**. Compared to single-threaded `wget`:

| Method | Parallelism | Speed (typical build link) |
|---|---|---|
| `wget` / `comfy model download` | Single-threaded | ~1–2 MB/s → ~4–8 hours |
| **hf_xet** (this image) | **Multi-chunk parallel** | ~5–20 MB/s → ~30–90 minutes |

No API token or special configuration needed — `hf_xet` auto-detects Xet repos.

## API Usage

The endpoint accepts standard RunPod ComfyUI requests:

```json
{
  "input": {
    "workflow": {
      "2": {
        "inputs": {
          "high_level_description": "A cute cat"
        },
        "class_type": "Ideogram4PromptBuilderKJ"
      }
    }
  }
}
```

See the [frontend repo](https://github.com/Nic0lasgon/Runpod_Ideogram4) for the full React UI that drives this worker.

## License

Ideogram 4 is released under the [ideogram-non-commercial-model-agreement](https://huggingface.co/Comfy-Org/Ideogram-4/blob/main/README.md). **Non-commercial use only.**
