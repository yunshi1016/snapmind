// SnapMind URL Bridge —— 把当前聚焦窗口的活动标签页 URL 推送给 SnapMind 桌面应用。
// SnapMind 桌面端在 127.0.0.1:49219 监听；未运行时 fetch 静默失败，不影响浏览器。

const ENDPOINT = "http://127.0.0.1:49219/url";

async function post(url, focused) {
  try {
    await fetch(ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url, focused }),
    });
  } catch (e) {
    // SnapMind 未运行，忽略。
  }
}

// 取当前聚焦窗口的活动标签页 URL 并推送。
async function pushActive(focused) {
  try {
    if (!focused) {
      await post("", false);
      return;
    }
    const win = await chrome.windows.getLastFocused();
    if (!win || win.id === chrome.windows.WINDOW_ID_NONE) {
      await post("", false);
      return;
    }
    const tabs = await chrome.tabs.query({ active: true, windowId: win.id });
    const tab = tabs && tabs[0];
    const u = tab && tab.url ? tab.url : "";
    // 只推送真实网页（http/https），排除 chrome:// 新标签页等。
    const url = /^https?:\/\//i.test(u) ? u : "";
    await post(url, true);
  } catch (e) {
    // 忽略任何异常。
  }
}

chrome.tabs.onActivated.addListener(() => pushActive(true));
chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (info.url || info.status === "complete") pushActive(true);
});
chrome.windows.onFocusChanged.addListener((winId) => {
  pushActive(winId !== chrome.windows.WINDOW_ID_NONE);
});
chrome.runtime.onStartup.addListener(() => pushActive(true));
chrome.runtime.onInstalled.addListener(() => pushActive(true));
