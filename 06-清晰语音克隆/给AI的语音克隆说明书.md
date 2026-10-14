# 给 AI Agent 的说明书 · 清晰语音克隆（F5-TTS）

> 本文件是 **`06-清晰语音克隆`** 模块的核心。请 AI 助手**完整读完再动手**。
> 目标：在本机用 **F5-TTS** 克隆用户嗓音，生成**清晰、不闷、不糊**的中文口播音频，
> 再交给 **Duix.Avatar** 驱动数字人口型，得到「清晰嗓音 + 数字人」的成品视频。

---

## 0. 先理解：为什么要单独做这一步？

Duix.Avatar 自带声音克隆（用建模视频里的那段声音），但实测**出来的声音发闷、含糊、像嘴里含着东西**，
而且它内置的 TTS 念中文文案时容易出现「嘟噜嘟噜」的怪音。这是**引擎天花板**，换麦、提码率都救不了。

正确做法是**拆成两步**：

```
① F5-TTS 本地克隆嗓音  →  生成一段清晰的中文口播音频（16k 单声道 WAV）
② 把这段清晰音频交给 Duix  →  驱动数字人脸，出口型同步的视频
```

本模块负责 **①**；**②** 见 `../03-一键安装/` 与 `../04-排错手册/`。

> ⚠️ 关键认知：Duix 支持「上传音频驱动口型」。**不要**用 Duix 自带的音色克隆 + 文本合成；
> 要用 F5-TTS 生成的**清晰音频**去驱动。

---

## 1. 环境要求

| 项目 | 要求 |
|---|---|
| 系统 | Windows 10/11 |
| 显卡 | **NVIDIA**，显存 ≥ 6GB（F5-TTS 比 Duix 轻得多，8GB 足够） |
| Python | **3.10.x**（本项目实测 3.10.6） |
| 磁盘 | 约 10GB（含模型） |
| 网络 | 能访问 hf-mirror.com（下模型用） |

> F5-TTS 与 Duix **互不冲突**，可装在同一个盘，各自独立 venv。

---

## 2. 安装 F5-TTS（步骤固定，照做）

### 2.1 建独立 venv

```bat
cd /d F:\F5-TTS
python -m venv venv
venv\Scripts\python.exe -m pip install -U pip
```

### 2.2 装 PyTorch（**必须 CUDA 版，且版本要配对**）

```bat
venv\Scripts\pip.exe install torch==2.11.0+cu130 torchaudio==2.11.0+cu130 --index-url https://download.pytorch.org/whl/cu130
```

**版本坑（务必遵守）**：
- cu130 索引上 `torch` 可到 2.14.1，但 `torchaudio` **最高只到 2.11.0**。
- 若写成 `torch==2.14.1+cu130 torchaudio==2.14.1+cu130`，pip 会因 torchaudio 解析失败而**整体回滚**，连 torch 都不装。
- 正确配对：**torch 与 torchaudio 都锁 2.11.0+cu130**。

装完自检：

```bat
venv\Scripts\python.exe -c "import torch;print(torch.__version__, torch.cuda.is_available())"
```

必须输出 `2.11.0+cu130 True`。若是 `+cpu` 或 `False`，说明装错了，重来。

### 2.3 装 F5-TTS 本体

```bat
venv\Scripts\pip.exe install f5-tts==1.1.22 vocos==0.1.0
```

> 装完**再跑一次 2.2 的自检**。若 f5-tts 的依赖把 torch 覆盖成了 CPU 版，**重跑 2.2 的 torch 安装命令**把 CUDA 版装回来。

### 2.4 打补丁（关键！否则推理必崩）

F5-TTS 用 `torchaudio.load` 读参考音，而 Windows 上它依赖 `libtorchcodec` 的 DLL，
本机通常缺这个 DLL → 报 `Could not load libtorchcodec` / `FFmpeg` 相关错误。

**运行 `scripts/patch_f5.py` 自动打补丁**：

```bat
venv\Scripts\python.exe scripts\patch_f5.py
```

它会把 `venv\Lib\site-packages\f5_tts\infer\utils_infer.py` 里的
`torchaudio.load(...)` 改成 `librosa.load(..., sr=24000, mono=True)`（并补 import）。
脚本幂等，可重复运行。

### 2.5 预下载模型（首次约 1.4GB）

```bat
set HF_ENDPOINT=https://hf-mirror.com
venv\Scripts\python.exe -c "from f5_tts.api import F5TTS; F5TTS(model='F5TTS_v1_Base', device='cuda')"
```

会用 hf-mirror 下 `SWivid/F5-TTS` 的 **F5TTS_v1_Base** 权重 + `charactr/vocos-mel-24khz` 声码器。
下载后缓存在 `%USERPROFILE%\.cache\huggingface`。

> 若卡在下载：设置环境变量 `HF_ENDPOINT=https://hf-mirror.com`（务必），并保持**单连接**别开多线程。

---

## 3. 准备参考音（决定音色与清晰度的关键）

### 3.1 参考音要求

| 项目 | 要求 |
|---|---|
| 时长 | **5–8 秒**（太长反而容易翻车，见 3.3） |
| 内容 | 单人连续说话，无音乐、无第二人、无环境噪声 |
| 格式 | wav，单声道，≥16kHz（44.1kHz 最好） |
| 文本 | **必须与音频逐字一致**（见 3.3） |

