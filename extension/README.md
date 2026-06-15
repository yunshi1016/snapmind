# SnapMind URL Bridge（浏览器扩展）

把当前浏览器标签页的 URL 推送给 SnapMind 桌面应用，让截图笔记的「来源链接」自动带上网页地址。

## 原理

- SnapMind 桌面端在本地回环 `127.0.0.1:49219` 起一个小服务。
- 本扩展在标签页/窗口焦点变化时，把**当前聚焦窗口的活动标签页 URL** POST 给它。
- 截图时若前台是浏览器，桌面端就用这个缓存的 URL 作为来源链接。
- 不在浏览器、或扩展未装、或 SnapMind 未运行 → 来源链接留空，互不影响。

数据只在你本机回环传输，不出本地；推送的仅是当前页 URL。

## 安装（Chrome / Edge，开发者模式加载）

1. 打开 `chrome://extensions`（Edge 为 `edge://extensions`）。
2. 右上角打开「开发者模式」。
3. 点「加载已解压的扩展程序」，选择本 `extension/` 文件夹。
4. 确保 SnapMind 桌面应用在运行（托盘常驻即可）。

之后在网页上按 SnapMind 快捷键截图，笔记的「来源链接」就会带上该网页 URL。

## 说明

- 仅推送 `http/https` 页面；`chrome://`、新标签页等不推送（来源链接留空）。
- 目标 Chromium 系（Chrome/Edge/Brave/Vivaldi）。Firefox 需对 manifest 略作适配（后续支持）。
- 端口固定 `49219`，与桌面端 `BrowserUrlServer` 对应。
