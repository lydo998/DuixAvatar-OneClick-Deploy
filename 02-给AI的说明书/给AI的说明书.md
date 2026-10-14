# 给 AI Agent 的安装说明书 · Duix.Avatar 数字人

> **你是被用户投喂了这份说明书和分发包的 AI Agent。**
> 请严格按本文档的流程，帮用户在本机完成 Duix.Avatar 数字人的部署。
> 你的任务是：**先自检 → 判断是否满足 → 引导安装 → 验证可用**。
> 全程用你所在平台可用的工具执行命令；本机是 Windows。

---

## 0. 先用一句话告诉用户

> 「我来帮你装本地数字人 Duix.Avatar。先花 1 分钟检查你的电脑配置，看能不能跑。」

---

## 1. 第一步：环境自检（必做，不要跳过）

在分发包的 `01-环境自检/` 目录下，运行环境自检脚本。有两种方式，**优先用 PowerShell 版**（更准）：

### 方式 A（推荐）
```
powershell -ExecutionPolicy Bypass -File "<分发包路径>\01-环境自检\环境自检.ps1"
```

### 方式 B（兜底）
如果 PowerShell 版因故失败，双击或调用：
```
<分发包路径>\01-环境自检\开始自检.bat
```

脚本会：
- 把结果打印到屏幕
- 同时在 `01-环境自检/` 下生成 **`check-report.txt`**

**你的动作**：读取 `check-report.txt`，解析其中的 `[ERROR]` / `[WARN]` / `[OK]` 行。

---

## 2. 第二步：根据自检结果判断

报告末尾有汇总行：
```
SUMMARY: ERROR=<数量>  WARN=<数量>  INFO=<数量>
```

### 判定规则

| 情况 | 你的动作 |
|---|---|
| `ERROR = 0` | ✅ 环境合格，直接进入第 3 步安装 |
| `ERROR > 0` | ❌ 环境不合格，**停止安装**，按第 2.1 节逐条引导用户解决 |
| `WARN > 0` 但 `ERROR = 0` | ⚠️ 可安装，但要把警告内容告诉用户并给出建议 |

### 2.1 常见 ERROR 及处理话术

**A. 未检测到 NVIDIA 显卡 / nvidia-smi 不存在**
> 「你的电脑没有检测到 NVIDIA 显卡，或者显卡驱动没装。这个数字人项目所有 AI 算力都跑在你本地的显卡上，所以**必须有 NVIDIA 显卡**（AMD/Intel 核显不行）。
> 如果你确实有 N 卡，请先装驱动：https://www.nvidia.cn/drivers/lookup/
> 装完驱动后重启，再跑一次自检。」

**B. 显存不足 8GB**
> 「你的显卡显存只有 X GB，低于 8GB 最低要求，跑不起来。建议换 8GB 以上显存的 N 卡（推荐 12GB+）。」

**C. 内存不足 16GB**
> 「内存只有 X GB，低于 16GB 最低要求。ASR（语音识别）服务很吃内存，16GB 都可能启动失败。建议升到 32GB。」

**D. 没有 D 盘**
这是**最常见**的问题。Duix.Avatar 强制要求 D 盘存放数据。给用户两个方案：

- **方案一（如果有其他空闲分区）**：用 subst 把某个目录映射成 D 盘
  ```cmd
  subst D: <某个空间充足的目录>
  ```
  注意：subst 重启后失效，**必须做成开机自启**（见第 5 节）。

- **方案二**：如果磁盘分区允许，建议用户用磁盘管理新建一个 D 分区。

> 话术：「这个软件要求必须有 D 盘来存数字人数据，但你电脑上没有 D 盘。我可以帮你把某个目录映射成 D 盘，不影响你现有文件。要这么做吗？」

**E. C 盘空间不足 110GB**
> 「C 盘只剩 X GB，但 Docker 镜像要占约 110GB。建议清理 C 盘，或者在 Docker Desktop 设置里把镜像存储位置改到其他盘（Settings → Resources → Disk image location）。」

---

## 3. 第三步：安装（环境合格后）

### 3.1 检查/安装 Docker Desktop

自检报告里如果有：
- `[OK] Docker Desktop 已安装` + `[OK] Docker 引擎运行中` → **跳过，直接 3.2**
- `[WARN] Docker 引擎未运行` → 启动 Docker Desktop，等左下角状态变成绿色（Engine running）
- `[WARN] 未找到 Docker Desktop 安装` → 引导用户安装

> 「你还没装 Docker Desktop。这是数字人的运行容器环境。下载地址：https://www.docker.com/products/docker-desktop/
> 装的时候一路下一步，**首次打开要接受协议、可以跳过登录**。装完告诉我。」

### 3.2 安装数字人服务端（拉取镜像 + 启动容器）

