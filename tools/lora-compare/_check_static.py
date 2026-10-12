#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""对比台静态自检（本机没有 node，用它替代最基本的语法/引用检查）

检查项：
  1. app.js 的字符串 / 注释是否闭合（未闭合会污染后面的代码）
  2. 括号 () [] {} 是否平衡 —— 能抓住绝大多数手写语法错误
  3. app.js 里 $('#id') 引用的 id 是否都在 index.html 里存在
  4. index.html 是否有重复 id

用法：python _check_static.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(ROOT, "app.js")
HTML = os.path.join(ROOT, "index.html")


def strip_comments_and_strings(src):
    """把字符串与注释替换掉，返回 (可分析的代码, 是否全部闭合)。"""
    out = []
    i, n = 0, len(src)
    state = None          # None | '  "  `  //  /*
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if state is None:
            if c == "/" and nxt == "/":
                state = "//"; i += 2; continue
            if c == "/" and nxt == "*":
                state = "/*"; i += 2; continue
            if c in "'\"`":
                state = c; out.append(" "); i += 1; continue
            out.append(c); i += 1; continue
        if state == "//":
            if c == "\n":
                state = None; out.append("\n")
            i += 1; continue
        if state == "/*":
            if c == "*" and nxt == "/":
                state = None; i += 2; continue
            if c == "\n":
                out.append("\n")
            i += 1; continue
        # 字符串内部
        if c == "\\":
            i += 2; continue
        if c == state:
            state = None
        elif c == "\n" and state != "`":
            out.append("\n")      # 单引号/双引号里出现换行 = 未闭合
        i += 1
    return "".join(out), state is None


def main():
    with open(APP, encoding="utf-8") as fp:
        app = fp.read()
    with open(HTML, encoding="utf-8") as fp:
        html = fp.read()

    problems = []

    code, closed = strip_comments_and_strings(app)
    if not closed:
        problems.append("app.js 有未闭合的字符串或块注释")

    pairs = {")": "(", "]": "[", "}": "{"}
    stack, line = [], 1
    for ch in code:
        if ch == "\n":
            line += 1
        elif ch in "([{":
            stack.append((ch, line))
        elif ch in ")]}":
            if not stack or stack[-1][0] != pairs[ch]:
                problems.append("app.js 第 %d 行多出 '%s'" % (line, ch))
            else:
                stack.pop()
    for ch, ln in stack:
        problems.append("app.js 第 %d 行的 '%s' 没有闭合" % (ln, ch))

    used = set(re.findall(r"\$\('#([A-Za-z0-9_-]+)'\)", app))
    defined = set(re.findall(r'id="([A-Za-z0-9_-]+)"', html))
    for missing in sorted(used - defined):
        problems.append("app.js 用了 $('#%s')，但 index.html 里没有这个 id" % missing)

    all_ids = re.findall(r'id="([A-Za-z0-9_-]+)"', html)
    for dup in sorted({x for x in all_ids if all_ids.count(x) > 1}):
        problems.append("index.html 里 id=\"%s\" 重复出现" % dup)

    unused = sorted(defined - used)
    if unused:
        print("[提示] index.html 定义但 app.js 未用 $('#id') 取的 id：%s" % ", ".join(unused))

    if problems:
        print("发现问题 %d 个：" % len(problems))
        for p in problems:
            print("  - " + p)
        return 1
    print("静态自检通过：字符串闭合 / 括号平衡 / id 引用一致（app.js 引用 %d 个 id）" % len(used))
    return 0


if __name__ == "__main__":
    sys.exit(main())
