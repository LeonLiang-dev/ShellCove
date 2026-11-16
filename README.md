# ShellCove

**macOS 开发者的服务器资料库** —— 原生 Swift 编写的 SSH 连接管理器：把「记住一台机器」和「连上它」变成同一件事。

## 功能亮点

- **服务器资料库**：分组、彩色标签、连接历史（保留最近 200 条），生产/测试/开发环境一眼分清
- **内置终端**：基于 [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 的 SSH 终端，连接不另开窗口，⌘W 关闭会话
- **多种认证**：密码（存入系统钥匙串）/ 私钥 / 默认 SSH 配置，支持连接超时设置
- **在线探活**：手动 TCP 探测 + 可选自动健康检查，左栏直接看机器死活
- **`~/.ssh/config` 导入**：批量解析导入，主机三元组自动去重
- **JSON 备份**：全量导出/导入，原子写入 + 版本校验，**绝不包含密码与私钥内容**
- **菜单栏快捷入口**：最近连接的 5 台机器，点一下直接连
- **命令面板**（⌘K）、复制 ssh 命令（⌘⌥C）、全中文界面与排障提示
- **深浅色外观**跟随系统，Liquid Glass 材质，轻量（安装包 < 3 MB）

## 下载安装

1. 下载仓库中的 [`ShellCove-1.0.0.dmg`](https://github.com/LeonLiang-dev/ShellCove/raw/main/ShellCove-1.0.0.dmg)
2. 打开 DMG，将 ShellCove 拖入「应用程序」
3. 首次打开：**右键 → 「打开」→ 再点「打开」**（当前版本未做开发者签名公证，放行一次即可）

## 从源码构建

环境要求：macOS 13+，Xcode 15+（含命令行工具），[xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen

make gen      # 生成 ShellCove.xcodeproj
make build    # 构建并运行
make test     # 运行 48 项单元测试
```

日常开发也可直接用 SwiftPM：

```bash
swift build
swift test
```

## 数据与隐私

ShellCove 不内置 SSH 库，直接调用系统 `/usr/bin/ssh`；所有数据只留在这台 Mac 上：

- 服务器资料与连接记录：`~/Library/Application Support/ShellCove/`（本地 SQLite）
- 密码：系统钥匙串（Keychain），备份额外校验保证永不导出
- 无任何遥测、无网络上报——只有你主动发起的 SSH/探活连接

## 技术栈

| 层 | 选型 |
|---|---|
| UI | SwiftUI + Liquid Glass |
| 数据 | SwiftData（本地 SQLite） |
| 终端 | SwiftTerm + `/usr/bin/ssh` |
| 工程 | SwiftPM + XcodeGen + Makefile |

## License

[Apache-2.0](LICENSE)
