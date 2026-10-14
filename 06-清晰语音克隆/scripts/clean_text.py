#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
clean_text.py —— 清洗文案，让 F5-TTS 不出「怪音」

F5-TTS 是逐字模型，怪音几乎都来自「文本里有它词表外的字符」。本脚本：
  1. 阿拉伯数字 -> 汉字（99 -> 九十九，800 -> 八百）
  2. 全角/特殊标点 -> 逗号或删除（：；（）—— 引号 等）
  3. 合并空白
  4. 逐字符校验：非 CJK 字符必须全部在 vocab.txt 内

用法：
    venv\\Scripts\\python.exe scripts\\clean_text.py 文案.txt            # 打印清洗结果
    venv\\Scripts\\python.exe scripts\\clean_text.py 文案.txt -o 清洗后.txt  # 写文件
"""
import argparse
import os
import re
import sys


DIGITS = "零一二三四五六七八九"
UNITS = ["", "十", "百", "千"]


def _sec4(n):
    """0..9999 -> 汉字（不含万/亿）"""
    s = ""
    unit = 0
    zero = False
    while n > 0:
        d = n % 10
        if d == 0:
            if s and not zero:
                zero = True
                s = "零" + s
        else:
            s = DIGITS[d] + UNITS[unit] + s
            zero = False
        n //= 10
        unit += 1
    if s.startswith("一十"):   # 15 -> 十五（不写一十五）
        s = s[1:]
    return s


def num_to_cn(n):
    """整数 -> 汉字（支持到亿）"""
    if n == 0:
        return "零"
    if n < 0:
        return "负" + num_to_cn(-n)
    yi, rest = divmod(n, 100000000)
    wan, low = divmod(rest, 10000)
    parts = []
    if yi:
        parts.append(_sec4(yi) + "亿")
    if wan:
        if yi and wan < 1000:
            parts.append("零")
        parts.append(_sec4(wan) + "万")
    elif yi and low:
        parts.append("零")
    if low:
        if (yi or wan) and low < 1000:
            parts.append("零")
        parts.append(_sec4(low))
    return "".join(parts)


# 标点替换表（→ 右边）
PUNCT_MAP = [
    ("：", "，"), ("；", "，"),
    ("——", "，"), ("—", "，"), ("–", "，"),
    ("（", "，"), ("）", "，"), ("(", "，"), (")", "，"),
    ("《", ""), ("》", ""), ("【", ""), ("】", ""), ("「", ""), ("」", ""),
    ("“", ""), ("”", ""), ("‘", ""), ("’", ""), ('"', ""), ("'", ""),
    ("…", "，"), ("·", ""), ("•", ""), ("~", ""), ("～", ""),
]


def clean(text):
    log = []
    # 1) 数字 -> 汉字
    def _num(m):
        cn = num_to_cn(int(m.group()))
        log.append(f"数字 {m.group()} -> {cn}")
        return cn
    text = re.sub(r"\d+", _num, text)

    # 2) 标点替换
    for a, b in PUNCT_MAP:
        if a in text:
            text = text.replace(a, b)
            log.append(f"标点 {a!r} -> {b!r}")

    # 3) 空白合并
    text = re.sub(r"[ \t\u3000]+", " ", text)
    text = re.sub(r"\n{2,}", "\n", text).strip()
    return text, log


def find_vocab():
    try:
        import f5_tts  # noqa
        p = os.path.join(os.path.dirname(os.path.abspath(f5_tts.__file__)),
                         "infer", "examples", "vocab.txt")
        if os.path.isfile(p):
            return p
    except Exception:
        pass
    import site
    roots = []
    try:
        roots += list(site.getsitepackages())
    except Exception:
        pass
    roots.append(os.path.join(os.path.dirname(sys.executable), "..", "Lib", "site-packages"))
    for r in roots:
        p = os.path.join(r, "f5_tts", "infer", "examples", "vocab.txt")
        if os.path.isfile(p):
            return os.path.abspath(p)
    return None


def is_cjk(c):
    o = ord(c)
    return (0x3400 <= o <= 0x9FFF) or (0xF900 <= o <= 0xFAFF) or (0x20000 <= o <= 0x2FA1F)


def verify(text, vocab):
    return sorted({c for c in text if not c.isspace() and not is_cjk(c) and c not in vocab})


def main():
    ap = argparse.ArgumentParser(description="清洗文案并校验 F5 词表")
    ap.add_argument("input", help="输入文案文件（txt）")
    ap.add_argument("-o", "--out", help="输出清洗后的文件（可选）")
    args = ap.parse_args()

    raw = open(args.input, encoding="utf-8").read()
    text, log = clean(raw)

    print("=== 清洗动作 ===")
    for line in log or ["（无需改动）"]:
        print("  " + line)

    print("\n=== 清洗后文案 ===")
    print(text)

    vocab_path = find_vocab()
    if not vocab_path:
        print("\n[!] 未找到 vocab.txt，跳过词表校验。")
        return
    vocab = set(open(vocab_path, encoding="utf-8").read().split("\n"))
    bad = verify(text, vocab)
    print("\n=== 词表校验 ===")
    if bad:
        print("  [!] 仍有非词表字符（可能导致怪音）：", bad)
        print("      请手动替换/删除后重跑本脚本。")
        sys.exit(3)
    else:
        print("  [OK] 所有非 CJK 字符均在词表内 ✅")

    if args.out:
        open(args.out, "w", encoding="utf-8").write(text)
        print("\n[OK] 已写出:", args.out)


if __name__ == "__main__":
    main()
