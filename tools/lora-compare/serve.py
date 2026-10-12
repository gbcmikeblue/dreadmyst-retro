#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LoRA 对比台 · 本地服务（静态文件 + Forge 反向代理 + 结果落盘）

为什么必须有它
--------------
Forge 启动时**没有开 CORS**（`GET /sdapi/v1/cmd-flags` 的 `cors_allow_origins` 为空字符串），
所以浏览器里的 fetch 无法直连 `http://127.0.0.1:7860` —— 纯静态页调不通 Forge API。
本脚本提供三件事：

1. **静态文件服务** —— 前端就是纯 HTML/CSS/JS，没有构建步骤。
2. **`/forge/*` 反向代理** —— 把请求转给 Forge API，绕开 CORS；线程池处理，
   所以出图期间还能同时轮询进度条。
3. **`/api/save`、`/api/image`、`/api/delete`** —— 把提示词修改、对比记录与生成图落盘到本目录。

用法
----
双击 `start.bat`，或：`python serve.py --port 7788`（`--forge` 可改 Forge 地址）
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import threading
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib import error as urlerror
from urllib import request as urlrequest
from urllib.parse import parse_qs, urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
FORGE = "http://127.0.0.1:7860"      # 旧后端（Forge / SD），仅保留兼容
COMFY = "http://127.0.0.1:8188"      # 现用后端：ComfyUI + Qwen-Image 2.1

MAX_BODY = 64 * 1024 * 1024   # 64MB：base64 图片够用
PROXY_TIMEOUT = 3600          # 出图 / 切模型都可能很久，别让代理先超时
ALLOWED_EXT = {".json", ".md", ".png", ".txt", ".csv", ".webp", ".jpg", ".jpeg"}