进入分发包的 `03-一键安装/` 目录，运行：

```
03-一键安装\一键安装.bat
```

这个脚本会自动：
1. 检查 D 盘（没有则尝试 subst 映射）
2. 检查 Docker 引擎
3. 创建数据目录 `D:\duix_avatar_data\{face2face,voice\data}`
4. 执行 `docker compose up -d` 拉取并启动 3 个服务

**⚠️ 重要提醒用户**：
> 「接下来要下载约 **110GB** 的 AI 镜像，视网速要 **半小时到几小时**。请连好 WiFi，期间不要关电脑。如果下载失败（网络问题），告诉我，我帮你换国内镜像源。」

### 3.3 验证三个服务

安装完成后，检查容器状态：
```
docker ps
```
必须看到**三个容器都是 `Up` 状态**：
- `duix-avatar-gen-video`（视频生成，端口 8383）
- `duix-avatar-asr`（语音识别，端口 10095）
- `duix-avatar-tts`（语音合成，端口 18180）

如果某个容器是 `Restarting` 或 `Exited`：
- 先 `docker logs <容器名> --tail 50` 看日志
- 参考 `04-排错手册/` 处理

**端口健康检查**（PowerShell）：
```powershell
curl.exe -s -o NUL -w "%{http_code}" http://127.0.0.1:8383/
curl.exe -s -o NUL -w "%{http_code}" http://127.0.0.1:10095/
curl.exe -s -o NUL -w "%{http_code}" http://127.0.0.1:18180/
```
预期：8383 返回任意 HTTP 码（服务在跑）、10095 返回 426（WebSocket 正常）、18180 返回 200。

> **注意**：ASR 服务启动较慢，可能需要几分钟。如果 10095 暂时不通，等 2-3 分钟再试。

### 3.4 安装客户端

引导用户到官方 Releases 下载 Windows 安装包：
https://github.com/duixcom/Duix.Avatar/releases

> 「最后一步，下载客户端界面程序：<链接>，选 `Duix.Avatar-x.x.x-setup.exe`，双击安装就行。」

安装完成后，在桌面创建启动入口（或直接用官方快捷方式）。

---

## 4. 第四步：验证可用

1. 启动客户端
2. 新建任务 → 左侧选**「文本」标签**
3. 粘贴一段中文文案，选一个音色 → 生成

**⚠️ 关键提醒**：
> 「创建任务时**一定要用『文本』标签输入文案，不要上传音频文件**。这是这个版本的设计。」

如果生成成功 → **部署完成** 🎉

---

## 5. 开机自启配置（如果用了 subst 映射 D 盘）

如果通过 subst 方式解决了 D 盘问题，**必须**配置开机自启，否则重启后软件会找不到数据。

