"""按对比台的 E 模板批量出「技能图标」：1024² 透明底 → 自动抠边留白 → 128² 到 assets/icons/。

提示词拼装与网页端**完全一致**（直接读 data/prompts.json）：
    正向 = [勾选的要求块·正向…]（按 要求块 的键顺序） + 模板·要求 + 每条自己的正向
    负向 = [勾选的要求块·负向…] + 模板·负向
去重规则同样复刻网页端（按逗号切、不分大小写、保留首次出现）。

用法（ComfyUI 需在 8188 运行）：
    D:\\AI\\venv-comfy\\Scripts\\python.exe gen_icons.py            # 只出缺的
    D:\\AI\\venv-comfy\\Scripts\\python.exe gen_icons.py --redo      # 全部重出
"""
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]          # 仓库根
PROMPTS = ROOT / "tools" / "lora-compare" / "data" / "prompts.json"
RAW_DIR = ROOT / "tools" / "lora-compare" / "images"   # 1024² 原图（过程产物，已 gitignore）
OUT_DIR = ROOT / "assets" / "icons"

COMFY = "http://127.0.0.1:8188"
UNET = "qwen_image_2.1_int8_convrot.safetensors"
CLIP = "qwen3vl_8b_nvfp4.safetensors"
VAE = "qwen_image_2.1_vae_bf16.safetensors"
TURBO = "qwen_image_2.1_turbo_lora_avg_rank_178_bf16.safetensors"

SIZE = 1024          # 出图边长（32 的倍数）
STEPS = 8            # 挂 Turbo LoRA → cfg 必须 1
OUT_SIZE = 128       # 进游戏的图标边长（技能栏槽位 56px，留 2× 余量）

# (文件名, 技能 id, 图标视觉词)  —— 只换「图标画什么」，其余全走全局块
JOBS = [
    ("skill_warrior_slash_icon", "warrior_slash",
     "a single crescent arc of golden blade light, sharp sweeping slash trail, radiant edge glow, spark particles"),
    ("skill_warrior_whirlwind_icon", "warrior_whirlwind",
     "a spinning golden whirlwind of blade light, circular sweeping arcs, motion blur ring, swirling sparks"),
    ("skill_mage_fireball_icon", "mage_fireball",
     "a glowing fireball core with radial flame arcs, swirling ember particles, intense orange light"),
    ("skill_mage_meteor_icon", "mage_meteor",
     "a descending burning meteor with a long fire tail, molten cracks, impact shockwave ring, drifting ash"),
    ("skill_ranger_arrow_icon", "ranger_arrow",
     "a single long arrow of green light piercing the center, sharp energy streak, glowing fletching"),
    ("skill_ranger_multishot_icon", "ranger_multishot",
     "a volley of glowing green arrows raining from above, parallel arrow trails, small impact sparks"),
]


def join_prompt(parts) -> str:
    """复刻网页端 joinPrompt：按逗号切分 → 不分大小写去重（保留首次出现）→ 重拼。"""
    seen, out = set(), []
    for p in parts:
        if not p:
            continue
        for piece in p.replace("，", ",").split(","):
            w = " ".join(piece.split())
            if not w or w.lower() in seen:
                continue
            seen.add(w.lower())
            out.append(w)
    return ", ".join(out)


def build_pair(tpl: dict, blocks: dict, positive_extra: str):
    use = tpl.get("套用要求", [])
    pos = [blocks[k]["文本"] for k in use if k in blocks and blocks[k]["类型"] == "正向"]
    neg = [blocks[k]["文本"] for k in use if k in blocks and blocks[k]["类型"] == "负向"]
    pos += [tpl.get("要求", ""), positive_extra]
    neg += [tpl.get("negative", "")]
    return join_prompt(pos), join_prompt(neg)


def post(path, payload):
    req = urllib.request.Request(COMFY + path, data=json.dumps(payload).encode("utf-8"),
                                 headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=60).read().decode("utf-8"))


def get(path, timeout=120):
    return json.loads(urllib.request.urlopen(COMFY + path, timeout=timeout).read().decode("utf-8"))


def graph(prompt, negative, prefix, seed=0):
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": UNET, "weight_dtype": "default"}},
        "2": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["1", 0], "shift": 3.1}},
        "3": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["2", 0], "lora_name": TURBO, "strength_model": 1.0}},
        "4": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP, "type": "qwen_image"}},
        "9": {"class_type": "VAELoader", "inputs": {"vae_name": VAE}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 0], "text": prompt}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 0], "text": negative}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": SIZE, "height": SIZE, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {
            "model": ["3", 0], "positive": ["5", 0], "negative": ["6", 0], "latent_image": ["7", 0],
            "seed": seed, "steps": STEPS, "cfg": 1, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["9", 0]}},
        "11": {"class_type": "SaveImage", "inputs": {"images": ["10", 0], "filename_prefix": prefix}},
    }


