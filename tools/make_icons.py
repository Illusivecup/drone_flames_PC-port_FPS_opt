import shutil
import base64
from PIL import Image

# 1. Create icon.png from icon_ios.png
shutil.copyfile("icon_ios.png", "icon.png")
print("Created icon.png from icon_ios.png")

# 2. Resize icon to 256x256 for SVG embed
img = Image.open("icon.png").convert("RGBA")
img_256 = img.resize((256, 256), Image.Resampling.LANCZOS)
img_256.save("icon_256.png")

with open("icon_256.png", "rb") as f:
    b64 = base64.b64encode(f.read()).decode("ascii")

svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="256" height="256" viewBox="0 0 256 256">
  <image width="256" height="256" xlink:href="data:image/png;base64,{b64}"/>
</svg>
'''
with open("icon.svg", "w", encoding="utf-8") as f:
    f.write(svg_content)
print("Updated icon.svg with DroneFlames icon")

import os
if os.path.exists("icon_256.png"):
    os.remove("icon_256.png")
