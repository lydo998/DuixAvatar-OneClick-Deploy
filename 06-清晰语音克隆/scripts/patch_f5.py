#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
patch_f5.py —— 修复 F5-TTS 在 Windows 上读取参考音会崩溃的问题

问题：F5 的 f5_tts/infer/utils_infer.py 用 torchaudio.load 读参考音，
      而 torchaudio 在 Windows 上依赖 libtorchcodec 的 DLL，本机通常缺 →
      推理时报 `Could not load libtorchcodec` / FFmpeg 相关错误。

修复：把 torchaudio.load(...) 改成 librosa.load(..., sr=24000, mono=True)，
      并补上 `import librosa`。幂等，可重复运行。

用法（务必用 F5 所在 venv 的 python 运行）：
    venv\\Scripts\\python.exe scripts\\patch_f5.py
"""
import os
import re
import sys
import site


NEW_BLOCK = '''    # NOTE: torchaudio.load relies on torchcodec/FFmpeg which is often unavailable on
    # Windows; load + resample with librosa instead, matching target_sample_rate
    # so the torchaudio.transforms.Resample branch below is skipped.
    _wav, _sr = librosa.load(ref_audio, sr=target_sample_rate, mono=True)
    audio = torch.from_numpy(_wav.astype(np.float32)).unsqueeze(0)  # (1, samples)
    sr = target_sample_rate'''


def find_target():
    """定位 f5_tts/infer/utils_infer.py"""
    # 1) 通过已安装的包定位（最可靠）
    try:
        import f5_tts  # noqa
        cand = os.path.join(os.path.dirname(os.path.abspath(f5_tts.__file__)),
                            "infer", "utils_infer.py")
        if os.path.isfile(cand):
            return cand
    except Exception:
        pass

    # 2) 扫描 site-packages（含当前 venv）
    roots = []
    try:
        roots += list(site.getsitepackages())
    except Exception:
        pass
    try:
        roots.append(site.getusersitepackages())
    except Exception:
        pass
    roots.append(os.path.join(os.path.dirname(sys.executable), "..", "Lib", "site-packages"))

    for r in roots:
        p = os.path.join(r, "f5_tts", "infer", "utils_infer.py")
        if os.path.isfile(p):
            return os.path.abspath(p)
    return None


def main():
    path = find_target()
    if not path:
        print("[!] 未找到 f5_tts/infer/utils_infer.py")
        print("    请先在该 venv 中安装 f5-tts，并用该 venv 的 python 运行本脚本。")
        sys.exit(1)

    print("[*] 目标文件:", path)
    src = open(path, encoding="utf-8").read()

    if "librosa.load(ref_audio" in src:
        print("[=] 已打过补丁，无需重复。")
        return

    changed = False

    # 1) 补 import librosa
    if re.search(r"^\s*import librosa\b", src, re.M) is None:
        if "import torchaudio" in src:
            src = src.replace("import torchaudio", "import torchaudio\nimport librosa", 1)
        else:
            src = "import librosa\n" + src
        changed = True
        print("[+] 已加入 import librosa")

    # 2) 替换加载行
    pat = re.compile(r"^[ \t]*audio,\s*sr\s*=\s*torchaudio\.load\(ref_audio\)[ \t]*$", re.M)
    if pat.search(src):
        src = pat.sub(NEW_BLOCK, src, count=1)
        changed = True
        print("[+] 已把 torchaudio.load 改为 librosa.load")
    else:
        print("[!] 未找到 `audio, sr = torchaudio.load(ref_audio)` 那一行。")
        print("    可能 F5 版本不同，请手动把该行替换为：\n")
        print(NEW_BLOCK)
        if not changed:
            sys.exit(2)

    if changed:
        open(path, "w", encoding="utf-8").write(src)
        print("[OK] 补丁已写入。")

    # 自检
    chk = open(path, encoding="utf-8").read()
    print("[i] 自检：", "librosa.load(ref_audio" in chk and "import librosa" in chk)


if __name__ == "__main__":
    main()