def render(prompt, negative, name, seed=0) -> Path:
    """提交 → 等 history → 取回 PNG，落盘到 RAW_DIR。"""
    t0 = time.time()
    try:
        r = post("/prompt", {"prompt": graph(prompt, negative, "_icon_" + name, seed), "client_id": "gen-icons"})
    except urllib.error.HTTPError as e:
        print(f"[{name}] 提交失败：{e.read().decode('utf-8', 'ignore')[:400]}")
        return None
    pid = r["prompt_id"]
    item = None
    while time.time() - t0 < 600:
        time.sleep(2)
        h = get(f"/history/{pid}")
        if pid in h:
            item = h[pid]
            break
    if item is None or item.get("status", {}).get("status_str") == "error":
        print(f"[{name}] 失败：{json.dumps(item or {}, ensure_ascii=False)[:400]}")
        return None
    o = [x for v in item["outputs"].values() for x in v.get("images", [])][0]
    q = urllib.parse.urlencode({"filename": o["filename"], "subfolder": o.get("subfolder", ""),
                                "type": o.get("type", "output")})
    raw = RAW_DIR / f"_icon_{name}.png"
    raw.write_bytes(urllib.request.urlopen(f"{COMFY}/view?{q}", timeout=180).read())
    print(f"[{name}] 出图 {round(time.time() - t0, 1)} s → {raw.name}")
    return raw


def to_icon(raw: Path, dst: Path) -> tuple:
    """去噪声地板 → 抠边 → 补正方形（留 10% 余量）→ LANCZOS 缩到 OUT_SIZE。

    ⚠️ 2.1 的 VAE 在"透明区"会留下 **alpha 1~2 的噪声地板**（实测占全画幅 45~66%，
    四角像素就是 a1）→ 直接用 >0 的包围盒会被它撑满整幅（永远抠不掉边）。
    所以先掐掉 alpha < 8，再按剩余 alpha 抠边。
    """
    im = Image.open(raw).convert("RGBA")
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 8 else v)
    box = a.getbbox() or (0, 0, im.width, im.height)
    pad = int(max(box[2] - box[0], box[3] - box[1]) * 0.04)
    box = (max(0, box[0] - pad), max(0, box[1] - pad),
           min(im.width, box[2] + pad), min(im.height, box[3] + pad))
    im = Image.merge("RGBA", (r, g, b, a)).crop(box)
    side = max(1, int(max(im.size) * 1.10))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2), im)
    out = canvas.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
    r2, g2, b2, a2 = out.split()
    out = Image.merge("RGBA", (r2, g2, b2, a2.point(lambda v: 0 if v < 4 else v)))   # 缩放振铃余雾
    out.save(dst)
    return im.size, dst.stat().st_size


def main() -> int:
    redo = "--redo" in sys.argv
    data = json.loads(PROMPTS.read_text(encoding="utf-8"))
    blocks = data["global"]["要求块"]
    tpl = next((t for t in data["templates"] if t["id"] == "E"), None)
    if tpl is None:
        print("prompts.json 里找不到 E 模板")
        return 1

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"E 模板：{tpl['name']}｜勾选 {tpl['套用要求']}")
    print(f"出图 {SIZE}x{SIZE} / {STEPS} 步 / cfg 1（Turbo）→ 抠边 → {OUT_SIZE}x{OUT_SIZE} → {OUT_DIR}")
    print("-" * 74)

    done = 0
    for name, skill_id, visual in JOBS:
        raw = RAW_DIR / f"_icon_{name}.png"
        if raw.exists() and not redo:
            print(f"[{name}] 复用已有原图")
        else:
            pos, neg = build_pair(tpl, blocks, visual)
            if name.endswith("fireball_icon"):
                print("正向（示例）：", pos)
            raw = render(pos, neg, name)
            if raw is None:
                continue
        dst = OUT_DIR / f"{name}.png"
        src_size, size = to_icon(raw, dst)
        print(f"[{name}] 抠边 {src_size[0]}x{src_size[1]} → {OUT_SIZE}x{OUT_SIZE}  {size // 1024} KB → {dst.name}")
        done += 1

    print("-" * 74)
    print(f"完成 {done}/{len(JOBS)}，assets/icons/ 现有：")
    for f in sorted(OUT_DIR.glob("*.png")):
        print(f"  {f.name:<38}{f.stat().st_size // 1024:>4} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
