#!/usr/bin/env python3
"""Turn any image into assets for the depth wallpaper.

  uv run --with onnxruntime --with opencv-python-headless --with numpy --with huggingface_hub \
      make_layers.py wallpaper.png ~/.local/share/depth-wall

Writes clean.jpg (2560x1440), depth.png (1280x720, white = near), glow.png
(optional light-source glow) and drop.png (rain sprite).

Models (downloaded once into the Hugging Face cache):
  - BiRefNet (subject cutout)            onnx-community/BiRefNet-ONNX
  - Depth Anything V2 Large (depth)      onnx-community/depth-anything-v2-large
"""
import argparse, os, time
import numpy as np, cv2, onnxruntime as ort
from huggingface_hub import hf_hub_download

p = argparse.ArgumentParser()
p.add_argument("image"); p.add_argument("outdir")
p.add_argument("--depth-res", type=int, default=770, help="height of the detailed depth pass (multiple of 14)")
p.add_argument("--glow", action="store_true", help="extract bright warm pixels in the centre band as a flickering glow layer")
p.add_argument("--glow-band", type=float, default=0.06, help="half width of the centre band, as a fraction of the width")
p.add_argument("--keep-rain", action="store_true", help="do not remove thin vertical streaks (painted rain) from the background")
a = p.parse_args()
os.makedirs(a.outdir, exist_ok=True)
img = cv2.imread(a.image); H, W = img.shape[:2]
so = ort.SessionOptions(); so.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
def session(repo): return ort.InferenceSession(hf_hub_download(repo, "onnx/model.onnx"), so, providers=["CPUExecutionProvider"])
def norm(x): return ((x - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]).transpose(2, 0, 1)[None].astype(np.float32)
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255
def guided(I, p_, r, eps):
    k = (2 * r + 1, 2 * r + 1)
    mI, mp = cv2.blur(I, k), cv2.blur(p_, k)
    A = (cv2.blur(I * p_, k) - mI * mp) / (cv2.blur(I * I, k) - mI * mI + eps)
    return cv2.blur(A, k) * I + cv2.blur(mp - A * mI, k)

# 1. subject cutout (BiRefNet)
t = time.time(); s = session("onnx-community/BiRefNet-ONNX")
x = cv2.resize(img, (1024, 1024), interpolation=cv2.INTER_AREA)[:, :, ::-1].astype(np.float32) / 255
m = 1 / (1 + np.exp(-np.squeeze(s.run(None, {s.get_inputs()[0].name: norm(x)})[-1]).astype(np.float32)))
alpha = np.clip(guided(gray, cv2.resize(m, (W, H), interpolation=cv2.INTER_CUBIC), 4, 1e-4), 0, 1)
alpha = np.clip((alpha - 0.08) / 0.84, 0, 1).astype(np.float32)
print(f"cutout {time.time()-t:.1f}s", flush=True)

# 2. optional glow (bright warm pixels near the centre, e.g. a glowing sword)
bolt = np.zeros((H, W), np.float32)
if a.glow:
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    v, sat, hue = [hsv[:, :, i].astype(np.float32) for i in (2, 1, 0)]; v /= 255; sat /= 255
    bolt = (((v > 0.80) & (hue > 18) & (hue < 38) & (sat > 0.30)) | ((v > 0.97) & (sat < 0.25) & (hue > 10) & (hue < 45))).astype(np.float32)
    band = np.zeros_like(bolt); c = W // 2; band[:, c - int(a.glow_band * W): c + int(a.glow_band * W)] = 1
    bolt = cv2.morphologyEx(bolt * band, cv2.MORPH_OPEN, np.ones((2, 2), np.uint8))
    ga = np.clip(cv2.GaussianBlur(bolt, (0, 0), 2) * 0.7 + cv2.GaussianBlur(bolt, (0, 0), 18) * 1.1 + cv2.GaussianBlur(bolt, (0, 0), 60) * 0.9, 0, 1)
    rgb = np.zeros_like(img); rgb[:] = (90, 235, 255)
    cv2.imwrite(f"{a.outdir}/glow.png", np.dstack([rgb, (ga * 255).astype(np.uint8)]))
    alpha = np.maximum(alpha, np.clip(cv2.GaussianBlur(bolt, (0, 0), 3) * 2, 0, 1))