### 3.2 增强参考音（**这一步是解决「闷」的核心**）

实测：F5 是**从参考音克隆音色**的。参考音高频弱 → 生成的声音就闷。
对参考音做「**响度归一化 + 3kHz 以上高频提升**」后，生成音的谱质心平均提升 **+200Hz 以上**，明显变清晰。

```bat
venv\Scripts\python.exe scripts\boost_ref.py 你的参考音.wav ref_boost.wav
```

脚本做三件事：去首尾静音 → 叠加 3kHz 高通（增益 0.55）→ RMS 归一到 0.1。

### 3.3 参考文本必须对齐（**否则会「漏文本」**）

F5 会把参考文本当作条件。若参考文本与音频**不完全一致**，模型可能把参考文本**漏进正文**。
实测：用一段 12 秒、文本靠 ASR 猜的参考音，输出里混进了参考文本里的句子 → 直接废掉。

**做法**：参考音尽量短（5–8s），并用 ASR（如 faster-whisper）拿到逐字时间戳，人工核对后写死参考文本。

---

## 4. 清洗正文文案（**F5 最容易翻车的地方**）

F5 是**逐字模型**，它念出的「怪音」几乎都来自**文本里有它词表外的字符**。必做的清洗：

| 问题 | 例子 | 处理 |
|---|---|---|
| 阿拉伯数字 | `99` 读成「纳尼那」，`800` 读成「a憨字条」 | 全部改成**汉字**：`九十九`、`八百` |
| 全角冒号 | `：` **不在词表** → 念出「吧」这类怪音 | 改成 `，` |
| 破折号 | `——` 渲染不稳 | 改成 `，` |
| 中文引号 | `""` 无语音价值且可能干扰 | 直接删掉 |

**清洗后必须校验**：非 CJK 字符必须**逐个**在 `vocab.txt` 里。

```bat
venv\Scripts\python.exe scripts\clean_text.py 你的文案.txt
```

脚本会清洗并报告任何仍在词表外的字符（详见同目录 `文本清洗规则.md`）。

---

## 5. 生成语音（定版参数）

```bat
venv\Scripts\python.exe scripts\gen_voice.py ^
    --ref ref_boost.wav ^
    --ref-text "参考音对应的文字" ^
    --text 文案.txt ^
    --out out_16k.wav
```

**定版参数（实测最优，别乱改）**：

| 参数 | 值 | 说明 |
|---|---|---|
| 模型 | **F5TTS_v1_Base** | v1 比 v0 清晰、更少毛刺 |
| nfe_step | **64** | 32 太糊；96 会报 `t must be strictly increasing` |
| cfg_strength | **2.5** | 引导强度；>3 会不稳定 |
| speed | **0.95** | 略慢更清楚 |
| seed | 42 | 固定，便于复现 |

输出脚本会自动：24kHz 生成 → 重采样到 **16kHz 单声道 PCM_16**（Duix 要求）。

> **为什么这么定**：实测对比见同目录 `参考音增强与定版参数.md`。
> 一句话——**「提亮参考音」比「加推理步数」有效得多**（32→64 步几乎无变化）。

---

## 6. 交给 Duix 出片

音频就绪后，按 `../04-排错手册/常见问题与排错.md` 与 `../02-给AI的说明书/给AI的说明书.md` 操作：
在 Duix 客户端**新建任务 → 上传这段音频**（不要选「文本」）→ 选母版 → 生成。

若走 API（进阶）：

```
POST http://127.0.0.1:8383/easy/submit
{ "audio_url": "/code/data/temp/xxx.wav", "video_url": "/code/data/temp/母版.mov", "code": "task_001" }
GET  http://127.0.0.1:8383/easy/query?code=task_001
# 结果：temp/<code>-r.mp4
```

音频必须是 **16kHz 单声道 PCM_16**，且放在容器的 `/code/data/temp/`（宿主机 `D:\duix_avatar_data\face2face\temp\`）。

---

## 7. 常见坑速查

| 现象 | 原因 | 解法 |
|---|---|---|
| 推理报 libtorchcodec / FFmpeg 错 | F5 用 torchaudio.load | 跑 `scripts/patch_f5.py` |
| 装完 torch 是 CPU 版 | f5-tts 依赖覆盖 | 重跑 2.2 的 cu130 安装 |
| 数字读成怪词 | 阿拉伯数字 | 改汉字（第 4 节） |
| 某处念出「吧」等怪音 | 全角标点不在词表 | 清洗 + `clean_text.py` 校验 |
| 输出里混进参考音的话 | 参考文本没对齐 | 缩短参考音 + 文本严格对齐 |
| 整体发闷、像含着东西 | 参考音高频弱 | `boost_ref.py` 增强参考音 |
| 下载模型超时 | 没走镜像 | `set HF_ENDPOINT=https://hf-mirror.com` |

---

## 8. 你的执行原则

1. **按顺序**：装环境 → 打补丁 → 下模型 → 准备参考音 → 清洗文案 → 生成 → 交 Duix。
2. **每步自检**：装完 torch 一定验 `cuda.is_available()`；生成前一定跑 `clean_text.py`。
3. **别跳步**：跳过 3.2（增强参考音）会得到闷音；跳过第 4 节清洗会得到怪音。
4. **报错先查第 7 节**，再动手改。
5. 面向用户时，用大白话说「正在帮你克隆声音」，不要念技术细节。
