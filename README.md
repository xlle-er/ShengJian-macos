# 声笺 · ShengJian for macOS

原生 Mac 实时字幕应用：把系统声音或麦克风实时转成字幕，并可同步翻译，显示在置顶的字幕浮窗中。引擎与界面组件来自 [Sheng Kit](https://github.com/xlle-er/Sheng-Kit)。

A native macOS app for live subtitles: it turns system audio or your microphone into real-time captions, optionally translated, shown in an always-on-top overlay.

## 功能

- **音源**：系统声音（可限定某个应用）、麦克风、双音源；双音源会抑制麦克风录到的外放回声。
- **识别与翻译**：Apple 本地识别与翻译（无需联网），或阿里云、火山引擎、腾讯云、百度、OpenAI、Azure、Gemini、xAI 等云服务；文字翻译可选 DeepL、DeepLX、OpenAI 兼容服务等。识别与翻译分别配置，可为每个识别配置保存常用语言组合。
- **字幕浮窗**：原文与译文双语、仅译文或仅原文；草稿实时显示；拖动、缩放、锁定、沉浸、点击穿透、回看；字体、颜色、对齐可调。
- **会话记录**（默认关闭）：保存字幕和分源录音；按天浏览、搜索、改名、播放，导出 TXT／Markdown／WAV。
- **其他**：全局快捷键、菜单栏控制、诊断摘要（不含字幕、音频、密钥与个人路径）、八种界面语言、浅色／深色主题。

不会自动开始采音；保存字幕与录音默认关闭。API Key 只保存在本机。

## 下载与安装

1. 从 [Releases](https://github.com/xlle-er/ShengJian-macos/releases/latest) 下载 `ShengJian-<版本>.zip`，解压后把“声笺”拖进“应用程序”文件夹。
2. 安装包未经 Apple 公证，第一次打开时 macOS 会提示无法验证开发者：在“系统设置 → 隐私与安全性”底部点击“仍要打开”。
3. 之后的版本可在 声笺 →“通用 → 软件更新”中检查并安装；每个安装包都带 Ed25519 签名，声笺校验通过后才会替换自身。更新后 macOS 可能会再次请求音频采集权限。

## 系统要求

- macOS 13 或更新版本；Apple 本地识别和翻译需要 Apple 芯片、macOS 26+ 并下载所选语言。
- 采集系统声音需要在“系统设置 → 隐私与安全性”中授权；麦克风同理。
- 云服务需要自备对应服务的 API Key。

## 从源码构建

需要 Xcode 26+ 与 Rust stable。

```bash
git clone --recursive https://github.com/xlle-er/ShengJian-macos.git
cd ShengJian-macos
./script/build_and_run.sh              # 优化构建并启动 dist/ShengJian.app
SHENG_BUILD_CONFIGURATION=debug ./script/build_and_run.sh --build-only   # 快速调试构建
./script/build_universal.sh            # Apple 芯片 + Intel（需安装两个 Rust 目标）
```

签名：默认使用本机已有的 Apple Development 证书，也可用 `SHENG_CODESIGN_IDENTITY` 指定。没有证书时设置 `SHENG_ALLOW_ADHOC=1` 做临时签名，但每次重建后可能需要重新授权音频采集。脚本不会创建证书或修改钥匙串。

发布构建：`./script/release.sh` 生成 Universal 安装包与更新签名（需要本机的更新签名私钥，见 `script/update_signing.swift`）。

## 许可

Apache License 2.0，见 [`LICENSE`](LICENSE) 与 [`NOTICE`](NOTICE)（Copyright 2026 xlle-er）。