# 3. clean plate: painted rain removed, subject stays, background behind it inpainted
bg = img if a.keep_rain else cv2.morphologyEx(img, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (9, 1)))
hole = cv2.dilate((alpha > 0.03).astype(np.uint8), np.ones((41, 41), np.uint8))
sm = cv2.inpaint(cv2.resize(bg, (W // 4, H // 4), interpolation=cv2.INTER_AREA),
                 cv2.resize(hole, (W // 4, H // 4), interpolation=cv2.INTER_NEAREST), 12, cv2.INPAINT_TELEA)
fill = cv2.resize((cv2.GaussianBlur(sm, (0, 0), 8) * 0.45).astype(np.uint8), (W, H), interpolation=cv2.INTER_CUBIC)
bg = np.where(hole[:, :, None] > 0, fill, bg)
clean = (img * alpha[:, :, None] + bg * (1 - alpha[:, :, None])).astype(np.uint8)
cv2.imwrite(f"{a.outdir}/clean.jpg", cv2.resize(clean, (2560, 1440), interpolation=cv2.INTER_AREA), [cv2.IMWRITE_JPEG_QUALITY, 94])

# 4. depth (Depth Anything V2 Large, two scales: global from 518 px, detail from --depth-res)
t = time.time(); s = session("onnx-community/depth-anything-v2-large")
def run(h):
    w = int(round(h * W / H / 14)) * 14
    x = cv2.resize(img, (w, h), interpolation=cv2.INTER_AREA)[:, :, ::-1].astype(np.float32) / 255
    d = np.squeeze(s.run(None, {s.get_inputs()[0].name: norm(x)})[0]).astype(np.float32)
    lo, hi = np.percentile(d, [0.5, 99.5]); return np.clip((d - lo) / (hi - lo), 0, 1)
wk, hk = 3840, 2160
lo_, hi_ = [cv2.resize(run(h), (wk, hk), interpolation=cv2.INTER_CUBIC) for h in (518, a.depth_res)]
B = lambda z, s_: cv2.GaussianBlur(z, (0, 0), s_)
d = np.clip(B(lo_, 24) + (hi_ - B(hi_, 24)), 0, 1).astype(np.float32)
g2 = cv2.resize(gray, (wk, hk), interpolation=cv2.INTER_AREA)
d = cv2.bilateralFilter(np.clip(guided(g2, d, 6, 1e-3), 0, 1).astype(np.float32), 9, 0.08, 4)
d = cv2.resize(d, (W, H), interpolation=cv2.INTER_CUBIC)
print(f"depth {time.time()-t:.1f}s", flush=True)
if a.glow and bolt.any():  # a light source should not stick out of the depth map
    ds = cv2.resize(d, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
    mk = cv2.dilate(cv2.resize((ga > 0.235).astype(np.uint8), (W // 4, H // 4), interpolation=cv2.INTER_NEAREST), np.ones((9, 9), np.uint8))
    d = cv2.resize(cv2.inpaint((ds * 255).astype(np.uint8), mk, 15, cv2.INPAINT_TELEA).astype(np.float32) / 255, (W, H), interpolation=cv2.INTER_CUBIC)

# 5. final depth: subject spread over 0.55..1, background flat and far, blended by the cutout
inside = d[alpha > 0.5]
lo, hi = np.percentile(inside, [2, 98]) if inside.size else (0, 1)
subject = 0.55 + 0.45 * np.clip((d - lo) / (hi - lo + 1e-6), 0, 1)
far = 0.12 + 0.10 * np.clip(d, 0, 1)
soft = cv2.GaussianBlur(alpha, (0, 0), 6)
out = cv2.GaussianBlur(far * (1 - soft) + subject * soft, (0, 0), 3)
cv2.imwrite(f"{a.outdir}/depth.png", (cv2.resize(out, (1280, 720), interpolation=cv2.INTER_AREA) * 255).astype(np.uint8))

# 6. rain sprite
S_ = 128; dr = np.zeros((S_, S_), np.float32)
dr[:, S_ // 2 - 1:S_ // 2 + 1] = (np.sin(np.linspace(0, 1, S_) * np.pi) ** 1.5)[:, None]
dr = cv2.GaussianBlur(dr, (0, 0), 0.6)
cv2.imwrite(f"{a.outdir}/drop.png", np.dstack([np.full((S_, S_), 255, np.uint8)] * 3 + [(np.clip(dr, 0, 1) * 255).astype(np.uint8)]))
print("done ->", a.outdir)
