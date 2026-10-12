# LoRA 对比台

给 Dreadmyst Clone 原型选 LoRA 用的本地小工具：**同一提示词 + 同一 seed + 同一参数，只换 LoRA**，
把 SD 1.5 / SDXL 下不同 LoRA 的出图并排摆出来，人工打分后导出 `RESULTS.md`——
用它决定**最终保留哪些 LoRA**。

- 纯静态前端（HTML / CSS / JS，无框架、无构建步骤）
- 一个本地 Python 服务负责：静态托管 + **Forge API 反向代理** + 结果落盘

---

## 为什么必须有一个本地服务？

因为 **Forge 默认没开 CORS**（`GET /sdapi/v1/cmd-flags` 的 `cors_allow_origins` 是空字符串），
浏览器里的 `fetch` 直连 `http://127.0.0.1:7860` 会被拦。
所以 `serve.py` 提供 `/forge/*` 反向代理，前端一律请求同源的 `/forge/...`。
它同时顺带解决了"把结果写回仓库"的问题（浏览器不能直接写磁盘）。

> 另外要装 `python`（本机用 `D:\AI\python-full\python.exe`，`start.bat` 会自动找）。

---

## 快速开始

1. **先启动 Forge —— 必须用 `webui-user.bat`**（它带 `COMMANDLINE_ARGS=--theme dark --api`）。
   ⚠️ 直接跑 `webui.bat` 不会带 `--api`，出图接口会返回 `{"detail":"Not Found"}`。
2. **双击 `start.bat`** —— 它会找到 python、在 `127.0.0.1:7788` 起服务并自动打开浏览器。
3. 界面里按 1→5 走：
   - **1 提示词**：从 A~F 六套模板里选一套，可直接编辑；点「保存修改」写回 `data/prompts.json`
     （旧版会压进「修改历史」，可回退）。
   - **2 参数**：选 checkpoint（SD 1.5 / SDXL，会自动带出该 base 的推荐尺寸与步数）、权重、seed。
     `seed = -1` 表示本批随机取一次后**锁死**，保证全批可比。
   - **3 对比对象**：勾要测的 LoRA（`（无 LoRA 基线）` 是必看的对照组）。
   - **4 结果**：每张图打 0~5 星 + 选结论（保留 / 待定 / 淘汰）+ 填备注，改完自动落盘。
   - **5 结论汇总** + 右上角 **「导出 RESULTS.md」**。

## 文件说明

| 路径 | 说明 | 入库？ |
| --- | --- | --- |
| `data/prompts.json` | 提示词库（含每套模板的修改历史） | ✅ |
| `data/loras.json` | LoRA 元数据：用途 / 触发词 / **base** / 许可 / 署名义务 | ✅ |
| `data/results.json` | 全部对比记录（含评分与结论） | ✅ |
| `RESULTS.md` | 由记录生成的结论文档（分组对比 + 建议保留哪些 LoRA） | ✅ |
| `images/*.png` | 生成的对比图（过程产物，体积大） | ❌ 已被 `.gitignore` 排除 |

`data/loras.json` 里的 `base` 字段来自 Civitai `model-versions` API 的 `baseModel`——
**它决定这个 LoRA 能在哪个 checkpoint 上测**。

---

## 两条硬约束（别绕过）

1. **LoRA 与 base 绑定**：SD 1.5 训练的 LoRA 拿到 SDXL 上跑没有意义（交叉注意力维度不同）。
   界面会把与当前 checkpoint 不兼容的 LoRA 置灰；确有需要可勾「允许跨 base 测试」，但结果不可信。
   > 现状：本机 9 个 LoRA **全部是 SD 1.5**，SDXL 侧目前只有基线可测（见 `docs/tasks/backlog.md` T-05）。
2. **公平对比 = 只换 LoRA**：批量生成时 seed / 步数 / CFG / 尺寸 / 采样器全程锁定；
   勾了「自动注入注册表里的触发词」时，各 LoRA 的最终提示词差异**只有** LoRA 标签 + 它自己的触发词。

---

## 排错

| 现象 | 原因 / 处理 |
| --- | --- |
| 页面顶部红条：`本地服务没有响应` | 没起服务。双击 `start.bat`，或 `python serve.py` |
| 双击 `index.html` 直接打开 | 不行。必须走 `http://127.0.0.1:7788/`（否则既调不到 Forge 也写不了盘） |
| `读不到 Forge 的 LoRA 列表` / 出图 `{"detail":"Not Found"}` | Forge 没启动，或**启动时没带 `--api`**（要用 `webui-user.bat`） |
| `Forge 不可达（http://127.0.0.1:7860）` | Forge 进程没在跑；`502` 是代理如实转达 |
| 端口 7788 被占 | `python serve.py --port 7799` |
| 想换 Forge 地址 | `python serve.py --forge http://127.0.0.1:7861` |
| 改完 JS 没生效 | 服务已发 `Cache-Control: no-store`；仍异常就 Ctrl+F5 |
| 页面静默失灵 | 顶部横幅会显示前端异常（`index.html` 里有全局 `error` / `unhandledrejection` 兜底） |

本机没有 `node`，所以自带了替代检查（语法括号 / 字符串闭合 / HTML id 引用一致性）：

```bash
python _check_static.py
```

---

## 目录结构

```
tools/lora-compare/
├── index.html        界面骨架（含前端异常兜底）
├── styles.css        深色样式
├── app.js            全部逻辑（无框架）
├── serve.py          本地服务：静态 + /forge 反代 + /api/save|image|delete
├── start.bat         一键启动（自动找 python）
├── _check_static.py  静态自检（替代 node 语法检查）
├── data/            prompts.json · loras.json · results.json
├── images/          生成的对比图（不入库）
└── RESULTS.md       导出的结论文档
```

相关文档：提示词源头 `assets/_PROMPTS.md`、许可登记 `assets/_LICENSES.md`、
待办与口径 `docs/tasks/backlog.md`。
