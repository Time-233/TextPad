# TextPad · 文本记事本（iOS）

一个给自己用的 iPhone 纯文本编辑器：新建 / 编辑 / 重命名 / 删除 / 导入导出 txt、ini、conf、json、md、log、csv 等文本文件，支持 UTF-8 / GB18030 / UTF-16 编码，界面全中文。

没有 Mac 也能装：源码推到 GitHub 后，由 **GitHub Actions 的 macOS 机器自动编译**，产出未签名 `TextPad.ipa`，再用 Windows 上的 Sideloadly 用你自己的 Apple ID 签名装进 iPhone。

## 目录结构

```
.github/workflows/build.yml      GitHub Actions：编译 + 打包 ipa + 发布 Release
project.yml                      XcodeGen 工程描述（自动生成 .xcodeproj）
Support/Info.plist               App 配置：文件共享、文档类型、权限说明
TextPad/                         SwiftUI 源码
Assets.xcassets/                 图标目录（AppIcon.png 由脚本在编译时生成）
scripts/make_icon.py             纯标准库画 1024x1024 图标
```

## 功能

- 文件列表：文件夹、搜索、左滑重命名 / 复制 / 删除、下拉刷新
- 新建文件：可选 txt / ini / md / json / csv / log / conf / cfg / xml / yaml 等扩展名，可写入示例内容
- 编辑器：等宽字体、字号调节、字数行数统计、正文查找、自动保存（退出/切后台时落盘）
- 编码：UTF-8 / GB18030（GBK 中文老文件）/ UTF-16，读写都按所选编码
- 和系统打通：`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`，
  在 iPhone「文件」App →「我的 iPhone」→「文本记事本」里能直接看到这些文件；
  也可以用 iTunes / 爱思助手的「文件共享」把文件拖进拖出
- 分享：编辑器菜单里可以直接把文件分享到微信、邮件、隔空投送

## 自己编译

推到 GitHub 后自动跑，也可以在 Actions 页面点 `Run workflow` 手动触发。
产物有两个地方可下：

- Releases：`https://github.com/<你的用户名>/TextPad/releases`（推荐，直接下 ipa）
- Actions → 对应运行记录 → Artifacts（zip 里是 ipa）

## 安装到 iPhone（Windows）

1. 电脑装 iTunes（必须是从 apple.com 下载的桌面版，不要用微软商店版，否则缺驱动）
2. 装 Sideloadly（sideloadly.io）
3. iPhone 用数据线连电脑，手机上点「信任此电脑」
4. Sideloadly 里选设备 → 把 `TextPad.ipa` 拖进 IPA 框 → 填自己的 Apple ID → Start
5. 手机上：设置 → 通用 → VPN 与设备管理 → 信任你的开发者证书
6. 免费 Apple ID 签的 App 有效期 7 天，到期用同样步骤重签一次；付费开发者账号（$99/年）可签 1 年

## 说明

- 仓库里不带任何签名证书，CI 只产出**未签名** ipa，签名在你自己的电脑上完成
- Bundle ID 默认 `com.textpad.editor`，Sideloadly 会自动加后缀避免冲突
