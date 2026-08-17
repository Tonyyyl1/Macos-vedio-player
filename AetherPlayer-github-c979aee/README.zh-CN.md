# AetherPlayer

[English](README.md)

基于 [AetherEngine](https://github.com/superuser404notfound/AetherEngine) 的原生 macOS 媒体播放器。

这是已验证提交 `c979aee`（`0.11.0`，构建号 `49`）的 GitHub 上传版源码快照。目录包含源码、本地媒体夹具、兼容性清单与验证脚本；不包含 `.git`、DerivedData、构建产物、签名证书、公证凭据或任何用户本机配置。

## 范围与状态

当前交付范围为 macOS 14.0 及以上版本，支持 Apple Silicon 和 Intel Mac。iOS 源码与 target 仍保留在工程中以维持兼容性，但不属于本开发线的新增计划或验收范围。

macOS M1--M7 兼容性工作已经完成，覆盖播放会话身份与陈旧回调防护、生命周期协调、沙盒安全作用域文件访问，以及以下本地媒体的垂直验证：

- MP4/MOV：H.264 + AAC
- Matroska：H.264 + AAC + SRT、HEVC Main10 + AAC
- WebM：VP9 + Opus、AV1 Main + Opus
- Matroska：HEVC Main10 + E-AC-3 + SRT、VP9 + PGS、HEVC Main10 HDR10
- 损坏媒体的明确失败诊断

每个 ready 状态的夹具都具备 Probe、播放路线、首帧、Seek 与运行态验证。当前清单为 10 个 ready 夹具，0 个 planned。

## 构建

需要 macOS 14+、当前版本 Xcode，以及用于下载 Swift Package Manager 依赖的网络连接。仓库已包含 Xcode 工程，可直接构建：

```bash
xcodebuild -project AetherPlayer.xcodeproj \
  -scheme AetherPlayer \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

`project.yml` 是 XcodeGen 的工程源文件。修改它后请重新生成工程：

```bash
brew install xcodegen
xcodegen generate
```

## 验证

先检查夹具清单：

```bash
ruby Scripts/verify-fixtures.rb
```

再运行 macOS 夹具测试：

```bash
xcodebuild -project AetherPlayer.xcodeproj \
  -scheme AetherPlayer \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:AetherPlayerTests/FixtureProbeTests \
  test
```

Intel Mac 请将 `arch=arm64` 改为 `arch=x86_64`。

## 发布

如需创建用户可安装的站外分发 DMG，需要有效的 Apple Developer Program 会员、`Developer ID Application` 签名身份和公证凭据：

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="AetherPlayerNotary" \
./Scripts/build-dmg.sh
```

脚本会创建已签名 DMG；提供 `NOTARY_PROFILE` 时还会完成 Apple 公证与装订。不要将证书、私钥、App 专用密码或钥匙串 profile 提交到仓库。

## 上传 GitHub

先在 GitHub 创建一个空仓库，然后在本文件夹执行：

```bash
git init
git add .
git commit -m "Initial import: AetherPlayer macOS M1-M7"
git branch -M main
git remote add origin https://github.com/YOUR_ACCOUNT/AetherPlayer.git
git push -u origin main
```

也可以用 GitHub Desktop 把该目录作为本地仓库添加并发布。请不要将生成的 `.app`、DMG、`DerivedData` 或签名材料上传到源码仓库。

## 许可证

[LGPL-3.0](LICENSE)。AetherPlayer 依赖 [AetherEngine](https://github.com/superuser404notfound/AetherEngine)，Swift Package Manager 会按照 `project.yml` 中声明的修订版本解析该依赖。
