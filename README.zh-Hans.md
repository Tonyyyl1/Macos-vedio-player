# AetherPlayer

> [简体中文](README.zh-Hans.md) · [English](README.md) · [更新记录](CHANGELOG.md)

AetherPlayer 是基于 [AetherEngine](https://github.com/superuser404notfound/AetherEngine) 的原生媒体播放器，面向 macOS 与 iOS/iPadOS。它可以打开视频或音频文件、切换音轨和字幕、在时间轴上显示实时缩略图，并导出原始分辨率的视频帧。

- macOS：Universal 二进制（Apple Silicon 和 Intel），需要 macOS 14.0 或更高版本。
- iOS/iPadOS：通用应用，需要 iOS/iPadOS 17.0 或更高版本。

## 目录

- [安装](#安装)
- [macOS 功能](#macos-功能)
- [控制方式](#控制方式)
- [iOS/iPadOS 功能](#iosipados-功能)
- [构建](#构建)
- [发布构建](#发布构建)
- [更新记录](CHANGELOG.md)
- [许可证](#许可证)

## 安装

**macOS：** 从上游 [Releases 页面](https://github.com/superuser404notfound/AetherPlayer/releases)下载已公证的 `.dmg`，将 AetherPlayer 拖入“应用程序”文件夹后启动。DMG 通过内置的 Sparkle 自动更新；也可以参与 [TestFlight](https://testflight.apple.com/join/rgrjZ98V) 测试。

**iOS/iPadOS：** 加入公开 [TestFlight 测试](https://testflight.apple.com/join/rgrjZ98V)，或按下文[构建](#构建)步骤从源码运行。

## macOS 功能

- **广泛格式播放。** 通过 AetherEngine 和 FFmpeg 解码；屏幕上的 `native` / `sw` 标记可显示当前渲染路径。
- **音频与系统“正在播放”。** 打开音乐或音频后，AetherPlayer 会显示专用的“正在播放”界面；嵌入封面显示在模糊背景上，没有封面时使用生成的渐变背景。播放信息会接入控制中心、锁屏界面和键盘媒体键。
- **音轨与字幕切换。** 可从菜单栏或轨道弹出菜单选择音轨/字幕；字幕支持“关闭”。把 `.srt` 拖到正在播放的视频上即可附加为外置字幕，并可在“窗口”菜单调整字幕大小。
- **光盘标题与章节。** 打开已解密的 DVD-Video 或 Blu-ray `.iso`（通过打开对话框、拖放到窗口或 Finder 的“打开方式”），轨道弹出菜单会列出标题；选择标题即可切换，并可点击当前标题的章节跳转。
- **带实时预览的拖动进度条。** 悬停时间轴可预览缩略图，点击跳转，或拖动连续定位。
- **截取帧。** 使用 `Cmd+Shift+S` 或相机按钮，以原始分辨率保存当前画面。
- **带缩略图的最近项目。** 已打开文件会缓存关键帧缩略图，便于快速辨认和重新打开。
- **断点续播。** 重新打开文件时可从上次的位置继续。
- **文件夹播放列表。** 打开文件夹后，按 `Cmd+Left` / `Cmd+Right` 可在其中的视频间切换。
- **可调缓冲。** 在“偏好设置”（`Cmd+,`）中设置预缓冲长度，以适应较慢或不稳定的网络源。
- **技术统计。** 通过 `Cmd+Shift+I` 打开实时检查器，查看后端与解码器、分辨率、帧率、动态范围、显示模式、视频/音频码率、声道、音视频同步、丢帧和缓冲状态。
- **简洁的播放界面。** 播放时控制栏会自动隐藏，移动鼠标后重新显示。

## 控制方式

| 操作 | 作用 |
| --- | --- |
| 空格 / 点击 | 播放 / 暂停 |
| 双击 / F | 切换全屏 |
| 左 / 右方向键 | 后退 / 前进 10 秒 |
| Cmd+Left / Cmd+Right | 文件夹中的上一个 / 下一个 |
| 上 / 下方向键 | 音量增加 / 减少 5% |
| M | 静音 / 取消静音 |
| Escape | 退出全屏；否则停止播放 |
| Cmd+O | 打开文件 |
| Cmd+Shift+O | 打开文件夹 |
| Cmd+Shift+S | 保存当前帧 |
| Cmd+, | 打开偏好设置 |
| Cmd+Shift+T | 切换始终置顶 |
| Cmd+Shift+I | 打开技术统计 |

系统媒体键和控制中心的播放控制也可控制播放/暂停和曲目切换。

## iOS/iPadOS 功能

- **打开本地文件或 URL。** 可从“文件”应用选取视频/音频，或粘贴 `http` / `https` 地址。
- **与 macOS 一致的自定义播放控制。** 包含带等宽前后时间码的进度条、拖动时浮动显示的缩略图、播放/暂停、前进/后退 10 秒按钮；顶部栏提供关闭、AirPlay 和轨道入口。控制栏点击后显示/隐藏，播放中自动隐藏，播放结束时显示重播按钮。
- **画中画、AirPlay 与锁屏播放信息。** 播放仍托管在 `AVPlayerViewController` 中，因此支持 PiP、AirPlay 路由和控制中心/锁屏“正在播放”。只隐藏 AVKit 的可见控制界面，保留其播放后端。
- **轨道切换。** 轨道页会列出音轨和字幕，字幕可关闭，也支持附加外置 `.srt`。
- **最近项目。** 主页显示最近打开的文件及其缓存缩略图，可快速重新打开。

## 构建

工程由 XcodeGen 生成：

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project AetherPlayer.xcodeproj -scheme AetherPlayer -destination 'platform=macOS' build
xcodebuild -project AetherPlayer.xcodeproj -scheme AetherPlayer-iOS -destination 'generic/platform=iOS' build
```

## 发布构建

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="NOTARY_PROFILE" \
./Scripts/build-dmg.sh
```

该脚本会生成已签名、公证并完成 stapling 的 Universal `.dmg`。设置 `DEVELOPER_ID` 可生成本地签名构建；同时设置 `NOTARY_PROFILE` 才会用于分发公证。

## 更新记录

详见 [CHANGELOG.md](CHANGELOG.md)。其中会区分上游应用版本、当前源码包的可复现性材料，以及尚未作为正式发布验证的内容。

## 许可证

[LGPL-3.0](LICENSE)，与 AetherEngine 和上游 FFmpeg 保持一致。
