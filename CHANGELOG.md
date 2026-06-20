# CHANGELOG

## [0.0.1] - 2026-06-21

### Core
- **Lifecycle Management**: Supported the complete lifecycle of LaunchAgents and LaunchDaemons (Start, Stop, Load, Unload, Enable, Disable) via a native macOS interface.
- **Privileged Helper**: Built-in Privileged Helper Tool with automatic registration and unregistration (using SMAppService and secure XPC communication), allowing users to manage system-wide LaunchDaemons without manual permission escalation.
- **Multi-window Support**: Supported opening independent Plist editor windows via "Open in New Window" or dragging external Plists for parallel configuration management.
- **App Preferences**: Supported customization of system service visibility, hiding disabled services, and configuring the log terminal's font size and theme colors.

### Editor
- **Dual-mode Editor**: Provided a visual Plist form editor and a real-time XML syntax highlighted preview, supporting bi-directional synchronization and dirty state warnings.
- **Undo/Redo & Shortcuts**: Form controls are deeply integrated with the system `UndoManager`, supporting `Cmd+Z` and `Cmd+Shift+Z` undo/redo actions; added `Cmd+N` for creating a new service, `Cmd+R` for refreshing the list, and `Cmd+S` for saving configurations.
- **Drag & Drop Import**: Native support for dragging and dropping external `.plist` configuration files into the app. Standard services will be localized in the sidebar list, while unknown external plists will open in independent editor windows.

### Automation
- **Shortcuts Integration**: Fully integrated with macOS AppIntents (Shortcuts), enabling automated tasks like listing services and controlling service states (Load, Unload, Start, Stop, Enable, Disable).

### Diagnostics
- **Smart Diagnostics**: Built-in Diagnostics Engine that detects potential configuration issues (such as non-existent program paths, missing redirect directories, or KeepAlive conflicts) and provides correction tips.

### Terminal & Logs
- **Log Viewer**: Integrated a terminal-like log viewer supporting real-time streaming (`tail -f` mode) for stdout/stderr redirects or system Unified Logs, with customizable log levels, font sizes, and color themes.

### Localization
- **Localization**: Localized all user-facing interface components, with special name adaptation for "Steve Shi" in Simplified Chinese.

---

### Chinese
### 核心功能
- **生命周期管理**：实现了全功能的 macOS launchd 服务管理面板，支持 LaunchAgents 和 LaunchDaemons 的完整生命周期管理（运行、停止、加载、卸载、启用、禁用）。
- **特权辅助工具**：内置 Privileged Helper Tool 自动化注册与注销（使用 SMAppService 和安全 XPC 通信），支持无需手动提权即可管理系统范围的 LaunchDaemons。
- **多窗口支持**：支持通过 `Open in New Window` 或拖拽外部 Plist 的方式在独立的 Plist 编辑窗口中进行并行配置管理。
- **系统偏好设置**：支持通过偏好设置自定义是否过滤只读系统服务、隐藏已禁用服务，以及配置日志终端字号与主题色。

### 编辑器
- **双模编辑器**：提供可视化的 Plist 表单编辑器和实时的 XML 语法高亮预览，支持修改实时相互同步与脏状态（Dirty State）提醒。
- **撤销重做 & 键盘快捷键**：表单组件深度整合了系统级 `UndoManager`，支持 `Cmd+Z` 与 `Cmd+Shift+Z` 进行属性级撤销/重做；支持快捷键 `Cmd+N` 新建服务，`Cmd+R` 刷新服务列表，`Cmd+S` 保存配置。
- **拖拽导入支持**：原生支持将外部 `.plist` 配置文件直接拖入应用中；若是系统已知 launchd 服务，会自动在列表中定位并选中；若是外部未知 Plist，将自动通过独立编辑器窗口打开。

### 自动化
- **快捷指令集成**：全面集成 macOS AppIntents（快捷指令），支持通过系统快捷指令执行列出服务、控制服务状态（Load/Unload/Start/Stop/Enable/Disable）等自动化操作。

### 智能诊断
- **智能诊断系统**：内置诊断引擎（Diagnostics Engine），能检测并分析潜在配置问题（如可执行程序或日志输出目录不存在，KeepAlive 与运行条件冲突等）并提出修正建议。

### 终端与日志
- **日志与终端查看器**：集成了终端日志查看器，支持对服务的 standardOut/standardError 重定向日志或系统 Unified Log 进行实时流式查看（`tail -f` 模式），可过滤日志等级并配置字号和颜色主题。

### 本地化
- **本地化**：深度本地化管理，支持多语言适配，并已对“轩楝 (Steve Shi)”进行专属的简体中文人名适配。
