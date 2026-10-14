#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
gen_voice.py —— 用 F5-TTS 生成清晰的中文口播音频（定版参数）

定版参数（实测最优）：
    模型 F5TTS_v1_Base / nfe_step 64 / cfg_strength 2.5 / speed 0.95 / seed 42

输出两份：
    <out>            16kHz 单声道 PCM_16（交给 Duix 驱动口型）
    <out>.24k.wav    24kHz 原始生成（留档/试听）

用法：
    venv\\Scripts\\python.exe scripts\\gen_voice.py ^
        --ref ref_boost.wav ^
        --ref-text "参考音对应的文字" ^
        --text 文案.txt ^
        --out out_16k.wav

    文案.txt 支持多行；每行单独生成，行间自动加 0.35 秒停顿再拼接。
"""
import argparse
import os
import sys

# 防御：若当前目录/上级存在名为 f5_tts 的本地目录，会遮蔽已安装的包
sys.path = [p for p in sys.path
            if not os.path.basename(os.path.normpath(p)) == "f5_tts"]

import numpy as np
import soundfile as sf
import librosa
import torch

import f5_tts
from f5_tts.api import F5TTS

SR = 24000
GAP = 0.35  # 段间停顿（秒）


def load_lines(path):
    with open(path, encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip()]


def main():
    ap = argparse.ArgumentParser(description="F5-TTS 生成清晰语音（定版参数）")
    ap.add_argument("--ref", required=True, help="增强后的参考音 wav")
    ap.add_argument("--ref-text", required=True, help="参考音对应的文字（必须逐字一致）")
    ap.add_argument("--text", required=True, help="正文文案 txt（可多行）")
    ap.add_argument("--out", required=True, help="输出 16k 单声道 wav")
    ap.add_argument("--model", default="F5TTS_v1_Base", help="模型名（默认 F5TTS_v1_Base）")
    ap.add_argument("--nfe", type=int, default=64, help="nfe_step（默认 64；>64 可能报错）")
    ap.add_argument("--cfg", type=float, default=2.5, help="cfg_strength（默认 2.5；>3 不稳）")
    ap.add_argument("--speed", type=float, default=0.95, help="语速（默认 0.95）")
    ap.add_argument("--seed", type=int, default=42, help="随机种子（默认 42）")
    args = ap.parse_args()

    lines = load_lines(args.text)
    if not lines:
        print("[!] 文案为空:", args.text)
        sys.exit(1)

    print("[i] f5_tts 来自:", f5_tts.__file__)
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"[i] device={dev}  model={args.model}  nfe={args.nfe} cfg={args.cfg} speed={args.speed}")

    tts = F5TTS(model=args.model, device=dev)

    wavs = []
    for i, text in enumerate(lines, 1):
        print(f"[gen] 第 {i}/{len(lines)} 段: {text[:30]} ...")
        w, sr_out, _ = tts.infer(
            ref_file=args.ref, ref_text=args.ref_text, gen_text=text,
            seed=args.seed, progress=None,
            nfe_step=args.nfe, cfg_strength=args.cfg, speed=args.speed,
        )
        w = np.asarray(w, dtype=np.float32)
        if sr_out != SR:
            w = librosa.resample(w, orig_sr=sr_out, target_sr=SR)
        wavs.append(w)
        print(f"       -> {len(w)/SR:.2f}s")

    gap = np.zeros(int(GAP * SR), dtype=np.float32)
    out24 = wavs[0]
    for w in wavs[1:]:
        out24 = np.concatenate([out24, gap, w])

    p24 = os.path.splitext(args.out)[0] + ".24k.wav"
    sf.write(p24, out24, SR)
    print(f"[OK] 24k 原始: {p24}  {len(out24)/SR:.2f}s")

    y16, _ = librosa.load(p24, sr=16000, mono=True)
    sf.write(args.out, y16.astype(np.float32), 16000)
    print(f"[OK] 16k 交付: {args.out}  {len(y16)/16000:.2f}s  16kHz 单声道 PCM_16")
    print("     ^ 这个文件交给 Duix 驱动口型")


if __name__ == "__main__":
    main()
