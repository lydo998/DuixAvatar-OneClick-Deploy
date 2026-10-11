# DuixAvatar One-Click Deploy

> 🚀 **把 Duix.Avatar 本地数字人的部署过程，变成「丢给 AI 就能装」**
>
> 非官方部署工具包 · 只包含安装脚本和文档，不含软件本体

[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Upstream](https://img.shields.io/badge/upstream-Duix.Avatar-orange)](https://github.com/duixcom/Duix.Avatar)

---

## 这是什么

[Duix.Avatar](https://github.com/duixcom/Duix.Avatar) 是硅基智能开源的一款本地数字人项目 ——
给一段 10 秒的真人说话视频，就能克隆出数字人形象和声音，输入文字即可生成口播视频。
**全本地运行、免费、不限次数。**

但它有个问题：**部署门槛不低**。要装 WSL2、Docker、拉 110GB 镜像、处理数据盘路径……
对非技术用户很不友好。

**这个项目就是来解决这个问题的。** 它把整个部署流程自动化，并写成 AI 能读懂的说明书 ——
用户只需要把文件夹丢给任意 AI 助手，就能完成安装。

---

## 核心特性

| 特性 | 说明 |
|---|---|
| 🔍 **环境自检** | 一键检测显卡/显存/内存/磁盘/Docker/WSL，输出结构化报告 |
| 🤖 **AI 可读** | 附带完整说明书，AI 助手读了就能自动引导安装 |
| 📦 **一键安装** | 自动完成 D 盘检查 → Docker 启动 → 拉镜像 → 起服务 |
| 🛠️ **分场景方案** | 针对没 N 卡 / 显存小 / 没 D 盘等情况给出替代方案 |
| 📖 **排错手册** | 覆盖 11 类常见问题的现象、原因、解法 |

---

## 快速开始

### 方式一：交给 AI（推荐，适合非技术用户）

1. 下载或 clone 本仓库
2. 把**整个文件夹**丢给你的 AI 助手（WorkBuddy / Claude / ChatGPT / 豆包 等）
3. 跟它说：

   > 「帮我按 `02-给AI的说明书/给AI的说明书.md`，在我的电脑上安装 Duix.Avatar 数字人。」

4. 跟着它的引导走即可

### 方式二：手动执行

```cmd
:: 1. 检查环境
01-环境自检\开始自检.bat

:: 2. 确认配置达标后，执行安装
03-一键安装\一键安装.bat
```

---

## 环境要求

| 项目 | 最低 | 推荐 |
|---|---|---|
| 操作系统 | Windows 10 (Build 19042+) | Windows 11 |
| 显卡 | **NVIDIA** 显卡，显存 ≥ 8GB | RTX 4070 / 12GB+ |
| 内存 | 16GB | 32GB |
| 磁盘 | C 盘 ≥ 110GB + **D 盘** ≥ 30GB | 更充裕 |
| 依赖 | Docker Desktop + WSL2 | — |

> ⚠️ **两个硬性门槛**
> 1. **必须是 NVIDIA（英伟达）显卡** —— AMD 和 Intel 核显无法运行
> 2. **必须有 D 盘** —— 上游客户端硬编码了 `d:/duix_avatar_data` 路径

**配置不达标？** 看 [`配置不够怎么办.md`](配置不够怎么办.md) ——
包含不需要本地显卡的**在线替代方案**。

---

## 目录结构

```
.
├── 00-从这里开始.md              用户入口（三步走）
├── 配置不够怎么办.md              配置不达标时的分场景方案
├── 01-环境自检/                  环境检测（PS 主 + BAT 兜底）
├── 02-给AI的说明书/              ★ 给 AI 读的完整安装流程
├── 03-一键安装/                  安装脚本 + 3 套 compose 配置
├── 04-排错手册/                  11 类常见问题与解法
├── NOTICE                       上游版权声明（协议要求）
└── LICENSE                      本项目许可
```

---

## 为什么只有脚本，没有镜像

Duix.Avatar 的三个 Docker 镜像合计约 **110GB**：

| 镜像 | 大小 | 作用 |
|---|---|---|
| `guiji2025/duix.avatar` | 15.1GB | 视频生成 |
| `guiji2025/fun-asr` | 42.4GB | 语音识别 |
| `guiji2025/fish-speech-ziming` | 52.1GB | 语音合成 |

本仓库**不分发镜像**，安装脚本会在用户机器上通过 `docker pull` 直接拉取。
这样仓库可以保持在很小的体积，也避免版权和带宽问题。

---

## 常见问题

<details>
<summary><b>安装要多久？</b></summary>

主要是下载镜像的时间，约 110GB。视网速从半小时到几小时不等。
建议连 WiFi，耐心等待。
</details>

<details>
<summary><b>装完怎么用？</b></summary>

启动客户端 → 新建任务 → 选「**文本**」标签 → 粘贴文案 → 选音色 → 生成。

⚠️ 注意：用「文本」标签输入文字，**不要上传音频文件**。
</details>

<details>
<summary><b>AMD 显卡能用吗？</b></summary>

不能。上游项目只支持 NVIDIA 显卡。AMD / Intel 核显请使用
[`配置不够怎么办.md`](配置不够怎么办.md) 中的在线替代方案。
</details>

<details>
<summary><b>没有 D 盘怎么办？</b></summary>

用 `subst` 命令把某个目录映射成 D 盘，并配置开机自启。
详见 [`配置不够怎么办.md`](配置不够怎么办.md) 方案五。
</details>

<details>
<summary><b>这个仓库和官方是什么关系？</b></summary>

**没有关系。** 这是非官方第三方工具包，只整理部署流程，不含任何官方代码或镜像。
软件本体请从 [官方仓库](https://github.com/duixcom/Duix.Avatar) 获取。
</details>

---

## 致谢与声明

- 上游项目：[Duix.Avatar](https://github.com/duixcom/Duix.Avatar)（硅基智能 / GuijiAI）
- 本项目为**非官方第三方部署工具**，与 DUIX.COM 及 GuijiAI 无隶属关系
- 本项目**不含**任何上游代码、镜像或二进制文件
- 本项目的脚本与文档基于 MIT 协议开源
- 使用本工具前，请阅读并遵守[上游许可协议](https://github.com/duixcom/Duix.Avatar/blob/main/LICENSE)
- 维护者 / Author：[Lydo · @lydo998](https://github.com/lydo998)

Built with DUIX.COM

---

## License

[MIT](LICENSE) for this project's scripts and documentation.

Upstream `Duix.Avatar` is licensed under the
[DUIX.COM Community License](https://github.com/duixcom/Duix.Avatar/blob/main/LICENSE).
Note: under that license, products exceeding **1,000 monthly active users**
require a separate commercial license from DUIX.COM.
