---
title: Mac神器hammerspoon
date: 2016-05-09T07:41:58+08:00
tags:
  - Mac
  - 工具
  - 效率
categories:
  - 生活随笔
draft: false
---
一键切换常用应用，一键调整桌面布局，Love Mac，Love Hammerspoon。
<!--more-->
# What is Hammerspoon?
This is a tool for powerful automation of OS X. At its core, Hammerspoon is just a bridge between the operating system and a Lua scripting engine.
What gives Hammerspoon its power is a set of extensions that expose specific pieces of system functionality, to the user.
Hammerspoon可以自定义Mac OS X的快捷键（例如`Command`+`Shift`+`h`）以实现多类操作，我个人主要将其用于窗口管理（比moom for mac更加高效）与应用启动（比alfred for mac更加高效）。

* Hammerspoon:  https://www.hammerspoon.org/
* Github:       https://github.com/Hammerspoon/hammerspoon
* [Hammerspoon API Documentation](https://www.hammerspoon.org/docs/index.html)

# Download
1. Download the [latest release](https://github.com/Hammerspoon/hammerspoon/releases/), Drag `Hammerspoon.app` from your `Downloads` folder to `Applications`;
2. use [Homebrew](https://brew.sh/) tool(recommend)

        $ brew cask install hammerspoon

# Getting Started Guide
参考：[Getting Started Guide](https://www.hammerspoon.org/go/)
`~/.hammerspoon`为hammerspoon的配置目录，配置文件`init.lua`基于Lua脚本语言编写。

    $ mkdir -p ~/.hammerspoon
    $ cd ~/.hammerspoon
    $ touch init.lua

之后的配置就是往`init.lua`中添加配置，修改完配置后hammerspoon.app需要重新加载(`Menu -> hammerspoon.app -> Reload Config`)；
## Hello World
参考：https://www.hammerspoon.org/go/#helloworld

    $ vim init.lua
    # 添加:

    hs.hotkey.bind({'cmd', 'shift'}, 'h', function()
        hs.alert('Hello World')
    end)

保存配置文件，`Reload Config`，配置文件成效！
按`Command`+`Shift`+`h`，屏幕上就会出现一行文本`Hello World`，几秒后自动消失。

> Hammerspoon 是一个插件化的程序，像 hs.hotkey 和 hs.alert 这些都是 Hammerspoon 所集成的插件。

## Fancier Hello World
参考：https://www.hammerspoon.org/go/#fancyhelloworld

    hs.hotkey.bind({"cmd", "alt", "ctrl"}, "W", function()
        hs.notify.new({title="Hammerspoon", informativeText="Hello World"}):send()
    end)
使用Mac OS X系统自带的提示(notifications)，右上角弹窗显示`Hello World`；

# 配置示例
## 模块化设计
所以配置都放在`init.lua`里未免太过繁琐，修改起来也比较麻烦，因此在配置前设计一套模块化的脚本配置文件是很有必要的。
具体做法：不同配置写在不同文件里（例如有关启动应用的配置写在`launch.lua`中），在主配置文件`init.lua`中包含模块配置文件（可以类比C语言的include）。
配置文件的目录框架：

    ├── init.lua
    └── modules
        ├── auto_reload.lua
        ├── hotkey.lua
        ├── launch.lua
        ├── screens.lua
        ├── system.lua
        └── windows.lua

`init.lua`:

    require "modules/hotkey"
    require "modules/screens"
    require "modules/windows"
    require "modules/launch"
    require "modules/system"
    require "modules/auto_reload"

## 快捷键设定
`~/.hammerspoon/modules/hotkey.lua`:

    hyper = {'ctrl', 'cmd'}
    hyperShift = {'ctrl', 'cmd', 'shift'}
配置快捷键前缀，其他配置文件会用到该变量`hyper`与`hyperShift`。这样配置的好处是，想要更换快捷键，只需要修改这一处即可。

## 快速启动Applications
`~/.hammerspoon/modules/launch.lua`:

    local hotkey = require 'hs.hotkey'
    local window = require 'hs.window'
    local application = require 'hs.application'

    local key2App = {
        a = 'AppCleaner',
        e = 'Evernote',
        f = 'Finder',
        g = 'Mail',
        j = 'Google Chrome',
        k = 'Preview',
        m = 'MacDown',
        p = '1Password',
        r = 'Reeder',
        s = 'System Preferences',
        z = 'Dictionary'
    }

    for key, app in pairs(key2App) do
        hotkey.bind(hyper, key, function()
            --application.launchOrFocus(app)
            toggle_application(app)
        end)
    end

    -- reload
    hotkey.bind(hyper, 'escape', function() hs.reload() end )

    -- Toggle an application between being the frontmost app, and being hidden
    function toggle_application(_app)
        -- finds a running applications
        local app = application.find(_app)

        if not app then
            -- application not running, launch app
            application.launchOrFocus(_app)
            return
        end

        -- application running, toggle hide/unhide
        local mainwin = app:mainWindow()
        if mainwin then
            if true == app:isFrontmost() then
                mainwin:application():hide()
            else
                mainwin:application():activate(true)
                mainwin:application():unhide()
                mainwin:focus()
            end
        else
            -- no windows, maybe hide
            if true == app:hide() then
                -- focus app
                application.launchOrFocus(_app)
            else
                -- nothing to do
            end
        end
    end

`key2App`指定快捷键后缀与应用的对应关系，通过`hotkey.bind`函数实现快捷键绑定，例如按`hyper`+`e`就是启动`Evernote`，按`hyper`+`p`就是启动`1Password`。
`toggle_application`函数是启动应用的具体实现，首先`application.find()`查找正在运行的app中是否有相同名称的app，没有找到则调用`application.launchOrFocus()`直接启动，找到则检查应用是否显示在最前(`app:isFrontmost()`)，在`focus`与`hide`之间切换。这样，按`hyper`+`e`就是启动`Evernote`，再次按`hyper`+`e`就是隐藏`Evernote`。
## 窗口管理
`~/.hammerspoon/modules/windows.lua`:

    require "hs.application"
    local hotkey = require 'hs.hotkey'
    local window = require 'hs.window'
    local layout = require 'hs.layout'
    local alert = require 'hs.alert'
    local hints = require 'hs.hints'
    local grid = require 'hs.grid'
    local geometry = require 'hs.geometry'

    ---- hyper [ for left one half window
    hotkey.bind(hyper, '[', function() window.focusedWindow():moveToUnit(layout.left50) end)

    -- hyper ] for right one half window
    hotkey.bind(hyper, ']', function() window.focusedWindow():moveToUnit(layout.right50) end)

    -- Hyper / to show window hints
    hotkey.bind(hyper, '/', function()
        hints.windowHints()
    end)

    -- Hotkeys to interact with the window grid
    hotkey.bind(hyper, ',', grid.show)
    hotkey.bind(hyper, 'Left', grid.pushWindowLeft)
    hotkey.bind(hyper, 'Right', grid.pushWindowRight)
    hotkey.bind(hyper, 'Up', grid.pushWindowUp)
    hotkey.bind(hyper, 'Down', grid.pushWindowDown)

hammerspoon提供的窗口管理API十分丰富，一行配置，就可以实现`hyper`+`[`使得窗口左半屏。
`window.focusedWindow():moveToUnit(layout.right50)`，使得当前focused的窗口移动到左半屏(`latest.right50`)，右半屏则为(`latest.right50`)；

三七分屏(`layout.left30`, `layout.right70`):

    -- Hotkeys to resize windows absolutely
    --hotkey.bind(hyper, '[', function() window.focusedWindow():moveToUnit(layout.left30) end)
    --hotkey.bind(hyper, ']', function() window.focusedWindow():moveToUnit(layout.right70) end)

按`hyper`+`/`显示窗口提示`hints.windowHints()`;
按`hyper`+`,`显示窗口珊格`grid.show`，可以将屏幕布局划分为九宫格，用户可以自定义当前窗口所占的空间大小。
`grid.pushWindowLeft`,`grid.pushWindowRight`实现窗口的移动，例如左半屏的窗口，通过`hyper`+`left`实现移动到右半屏，等价于`hyper`+`]`的效果。

# 配置文件参考 - SeanXP
[SeanXP-Hammerspoon](/static/hammerspoon-config-seanxp.tar.xz)
## 快捷键配置
`hyper` = `ctrl` + `cmd`
`hyperShift` = `ctrl` + `cmd` + `Shift`
## Focus Application - modules/launch.lua
| Key | Description |
|-----|-------------|
| `hyper`+`a` | Toggle AppCleaner |
| `hyper`+`b` | Toggle Notes |
| `hyper`+`c` | Toggle Calendar |
| `hyper`+`d` | (System hotkey) Define word |
| `hyper`+`e` | Toggle Evernote |
| `hyper`+`f` | Toggle Finder |
| `hyper`+`g` | Toggle Mail |
| `hyper`+`h` | Toggle Dash |
| `hyper`+`j` | Toggle Google Chrome |
| `hyper`+`k` | Toggle Preview |
| `hyper`+`m` | Toggle MacDown |
| `hyper`+`n` | Toggle NeteaseMusic |
| `hyper`+`o` | Toggle OmniToggle |
| `hyper`+`p` | Toggle 1Password |
| `hyper`+`r` | Toggle Reeder |
| `hyper`+`s` | Toggle System Preferences |
| `hyper`+`t` | Toggle Tweetbot |
| `hyper`+`u` | Toggle Ulysses |
| `hyper`+`w` | Toggle WeChat |
| `hyper`+`z` | Toggle Dictionary |
| `hyper`+`;` | Toggle iTerm |
| `hyper`+`ESC` | Reload Hammerspoon Config |
## auto reload - modules/auto_reload.lua
automatically reload the configuration whenever the file changes.
## Window Layouts - modules/windows.lua
| Key | Description |
|-----|-------------|
| `hyper`+`[` | Set the current app to left layout |
| `hyper`+`tab` | Toggle the current app to fullscreen layout or normal layout |
| `hyper`+`]` | Set the current app to right layout |
| `hyper`+`,` | Show the window grid |
| `hyper`+`Left` | Push the current app to the left screen |
| `hyper`+`Right` | Push the current app to the right screen |
| `hyper`+`Up` | Push the current app to the up screen |
| `hyper`+`Down` | Push the current app to the down screen |
| `hyper`+`/` | Show Window Hints |
## Move between displays - modules/screens.lua
| Key | Description |
|-----|-------------|
| `hyper`+ `.` | Move to next display |
| `hyperShift`+ `.` | Move to previous display |
## System hotkey - modules/system.lua
| Key | Description |
|-----|-------------|
| `hyper`+ **`** | lock screen |

# 其他教程参考
* [Getting Started Guide](https://www.hammerspoon.org/go/)
* https://github.com/Hammerspoon/hammerspoon/wiki/Sample-Configurations
* https://github.com/cmsj/hammerspoon-config
* https://bezhermoso.github.io/2016/01/20/making-perfect-ramen-lua-os-x-automation-with-hammerspoon/
* [Hammerspoon, OS X 上的全能窗口管理器](https://songchenwen.com/tech/2015/04/02/hammerspoon-mac-window-manager/)
