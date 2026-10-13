#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""A4 多视角设定图（2×2 一图流）→ 单张 sprite 裁切。

版面约定（与 prompts.json 的 A4 模板一致）：
    左上 = front ｜ 右上 = iso（3/4 俯视） ｜ 左下 = side ｜ 右下 = back

做法：
  1) 把画布按 2×2 切成四格（也可 --mode auto 用 alpha 连通域定位，需要 numpy）
  2) 每格按 alpha 收紧到人物 bbox + 留白（去掉空格子与多余透明边）
  3) **默认四个视角共用同一缩放系数**（以最高的那个人形为基准）→ 视角之间相对比例一致，
     可直接进游戏；否则每个视角各自放大到满框，比例会失真
  4) 等比缩放进 size×size 的正方形画布，**底对齐**（脚底对齐），透明底与 alpha 原样保留
  5) 输出 size×size 的 PNG，命名 `<name>_<view>.png`

用法（用 venv-comfy 的 python 跑，Pillow 已装）：
  D:\\AI\\venv-comfy\\Scripts\\python.exe crop_sheet.py images/_mv_1536.png
  ... crop_sheet.py images/_mv_1536.png --name enemy_slime --size 128
  ... crop_sheet.py images/_mv_1536.png --name enemy_slime --out D:\\yiyi\\dreadmyst-1\\assets
  ... crop_sheet.py x.png --mode auto            # alpha 连通域定位（更抗偏移，需 numpy）
  ... crop_sheet.py x.png --views front,iso,side,back --pad 0.06

默认输出目录：<图所在目录>/<图名>_crops/
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("缺 Pillow：请用 D:\\AI\\venv-comfy\\Scripts\\python.exe 运行本脚本", file=sys.stderr)
    sys.exit(2)

QUADRANTS = {  # 2×2 版面 → 视角名
    (0, 0): "front",  # 左上
    (0, 1): "iso",    # 右上（3/4 俯视）
    (1, 0): "side",   # 左下
    (1, 1): "back",   # 右下
}


