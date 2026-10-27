# Dayline

macOS 右侧悬浮工作时间轴，使用 SwiftUI、AppKit 和 Carbon 构建。

## 功能

- 小时刻度与当日工作记录，支持切换日期。
- ⌥⌘J 呼出输入，回车添加。
- 铅笔按钮编辑内容、日期和时间，也可删除事项。
- 编辑时回车保存，Shift + 回车换行。
- 浅色磨砂背景、悬浮置顶与跨桌面显示。
- 支持窗口缩放，保存位置和尺寸；左下边缘保留不可见缩放区域。
- 菜单栏 ◷ 显示或退出。

## 构建与测试

需要 macOS 14 或更新版本，以及 Xcode Command Line Tools。

```sh
bash test.sh
bash build.sh
open .build/Dayline.app
```

构建产物是本机架构的应用，采用本地临时签名，未做 Apple 公证。

## 数据

工作记录保存在 `~/Library/Application Support/Dayline/entries.json`，不包含在源码仓库中。窗口设置保存在本机 UserDefaults。

## 当前验证范围

已验证源码构建和记录新增、修改、删除的本地持久化测试。跨应用置顶、全屏桌面、输入法和窗口缩放需在目标 macOS 桌面进行交互验证。