创建文件：
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\map_drive_D.bat
```
内容（假设映射到 `F:\DuixData`，按实际替换）：
```bat
@echo off
if not exist "D:\duix_avatar_data" subst D: "F:\DuixData" >nul 2>&1
exit /b 0
```

对用户说明：
> 「我给你加了个开机自动映射，重启后 D 盘会自动回来，不用手动操作。」

---

## 6. 关键技术事实（供你判断，不要念给用户）

### 服务架构
| 容器 | 镜像 | 大小 | 端口 | 挂载 |
|---|---|---|---|---|
| duix-avatar-gen-video | guiji2025/duix.avatar | 15.1GB | 8383:8383 | `d:/duix_avatar_data/face2face` → `/code/data` |
| duix-avatar-asr | guiji2025/fun-asr | 42.4GB | 10095:10095 | 无 |
| duix-avatar-tts | guiji2025/fish-speech-ziming | 52.1GB | 18180:8080 | `d:/duix_avatar_data/voice/data` → `/code/data` |

- 三容器通过 `deploy_ai_network`（bridge）互联
- 全部 `restart: always`、`runtime: nvidia`
- gen-video 需要 `shm_size: 8g`
- 三个服务合计约 **110GB**

### 硬性要求
- Windows 10 Build 19042.1526+ 或 Win11
- **必须有 NVIDIA 显卡** + 正确驱动（AMD/Intel 不行）
- 内存 ≥ 16GB（推荐 32GB）
- C 盘 ≥ 110GB 空闲（Docker 镜像）
- **必须有 D 盘**，数据目录 `D:\duix_avatar_data` 需 30GB+
- 需启用 WSL2（Docker Desktop 依赖）

### 客户端硬编码路径（重要！）
客户端程序内部**写死了 `d:/duix_avatar_data`**。所以：
- D 盘必须真实存在（或通过 subst 映射）
- 如果用户没有 D 盘，`subst` 是最省事的方案（比改程序简单）

### 显存与方案选择
- **≥ 12GB**：完整三服务方案（默认 `docker-compose.yml`）
- **8-11GB**：用 lite 方案 `docker-compose-lite.yml`（仅 gen-video），或按需启停服务

### 50 系显卡
RTX 50 系列（及部分 40 系 + CUDA 12.8）需要用 `docker-compose-5090.yml`。

---

## 7. 你的执行原则

1. **不要跳步**：先自检，再安装。自检不过就不要往下走。
2. **先说人话**：报告是给用户看的，要把技术结论翻译成大白话。
3. **错了就查**：任何一步失败，先看 `04-排错手册/`；仍解决不了再去
   [官方仓库](https://github.com/duixcom/Duix.Avatar) 和
   [官方 Issues](https://github.com/duixcom/Duix.Avatar/issues) 找答案。
4. **不确定就问**：涉及修改用户系统（映射盘符、改开机启动）前，先征得同意。
5. **别急着下 110GB**：确认镜像没拉过再拉，避免重复下载。

---

## 8. 目录导航

```
DuixAvatar-一键分发包/
├── 00-从这里开始.md          ← 给用户看的入口说明
├── 配置不够怎么办.md          ← ★配置不达标时的分场景方案（含云方案）
├── 给AI的说明书.md            ← 你正在读的文件
├── 01-环境自检/
│   ├── 环境自检.ps1           ← 主自检脚本（推荐）
│   ├── 环境自检.bat           ← BAT 版自检（兜底）
│   └── 开始自检.bat           ← 双击入口
├── 02-给AI的说明书/           ← 本文件所在
├── 03-一键安装/
│   ├── 一键安装.bat           ← 主安装脚本
│   ├── docker-compose.yml     ← 三服务完整方案
│   ├── docker-compose-lite.yml← 轻量方案（8G 显存）
│   └── docker-compose-5090.yml← 50 系显卡方案
├── 04-排错手册/
│   └── 常见问题与排错.md
├── 06-清晰语音克隆/            ← ★可选进阶：用 F5-TTS 生成清晰嗓音，再交 Duix 驱动口型
│   ├── 00-先读我.md
│   ├── 给AI的语音克隆说明书.md  ← 该模块的核心说明书
│   ├── 文本清洗规则.md
│   ├── 参考音增强与定版参数.md
│   └── scripts/               ← patch_f5 / clean_text / boost_ref / gen_voice
└── NOTICE                     ← 上游版权声明
```

> 官方原始文档（README、FAQ、许可协议）请访问上游仓库：
> https://github.com/duixcom/Duix.Avatar

### 8.1 遇到配置不达标时

如果自检报 `ERROR`，**先读 `配置不够怎么办.md`**，里面有分场景的完整方案，
包含不需要本地显卡的**在线替代方案（Coze 云服务）**。你可以直接把对应的
方案段落转述给用户，或让用户自己看该文件。

各 ERROR 与方案的对应关系：

| 自检 ERROR | 对应方案章节 |
|---|---|
| 未检测到 NVIDIA 显卡 | 方案一（云方案 / 买卡） |
| 显存不足 8GB | 方案二 |
| 显存 8-11GB（WARN） | 方案三（轻量模式） |
| 内存不足 16GB | 方案四 |
| 未检测到 D 盘 | 方案五（subst 映射） |
| C 盘空间不足 | 方案六（挪 Docker 镜像） |
| 50 系显卡 | 方案七（5090 配置） |

---

## 9. 可选进阶：用 F5-TTS 让声音更清晰

Duix 自带的声音克隆**发闷、含糊**（像嘴里含着东西），内置 TTS 念中文还容易出「嘟噜」怪音。
如果用户对音质不满意，引导他做 **`06-清晰语音克隆`** 模块：

```
① F5-TTS 本地克隆嗓音 → 生成清晰的中文口播音频（16k 单声道 WAV）
② 把这段音频交给 Duix（新建任务 → 上传音频 → 选母版）驱动口型
```

**给 AI 的执行提示**：
- 该模块有独立说明书：`06-清晰语音克隆/给AI的语音克隆说明书.md`，按它执行。
- 该模块需要**独立 venv + PyTorch CUDA**，与 Duix 互不冲突。
- 三条最容易翻车的点，务必遵守：
  1. 装完必须跑 `scripts/patch_f5.py`（否则推理必崩）；
  2. 生成前必须跑 `scripts/clean_text.py`（数字改汉字、标点清洗，否则出怪音）；
  3. 参考音必须过 `scripts/boost_ref.py` 增强（否则声音闷）。
- 面向用户时，用大白话说「帮你克隆一个更清晰的声音」，不要念技术细节。

> 若用户配置不足以跑 F5-TTS（无 N 卡等），跳过本模块，直接用 Duix 自带音色即可。
