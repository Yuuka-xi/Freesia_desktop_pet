r"""把 EmoteLab 导出的 GIF 同步进项目，并为每个分类生成一个 SpriteFrames（<分类>/<分类>.tres）。

用法（在项目根目录）：  python tools/build_frames.py <角色名>     例如  python tools/build_frames.py Rene
- 读取 EmoteLab\Export\<角色名>，输出到 Asset/<角色名>/
- 新增或改过的 GIF：重新拆帧（200x200）
- EmoteLab 里删掉的 GIF：对应序列帧也删掉
- 子文件夹里的动画会带前缀，如 打字/生气/typing → 动画名 angry_typing
"""
import os, re, shutil, subprocess, sys

if len(sys.argv) != 2:
    sys.exit("用法：python tools/build_frames.py <角色名>，例如 Rene")
CHARACTER = sys.argv[1]
SRC = os.path.join(r"C:\Users\yuanx\Documents\EmoteLab\Export", CHARACTER)
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(PROJECT, "Asset", CHARACTER)
MAGICK = r"C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe"
SIZE, FPS = "200x200", 25.0
# 中文文件夹名 → 英文（同一分类允许多个中文写法）
CAT = {"休眠": "sleep", "截屏": "screenshot", "截图": "screenshot", "戳一戳": "poke", "打字": "typing",
       "正常待机": "idle", "待机": "idle", "消息通知": "notify", "游戏": "game", "电量": "battery",
       "画画": "drawing", "随机动作": "random", "随机": "random", "到达": "arrive",
       "长动作": "long", "生气": "angry", "疲倦": "tired", "音乐": "music"}
if not os.path.isdir(SRC):
    sys.exit("找不到导出文件夹：" + SRC)
os.makedirs(DST, exist_ok=True)
ONE_SHOT = {"arrive", "poke", "screenshot", "notify"}  # 这些分类的动画只播一次


def pngs(folder):
    return sorted(f for f in os.listdir(folder) if f.endswith(".png"))


# 1. 收集 GIF：目标目录 → GIF 路径
wanted = {}
for root, _, files in os.walk(SRC):
    rel = os.path.relpath(root, SRC)
    parts = [] if rel == "." else [CAT.get(p, p) for p in rel.split(os.sep)]
    for f in files:
        if f.endswith(".gif"):
            wanted[os.path.join(DST, *parts, f[:-4])] = os.path.join(root, f)

# 2. 拆帧：没拆过或 GIF 比帧新
for folder, gif in sorted(wanted.items()):
    first = os.path.join(folder, "000.png")
    if os.path.exists(first) and os.path.getmtime(first) >= os.path.getmtime(gif):
        continue
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.startswith(tuple("0123456789")):
            os.remove(os.path.join(folder, f))
    subprocess.run([MAGICK, gif, "-coalesce", "-resize", SIZE,
                    os.path.join(folder, "%03d.png")], check=True)
    print("拆帧:", os.path.relpath(folder, DST))

# 3. 删除 EmoteLab 里已不存在的动画
for root, dirs, _ in os.walk(DST, topdown=False):
    if root != DST and pngs(root) and root not in wanted:
        shutil.rmtree(root)
        print("删除:", os.path.relpath(root, DST))
    elif root != DST and not os.listdir(root):
        os.rmdir(root)

# 4. 每个分类生成一个 SpriteFrames
for cat in sorted(os.listdir(DST)):
    cat_dir = os.path.join(DST, cat)
    if not os.path.isdir(cat_dir):
        continue
    anims = sorted(f for f in wanted if f == cat_dir or f.startswith(cat_dir + os.sep))
    tres = os.path.join(cat_dir, cat + ".tres")
    uid = ""  # 保留旧 uid，避免场景引用失效
    if os.path.exists(tres):
        m = re.search(r'uid="([^"]+)"', open(tres, encoding="utf-8").readline())
        uid = f' uid="{m.group(1)}"' if m else ""
    ext, blocks, n = [], [], 0
    for folder in anims:
        rel = os.path.relpath(folder, cat_dir)
        name = cat if rel == "." else rel.replace(os.sep, "_")
        frames = []
        for f in pngs(folder):
            n += 1
            path = "res://" + os.path.relpath(os.path.join(folder, f), PROJECT).replace(os.sep, "/")
            ext.append(f'[ext_resource type="Texture2D" path="{path}" id="{n}"]')
            frames.append(f'{{\n"duration": 1.0,\n"texture": ExtResource("{n}")\n}}')
        loop = "false" if cat in ONE_SHOT else "true"
        blocks.append(f'{{\n"frames": [{", ".join(frames)}],\n"loop": {loop},\n'
                      f'"name": &"{name}",\n"speed": {FPS}\n}}')
    with open(tres, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(f'[gd_resource type="SpriteFrames" format=3{uid}]\n\n' + "\n".join(ext)
                 + "\n\n[resource]\nanimations = [" + ", ".join(blocks) + "]\n")
    print(f"{cat}.tres: {len(anims)} 个动画, {n} 帧")