def parse_args():
    ap = argparse.ArgumentParser(description="A4 多视角设定图 → 单张 sprite 裁切",
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    ap.add_argument("sheet", help="设定图 PNG（A4 模板出的 2×2 一图流）")
    ap.add_argument("--out", default=None, help="输出目录（默认 <图目录>/<图名>_crops）")
    ap.add_argument("--name", default=None, help="输出名前缀（默认用图名）")
    ap.add_argument("--size", type=int, default=128, help="输出 sprite 边长（正方形）")
    ap.add_argument("--views", default="front,iso,side,back",
                    help="按 左上/右上/左下/右下 顺序的视角名")
    ap.add_argument("--mode", choices=["grid", "auto"], default="grid",
                    help="grid = 直接按 2×2 切；auto = alpha 连通域定位（需 numpy）")
    ap.add_argument("--pad", type=float, default=0.04, help="人物 bbox 外再留的余量（占长边比例）")
    ap.add_argument("--alpha-threshold", type=float, default=0.35, help="判定为人物像素的 alpha 阈值")
    ap.add_argument("--no-common-scale", action="store_true",
                    help="关掉「四视角共用缩放」——每格各自放大到满框（比例可能失真）")
    ap.add_argument("--anchor", choices=["bottom", "center"], default="bottom",
                    help="缩放在画布上的对齐方式（bottom = 脚底对齐）")
    return ap.parse_args()


def quadrant_boxes(im: Image.Image, alpha_threshold: float):
    """grid 模式：按 2×2 切画布，再在每格内按 alpha 收紧。"""
    W, H = im.size
    alpha = im.getchannel("A")
    boxes = {}
    for (row, col), view in QUADRANTS.items():
        x0, y0 = col * W // 2, row * H // 2
        x1, y1 = (col + 1) * W // 2, (row + 1) * H // 2
        cell_alpha = alpha.crop((x0, y0, x1, y1))
        mask = cell_alpha.point(lambda v: 255 if v >= int(alpha_threshold * 255) else 0)
        bbox = mask.getbbox()
        if bbox is None:  # 空格子
            boxes[view] = None
            continue
        boxes[view] = (x0 + bbox[0], y0 + bbox[1], x0 + bbox[2], y0 + bbox[3])
    return boxes


def auto_boxes(im: Image.Image, alpha_threshold: float):
    """auto 模式：**在每个格位内**做 alpha 连通域定位（降采样 + 膨胀合并零碎部件）。

    比全图连通域稳：不会把相邻两格的人形合并成一块，也不会整格丢失；
    同时仍能抗「人形没画在格子正中」的偏移（按最大连通域收紧）。
    """
    try:
        import numpy as np
    except ImportError:
        print("--mode auto 需要 numpy；退回 grid 模式", file=sys.stderr)
        return quadrant_boxes(im, alpha_threshold)

    W, H = im.size
    s = 192  # 每格内的工作分辨率（2048² 下每格也就 1024² → 192 足够定位）
    alpha_small = im.getchannel("A").resize((s, s), Image.NEAREST)
    arr = np.asarray(alpha_small, dtype=np.float32) / 255.0

    boxes = {}
    for (row, col), view in QUADRANTS.items():
        x0s, y0s = col * s // 2, row * s // 2
        cell = arr[y0s:(row + 1) * s // 2, x0s:(col + 1) * s // 2]
        m = cell >= alpha_threshold
        if not m.any():
            boxes[view] = None
            continue
        for _ in range(2):  # 膨胀两格：把法杖 / 发梢之类零碎部件并回主体
            m = m | np.roll(m, 1, 0) | np.roll(m, -1, 0) | np.roll(m, 1, 1) | np.roll(m, -1, 1)
        seen = np.zeros_like(m, dtype=bool)
        best = None
        for i in range(m.shape[0]):
            for j in range(m.shape[1]):
                if not m[i, j] or seen[i, j]:
                    continue
                stack, cells = [(i, j)], []
                seen[i, j] = True
                while stack:
                    y, x = stack.pop()
                    cells.append((y, x))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and m[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
                if best is None or len(cells) > len(best):
                    best = cells
        ys = [c[0] for c in best]
        xs = [c[1] for c in best]
        # 工作分辨率 → 原图坐标
        sx, sy = W / s, H / s
        boxes[view] = (int((x0s + min(xs)) * sx), int((y0s + min(ys)) * sy),
                       int((x0s + max(xs) + 1) * sx), int((y0s + max(ys) + 1) * sy))
    if sum(1 for v in boxes.values() if v) < 4:
        print("auto 只找到 %d 个主体 → 退回 grid 模式" % sum(1 for v in boxes.values() if v), file=sys.stderr)
        return quadrant_boxes(im, alpha_threshold)
    return boxes


def expand(box, pad_ratio, W, H):
    x0, y0, x1, y1 = box
    pad = max(2, int(max(x1 - x0, y1 - y0) * pad_ratio))
    return (max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad))


def main():
    args = parse_args()
    src = Path(args.sheet)
    if not src.exists():
        print("找不到文件：%s" % src, file=sys.stderr)
        return 2
    out_dir = Path(args.out) if args.out else src.with_name(src.stem + "_crops")
    out_dir.mkdir(parents=True, exist_ok=True)
    name = args.name or src.stem
    views = [v.strip() for v in args.views.split(",") if v.strip()]
    if len(views) != 4:
        print("--views 需要 4 个名字（左上,右上,左下,右下）", file=sys.stderr)
        return 2

    im = Image.open(src).convert("RGBA")
    W, H = im.size
    boxes = quadrant_boxes(im, args.alpha_threshold) if args.mode == "grid" \
        else auto_boxes(im, args.alpha_threshold)

    order = [QUADRANTS[(0, 0)], QUADRANTS[(0, 1)], QUADRANTS[(1, 0)], QUADRANTS[(1, 1)]]
    items = []
    for slot, view in zip(order, views):
        b = boxes.get(slot)
        items.append((view, slot, None if not b else expand(b, args.pad, W, H)))

    # 共用缩放：以最高的那个人形为基准
    usable = [(v, s, b) for v, s, b in items if b]
    if not usable:
        print("四格都是空的：这张图没有可用主体", file=sys.stderr)
        return 1
    if args.no_common_scale:
        scale = None
    else:
        tallest = max(b[3] - b[1] for _, _, b in usable)
        widest = max(b[2] - b[0] for _, _, b in usable)
        scale = min(args.size / widest, args.size / tallest)

    print("源图 %s  %d×%d  →  输出目录 %s" % (src.name, W, H, out_dir))
    print("%-7s %-6s %-14s %-11s %s" % ("视角", "格位", "源 bbox(宽×高)", "输出", "不透明%"))
    print("-" * 66)
    ok = 0
    for view, slot, box in items:
        if not box:
            print("%-7s %-6s —— 空格子，跳过" % (view, slot))
            continue
        crop = im.crop(box)
        cw, ch = crop.size
        s = scale if scale else min(args.size / cw, args.size / ch)
        nw, nh = max(1, round(cw * s)), max(1, round(ch * s))
        rw, rh = min(args.size, nw), min(args.size, nh)
        small = crop.resize((nw, nh), Image.LANCZOS)
        if (nw, nh) != (rw, rh):  # 极端宽高比时避免出血
            small = small.crop((0, 0, rw, rh))
        canvas = Image.new("RGBA", (args.size, args.size), (0, 0, 0, 0))
        x = (args.size - rw) // 2
        y = args.size - rh if args.anchor == "bottom" else (args.size - rh) // 2
        canvas.paste(small, (x, y), small)
        dst = out_dir / ("%s_%s.png" % (name, view))
        canvas.save(dst)
        alpha = canvas.getchannel("A")
        opaque = sum(alpha.point(lambda v: 1 if v > 127 else 0).getdata()) / (args.size * args.size) * 100
        print("%-7s %-6s %-14s %-11s %.1f" % (view, slot, "%d×%d" % (cw, ch),
                                              "%d×%d" % canvas.size, opaque))
        ok += 1
    print("-" * 66)
    print("已输出 %d 张 → %s" % (ok, out_dir))
    print("共用缩放：%s" % ("关（每格各自满框）" if args.no_common_scale else "开（比例一致，推荐）"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
