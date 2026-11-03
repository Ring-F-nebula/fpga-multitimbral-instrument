"""Convert actual RTL RGB frames to PNG; never redraw the LCD screen."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SIM = ROOT / 'firmware/reports/final-simulation'
OUT = ROOT / 'docs/native-ui'
OUT.mkdir(parents=True, exist_ok=True)
views = [('目标亮格', 'screen_matrix_target', 'UI state fixture'),
         ('按错识别', 'screen_matrix_wrong', 'UI state fixture'),
         ('正确评价', 'screen_matrix_correct', 'UI state fixture'),
         ('暂停', 'screen_matrix_paused', 'UI state fixture'),
         ('空载校准', 'screen_matrix_calibrating', 'UI state fixture'),
         ('钢琴演奏', 'screen_native_0', 'production piano PCM -> analyzer -> LCD'),
         ('原跟练设置', 'screen_page_3', 'production display and score-state fixture'),
         ('吉他波形', 'screen_guitar_view_0', 'production guitar PCM -> analyzer -> LCD'),
         ('吉他频谱', 'screen_guitar_view_1', 'production guitar PCM -> analyzer -> LCD'),
         ('吉他李萨如', 'screen_guitar_view_2', 'production guitar PCM -> analyzer -> LCD')]
evidence = []
for title, name, source_type in views:
    source = SIM / (name + '.ppm')
    target = OUT / (name + '.png')
    im = Image.open(source).convert('RGB')
    assert im.size == (1024, 600)
    im.save(target)
    evidence.append(dict(title=title, source=source.relative_to(ROOT).as_posix(),
                         source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                         png=target.relative_to(ROOT).as_posix(),
                         png_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                         input=source_type, hardware_photo=False))
(OUT / 'screenshots.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding='utf-8')
buttons=''.join(f'<button data-file="{name}.png">{title}</button>' for title,name,_ in views)
(OUT / 'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>4×4 压力跟练 · RTL 预览</title>
<style>body{max-width:1100px;margin:24px auto;padding:0 16px;background:#f7f8fc;color:#343a50;font-family:system-ui,"Microsoft YaHei",sans-serif}button{padding:10px 18px;margin:0 6px 12px 0;border:0;border-radius:10px;background:#e5ebfa;color:#343a50;cursor:pointer}img{width:100%;border-radius:12px}p{line-height:1.8}</style>
<h1>4×4 压力跟练</h1><p>入口：跟练 → 压力垫 4×4 大屏 → 开始。左上 A0、逐行排列至右下 A15。大格仅显示指引和真实压力按压，触摸格子不会发声或计分。</p>
'''+buttons+'''<img id="screen" src="screen_matrix_target.png" alt="4×4 压力跟练 RTL 仿真画面">
<p>所有图片来自生产 RTL 的逐像素 RGB 输出，尚非实板照片。前五张为显式界面状态测试；钢琴和吉他分析画面由真实合成器 PCM 驱动。此页面按钮只切换截图。</p>
<script>document.querySelectorAll('button').forEach(b=>b.onclick=()=>{document.querySelector('#screen').src=b.dataset.file;document.querySelector('#screen').alt=b.textContent+' RTL 仿真画面';});</script></html>''', encoding='utf-8')
print('EXPORTED', len(views), 'RTL previews:', OUT)
