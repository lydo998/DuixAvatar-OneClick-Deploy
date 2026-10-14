#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
boost_ref.py —— 增强参考音，解决 F5-TTS 生成语音「闷 / 含着东西」

原理：F5 从参考音克隆音色，参考音高频弱 -> 生成音就闷。
本脚本对参考音做三步处理，提升清晰度：
  1. 去首尾静音
  2. 3kHz 以上高通叠加（presence boost，默认增益 0.55）
  3. 响度归一化到 RMS=0.1（与 F5 内部 target_rms 一致）

用法：
    venv\\Scripts\\python.exe scripts\\boost_ref.py 参考音.wav 增强后.wav
    venv\\Scripts\\python.exe scripts\\boost_ref.py 参考音.wav 增强后.wav --gain 0.95
"""
import argparse
import os
import sys

import numpy as np
import soundfile as sf
import librosa
import scipy.signal as ss


def boost(src, dst, gain=0.55, rms_target=0.1, sr=24000):
    y, _ = librosa.load(src, sr=sr, mono=True)
    dur0 = len(y) / sr
    yt, _ = librosa.effects.trim(y, top_db=30)          # 去首尾静音
    dur1 = len(yt) / sr

    b, a = ss.butter(2, 3000 / (sr / 2), btype="high")  # 3kHz 高通
    hf = ss.filtfilt(b, a, yt)
    yb = yt + gain * hf                                  # presence boost

    rms = float(np.sqrt(np.mean(yb ** 2))) + 1e-9
    yb = np.clip(yb * (rms_target / rms), -1, 1).astype(np.float32)

    sf.write(dst, yb, sr)
    print(f"[OK] {os.path.basename(src)} {dur0:.2f}s -> 去静音 {dur1:.2f}s")
    print(f"     增益={gain}  RMS->{rms_target}  输出={dst}")


def main():
    ap = argparse.ArgumentParser(description="增强 F5 参考音（去静音 + 高频提升 + 响度归一化）")
    ap.add_argument("src", help="原始参考音（wav，5-8 秒最佳）")
    ap.add_argument("dst", help="输出的增强参考音")
    ap.add_argument("--gain", type=float, default=0.55,
                    help="高频提升增益：0.55=平衡（推荐）；0.95=更亮但齿音偏重")
    ap.add_argument("--rms", type=float, default=0.1, help="目标响度 RMS（默认 0.1）")
    args = ap.parse_args()

    if not os.path.isfile(args.src):
        print("[!] 找不到参考音:", args.src)
        sys.exit(1)
    boost(args.src, args.dst, gain=args.gain, rms_target=args.rms)


if __name__ == "__main__":
    main()
