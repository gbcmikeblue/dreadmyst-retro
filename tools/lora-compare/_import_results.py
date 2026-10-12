#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把脚本直接生成在 images/ 里的对比图，按真实参数补登进对比台的 data/results.json。

为什么需要：对比台的卡片是读 results.json 渲染的，而脚本出图没写记录 —— 所以工具里看不到。
本脚本把「批次 / 模板 / 底模 / seed / 提示词全文」补齐，之后就能在网页上并排对比 + 评分 + 导出 RESULTS.md。
幂等：已存在的 image 路径会跳过。
"""
import io
import json
import os
import sys
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

TOOL = r"d:\yiyi\dreadmyst-1\tools\lora-compare"
IMGDIR = os.path.join(TOOL, "images")
RESULTS = os.path.join(TOOL, "data", "results.json")

CKPT_BASE = "_D_AI_ckpt\\v1-5-pruned-emaonly.safetensors"
CKPT_GF3 = "_D_AI_ckpt\\guofeng3_v32.safetensors"

# ---- 各批次的提示词（当时实际发出去的原文）----
N_OLD = ("monochrome, greyscale, grayscale, line art, sketch, ink outline, black outline, flat color, "
         "pixel art, 8-bit, hard pixel edges, 3d render, photo, watermark, text, signature, blurry, "
         "deformed, extra limbs, ugly")
N_NEW = ("monochrome, greyscale, grayscale, line art, sketch, ink outline, black outline, flat color, "
         "pixel art, 8-bit, hard pixel edges, photorealistic 3d render, plastic 3d model, western fantasy, "
         "photo, watermark, text, signature, blurry, deformed, extra limbs, ugly, chibi, big head, super deformed")
MULTI = "multiple characters, two people, full scene, cropped"

P_A1_OLD = ("full body character, standing pose, front view, plain background, entire figure head to toe, "
            "nothing cropped, clear margin around the figure, colorful painted illustration, warm palette, "
            "smooth colors, 2.5D retro RPG style, soft shading, limited palette, centered composition, "
            "simple background, game asset, single character, clean readable silhouette, equipment clearly "
            "readable, painted 2D game sprite")
P_A1_NEW = ("full body character, standing pose, front view, plain background, entire figure head to toe, "
            "nothing cropped, clear margin around the figure, chinese oriental fantasy theme, xianxia immortal "
            "aesthetics, ruyi cloud pattern, jade ornaments, gold trim, silk ribbons, tassel, embroidered silk, "
            "traditional chinese motifs, 2.5D oriental fantasy RPG style, painted illustration, rich vivid colors, "
            "high saturation, smooth soft shading, clean readable shapes, cohesive color palette, hand painted "
            "texture, centered composition, plain background, simple background, game asset, single character, "
            "clean readable silhouette, equipment clearly readable, painted 2D game sprite")
P_A2_OLD = ("three-quarter high-angle view, camera pitched about 45 degrees down, full body, standing upright, "
            "facing the viewer, whole figure inside the frame, colorful painted illustration, warm palette, smooth "
            "colors, 2.5D retro RPG style, soft shading, limited palette, centered composition, simple background, "
            "game asset, same character, same outfit, same colors, keep the original silhouette, painted 2D game sprite")
P_A3_OLD = ("three-quarter high-angle view, camera pitched about 45 degrees down, full body, standing upright, "
            "facing the viewer, whole figure inside the frame, colorful painted illustration, warm palette, smooth "
            "colors, 2.5D retro RPG style, soft shading, limited palette, centered composition, simple background, "
            "game asset, single character, clean readable silhouette, equipment clearly readable, painted 2D game sprite")
P_A3_NEW = ("isometric view, 30 degree angle, no perspective, orthographic, parallel projection, full body, "
            "standing upright, facing the viewer, whole figure inside the frame, chinese oriental fantasy theme, "
            "xianxia immortal aesthetics, ruyi cloud pattern, jade ornaments, gold trim, silk ribbons, tassel, "
            "embroidered silk, traditional chinese motifs, 2.5D oriental fantasy RPG style, painted illustration, "
            "rich vivid colors, high saturation, smooth soft shading, clean readable shapes, cohesive color palette, "
            "hand painted texture, centered composition, plain background, simple background, game asset, single "
            "character, clean readable silhouette, equipment clearly readable, painted 2D game sprite")
N_A3_NEW = ("bird's eye view, directly overhead, flat top-down layout, only the top of the head visible, extreme "
            "foreshortening, front view standing portrait, perspective, vanishing point, tilted camera, wide angle "
            "lens, photographic, " + N_NEW + ", " + MULTI)

VIEWPOS = ("three-quarter high-angle view, camera pitched about 45 degrees down, full body, standing upright, facing "
           "the viewer, whole figure inside the frame, colorful painted illustration, warm palette, smooth colors, "
           "2.5D retro RPG style, soft shading, limited palette, centered composition, simple background, game asset, "
           "single character, clean readable silhouette, equipment clearly readable, full body character, painted 2D "
           "game sprite")

T_A1 = ("A1", "角色立绘（阶段1 · 文生图）")
T_A2 = ("A2", "视角转换 → 3/4 俯视（阶段2 · 图生图）")
T_A3 = ("A3", "3/4 俯视立绘（一步出图 · 文生图）")
T_VIEW = ("A3", "文生图 + 视角要求（A3 雏形）")

JOBS = []


def add(img, tpl, ckpt, seed, pos, neg, batch, steps=25, stage="txt2img", denoise=None, init=None):
    if not os.path.exists(os.path.join(IMGDIR, img)):
        print("  跳过（文件不存在）:", img)
        return
    JOBS.append({"img": img, "tpl": tpl, "ckpt": ckpt, "seed": seed, "pos": pos, "neg": neg,
                 "batch": batch, "steps": steps, "stage": stage, "denoise": denoise, "init": init})


# ① 阶段1 立绘（旧基线，上色修正后）
add("_fix_1_A1立绘.png", T_A1, CKPT_BASE, 20261012, P_A1_OLD, N_OLD + ", " + MULTI,
    "① 要求块上色修正·原始base", 20)
# ② 阶段2 转视角 三档 denoise（旧基线）
for d in (80, 85, 90):
    add("_fix_2_A2_d%03d.png" % d, T_A2, CKPT_BASE, 20261012, P_A2_OLD,
        "bird's eye view, directly overhead, flat top-down layout, only the top of the head visible, extreme "
        "foreshortening, front view standing portrait, " + N_OLD + ", different character, different outfit",
        "② img2img 转视角·denoise %.2f" % (d / 100), 20, "img2img", d / 100, "images/_fix_1_A1立绘.png")
# ③ 文生图直接带视角要求 + 抽卡
for s in (20261012, 20261013, 20261014, 20261015):
    add("_view_s%d.png" % s, T_VIEW, CKPT_BASE, s, VIEWPOS, N_A3_NEW,
        "③ 文生图带视角要求·原始base（抽卡）", 20)
# ④ A3 旧基线 + 抽卡
for s in (30101, 30102, 30103, 30104):
    add("_a3_s%d.png" % s, T_A3, CKPT_BASE, s, P_A3_OLD, N_OLD + ", " + MULTI,
        "④ A3 旧基线·原始base（抽卡）", 25)
# ⑤ A3 新基线（投影词）+ 抽卡 · 原始 base
for s in (30101, 30102, 30103, 30104):
    add("_a3iso_s%d.png" % s, T_A3, CKPT_BASE, s, P_A3_NEW, N_A3_NEW,
        "⑤ A3 新基线(投影词)·原始base（抽卡）", 25)
# ⑥ A3 新基线 + 抽卡 · 国风3 底模
for s in (30101, 30102, 30103, 30104):
    add("_gf3_A3_s%d.png" % s, T_A3, CKPT_GF3, s, P_A3_NEW, N_A3_NEW,
        "⑥ A3 新基线·国风3底模（抽卡）", 25)
# ⑦ A1 新基线 · 国风3 底模
for s in (30101, 30102):
    add("_gf3_A1_s%d.png" % s, T_A1, CKPT_GF3, s, P_A1_NEW, N_NEW + ", " + MULTI,
        "⑦ A1 新基线·国风3底模（风格对照）", 25)
# ⑧ 早期 reference_only（提示词未留档）
for i, name in ((1, "_refonly_1_立绘_A1.png"), (2, "_refonly_2_转视角_无参考.png"), (3, "_refonly_3_转视角_参考0.7.png")):
    add(name, T_A2 if i > 1 else T_A1, CKPT_BASE, 0, "", "",
        "⑧ 早期 reference_only 实验（提示词未留档）", 20,
        "img2img" if i > 1 else "txt2img", 0.7 if i > 1 else None)


def main():
    with open(RESULTS, encoding="utf-8") as fp:
        doc = json.load(fp)
    have = {r.get("image") for r in doc["records"]}
    added = 0
    for j in JOBS:
        key = "images/" + j["img"]
        if key in have:
            continue
        mt = time.localtime(os.path.getmtime(os.path.join(IMGDIR, j["img"])))
        doc["records"].append({
            "id": "%d_%s" % (int(time.time() * 1000) + added, os.urandom(3).hex()),
            "at": time.strftime("%Y-%m-%d %H:%M:%S", mt),
            "template": j["tpl"][0], "template_name": j["tpl"][1],
            "阶段": j["stage"], "denoise": j["denoise"], "底图": j["init"],
            "base": "SD 1.5", "checkpoint": j["ckpt"],
            "width": 512, "height": 512, "steps": j["steps"], "cfg": 7,
            "sampler": "DPM++ 2M", "seed": j["seed"],
            "lora": None, "weight": None, "own_weight": False, "trigger": "",
            "final_prompt": j["pos"], "negative_prompt": j["neg"],
            "image": key,
            "批次": j["batch"], "rating": None, "verdict": "",
            "notes": "批次：" + j["batch"] + ("｜提示词未留档" if not j["pos"] else ""),
        })
        added += 1
    doc["updated"] = time.strftime("%Y-%m-%d")
    with open(RESULTS, "w", encoding="utf-8") as fp:
        json.dump(doc, fp, ensure_ascii=False, indent=2)
    print("导入 %d 条；results.json 现共 %d 条记录" % (added, len(doc["records"])))


if __name__ == "__main__":
    main()