class Handler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "lora-compare/1.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    # ---------------- 基础设施 ----------------

    def end_headers(self):
        # 开发期禁缓存，避免改完 JS 还看到旧版本
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        # 默认只报 4xx/5xx（避免出图时刷屏）；VERBOSE=1 时全打。
        # 注意 args 是完整的 ('"%s" %s %s', requestline, code, size)，
        # 必须用 fmt % args 整体格式化 —— 截取 args[2:] 会参数不足抛 TypeError，
        # 而它是在 send_response() 内部调用的，一崩就整条响应变成"空回复"。
        code = str(args[1]) if len(args) > 1 else ""
        bad = code[:1] in ("4", "5")
        if not (bad or os.environ.get("VERBOSE")):
            return
        stream = sys.stderr if bad else sys.stdout
        try:
            stream.write("  [%s] %s\n" % (code, fmt % args))
        except Exception:
            stream.write("  [%s] %s\n" % (code, args))

    def list_directory(self, path):
        self.send_error(404, "No directory listing")
        return None

    def _json(self, code, obj):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0:
            return None
        if n > MAX_BODY:
            raise ValueError("请求体过大（%d 字节）" % n)
        return self.rfile.read(n)

    def _resolve(self, rel):
        """把相对路径限制在本目录内，并限制扩展名；非法返回 None。"""
        rel = str(rel).replace("\\", "/").lstrip("/")
        parts = [p for p in rel.split("/") if p not in ("", ".")]
        if not parts or ".." in parts:
            return None
        target = os.path.normpath(os.path.join(ROOT, *parts))
        if os.path.commonpath([ROOT, target]) != ROOT:
            return None
        if os.path.splitext(target)[1].lower() not in ALLOWED_EXT:
            return None
        return target

    # ---------------- 路由 ----------------

    def do_GET(self):
        if self.path.startswith("/forge/"):
            return self._proxy("GET")
        if self.path.startswith("/comfy/"):
            return self._proxy("GET", COMFY, "/comfy")
        if self.path == "/api/ping":
            return self._json(200, {"ok": True, "forge": FORGE, "root": ROOT})
        if self.path.startswith("/api/list"):
            return self._list_dir()
        return super().do_GET()

    def do_POST(self):
        if self.path.startswith("/forge/"):
            return self._proxy("POST")
        if self.path.startswith("/comfy/"):
            return self._proxy("POST", COMFY, "/comfy")
        if self.path == "/api/save":
            return self._save_text()
        if self.path == "/api/image":
            return self._save_image()
        return self._json(404, {"ok": False, "error": "未知接口: " + self.path})

    def do_DELETE(self):
        if self.path != "/api/delete":
            return self._json(404, {"ok": False, "error": "未知接口: " + self.path})
        try:
            payload = json.loads(self._body() or b"{}")
        except Exception as exc:
            return self._json(400, {"ok": False, "error": "JSON 解析失败: %s" % exc})
        target = self._resolve(payload.get("path", ""))
        if target is None:
            return self._json(403, {"ok": False, "error": "路径非法: %s" % payload.get("path")})
        if os.path.isfile(target):
            os.remove(target)
            return self._json(200, {"ok": True, "removed": os.path.relpath(target, ROOT)})
        return self._json(200, {"ok": True, "removed": None})

    def _resolve_dir(self, rel):
        """目录白名单：只允许本目录内的子目录（用于列 images/ 当图生图底图）。"""
        rel = str(rel).replace("\\", "/").strip("/")
        parts = [p for p in rel.split("/") if p not in ("", ".")]
        if not parts or ".." in parts:
            return None
        target = os.path.normpath(os.path.join(ROOT, *parts))
        if os.path.commonpath([ROOT, target]) != ROOT:
            return None
        return target

    def _list_dir(self):
        """/api/list?dir=images —— 列出目录内的可读文件（给图生图的「选底图」用）。"""
        q = parse_qs(urlparse(self.path).query)
        rel = (q.get("dir") or ["images"])[0]
        target = self._resolve_dir(rel)
        if target is None:
            return self._json(403, {"ok": False, "error": "目录非法: %s" % rel})
        files = []
        if os.path.isdir(target):
            for name in os.listdir(target):
                p = os.path.join(target, name)
                if not os.path.isfile(p):
                    continue
                if os.path.splitext(name)[1].lower() not in ALLOWED_EXT:
                    continue
                files.append({"name": name, "bytes": os.path.getsize(p),
                              "mtime": int(os.path.getmtime(p))})
        files.sort(key=lambda x: -x["mtime"])
        return self._json(200, {"ok": True, "dir": rel, "files": files})

    # ---------------- 后端反代（/forge = 旧 Forge；/comfy = ComfyUI） ----------------

    def _proxy(self, method, base=None, prefix="/forge"):
        base = base or FORGE
        upstream = base + self.path[len(prefix):]
        try:
            body = self._body()
        except ValueError as exc:
            return self._json(413, {"ok": False, "error": str(exc)})
        req = urlrequest.Request(upstream, data=body, method=method)
        ctype = self.headers.get("Content-Type")
        if ctype:
            req.add_header("Content-Type", ctype)
        try:
            with urlrequest.urlopen(req, timeout=PROXY_TIMEOUT) as resp:
                # 取图（/comfy/view）返回的是二进制，这里原样转发
                return self._relay(resp.status, resp.headers.get("Content-Type"), resp.read())
        except urlerror.HTTPError as exc:
            return self._relay(exc.code, exc.headers.get("Content-Type"), exc.read())
        except Exception as exc:
            return self._json(502, {"ok": False,
                                    "error": "后端不可达（%s）：%s" % (base, exc)})

    def _relay(self, code, ctype, data):
        self.send_response(code)
        self.send_header("Content-Type", ctype or "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    # ---------------- 落盘 ----------------

    def _save_text(self):
        try:
            payload = json.loads(self._body() or b"{}")
        except Exception as exc:
            return self._json(400, {"ok": False, "error": "JSON 解析失败: %s" % exc})
        rel, content = payload.get("path", ""), payload.get("content")
        if not isinstance(content, str):
            return self._json(400, {"ok": False, "error": "content 必须是字符串"})
        target = self._resolve(rel)
        if target is None:
            return self._json(403, {"ok": False, "error": "路径非法: %s" % rel})
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "w", encoding="utf-8", newline="\n") as fp:
            fp.write(content)
        return self._json(200, {"ok": True, "path": os.path.relpath(target, ROOT),
                                "bytes": len(content.encode("utf-8"))})

    def _save_image(self):
        try:
            payload = json.loads(self._body() or b"{}")
        except Exception as exc:
            return self._json(400, {"ok": False, "error": "JSON 解析失败: %s" % exc})
        name = str(payload.get("name", ""))
        data = str(payload.get("data", ""))
        if "," in data[:64]:                      # 去掉 data:image/png;base64, 前缀
            data = data.split(",", 1)[1]
        target = self._resolve("images/" + name)
        if target is None:
            return self._json(403, {"ok": False, "error": "文件名非法: %s" % name})
        try:
            raw = base64.b64decode(data)
        except Exception as exc:
            return self._json(400, {"ok": False, "error": "base64 解码失败: %s" % exc})
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as fp:
            fp.write(raw)
        return self._json(200, {"ok": True, "path": "images/" + name, "bytes": len(raw)})


def main():
    global FORGE, COMFY
    ap = argparse.ArgumentParser(description="LoRA 对比台 · 本地服务")
    ap.add_argument("--port", type=int, default=7788, help="监听端口（默认 7788）")
    ap.add_argument("--forge", default="http://127.0.0.1:7860", help="旧 Forge API 地址")
    ap.add_argument("--comfy", default="http://127.0.0.1:8188", help="ComfyUI 地址")
    ap.add_argument("--no-browser", action="store_true", help="不自动打开浏览器")
    args = ap.parse_args()
    FORGE = args.forge.rstrip("/")
    COMFY = args.comfy.rstrip("/")

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True

    url = "http://127.0.0.1:%d/" % args.port
    print("=" * 62)
    print("  LoRA 对比台")
    print("  界面   : %s" % url)
    print("  ComfyUI: %s" % COMFY)
    print("  Forge  : %s（旧后端，可不用）" % FORGE)
    print("  目录   : %s" % ROOT)
    print("  Ctrl+C 退出")
    print("=" * 62)
    if not args.no_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n已退出")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
