"""
Tạo icon 512x512 cho Cờ Caro app.
Chạy: python3 generate_icon.py
Cần: pip3 install Pillow
"""
from PIL import Image, ImageDraw, ImageFont
import math

SIZE = 512
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Rounded rectangle background (gradient giả bằng 2 màu)
def rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.ellipse([x0, y0, x0 + 2*radius, y0 + 2*radius], fill=fill)
    draw.ellipse([x1 - 2*radius, y0, x1, y0 + 2*radius], fill=fill)
    draw.ellipse([x0, y1 - 2*radius, x0 + 2*radius, y1], fill=fill)
    draw.ellipse([x1 - 2*radius, y1 - 2*radius, x1, y1], fill=fill)

# Background gradient (xanh đậm → xanh nhạt hơn)
for i in range(SIZE):
    ratio = i / SIZE
    r = int(26 + (40 - 26) * ratio)
    g = int(35 + (53 - 35) * ratio)
    b = int(126 + (147 - 126) * ratio)
    draw.line([(0, i), (SIZE, i)], fill=(r, g, b, 255))

# Mask bo góc
mask = Image.new("L", (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
rounded_rect(mask_draw, [0, 0, SIZE, SIZE], 80, 255)
img.putalpha(mask)

draw = ImageDraw.Draw(img)

# Vẽ lưới bàn cờ (5x5 ô nhỏ ở giữa)
GRID_SIZE = 5
CELL = 58
START_X = (SIZE - GRID_SIZE * CELL) // 2
START_Y = (SIZE - GRID_SIZE * CELL) // 2 + 10

grid_color = (255, 255, 255, 60)
for i in range(GRID_SIZE + 1):
    x = START_X + i * CELL
    y = START_Y + i * CELL
    draw.line([(START_X, y), (START_X + GRID_SIZE * CELL, y)], fill=grid_color, width=2)
    draw.line([(x, START_Y), (x, START_Y + GRID_SIZE * CELL)], fill=grid_color, width=2)

# Vẽ quân O (đỏ) tại các vị trí
O_COLOR = (239, 83, 80, 255)   # #EF5350
X_COLOR = (66, 165, 245, 255)  # #42A5F5
WIN_BG  = (255, 255, 255, 40)

def cell_center(row, col):
    return (START_X + col * CELL + CELL // 2, START_Y + row * CELL + CELL // 2)

# Layout quân cờ: O thắng theo đường chéo (0,0)→(4,4) nhưng dừng ở (2,2)
pieces = [
    # O pieces (winning diagonal + thêm)
    ("O", 0, 0), ("O", 1, 1), ("O", 2, 2), ("O", 3, 1), ("O", 1, 3),
    # X pieces
    ("X", 0, 2), ("X", 2, 0), ("X", 0, 4), ("X", 4, 0), ("X", 3, 3),
]

# Highlight winning cells
win_cells = [(0,0),(1,1),(2,2),(3,3),(4,4)]
for r, c in win_cells:
    cx, cy = cell_center(r, c)
    draw.rectangle([cx - CELL//2 + 2, cy - CELL//2 + 2,
                    cx + CELL//2 - 2, cy + CELL//2 - 2], fill=WIN_BG)

# Thêm quân O win (3,3) và (4,4)
pieces += [("O", 3, 3), ("O", 4, 4)]

RADIUS = 20
for piece, row, col in pieces:
    cx, cy = cell_center(row, col)
    if piece == "O":
        draw.ellipse([cx-RADIUS, cy-RADIUS, cx+RADIUS, cy+RADIUS],
                     outline=O_COLOR, width=5)
    else:
        r = RADIUS - 3
        draw.line([cx-r, cy-r, cx+r, cy+r], fill=X_COLOR, width=5)
        draw.line([cx+r, cy-r, cx-r, cy+r], fill=X_COLOR, width=5)

# Text "CARO" ở dưới
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 52)
    font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
except:
    font = ImageFont.load_default()
    font_small = font

text = "CARO"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
tx = (SIZE - tw) // 2
ty = START_Y + GRID_SIZE * CELL + 18
draw.text((tx+2, ty+2), text, font=font, fill=(0, 0, 0, 80))
draw.text((tx, ty), text, font=font, fill=(255, 255, 255, 240))

text2 = "GOMOKU"
bbox2 = draw.textbbox((0, 0), text2, font=font_small)
tw2 = bbox2[2] - bbox2[0]
draw.text(((SIZE - tw2)//2, ty + 56), text2, font=font_small, fill=(255, 255, 255, 160))

# Lưu
out = "icon-512.png"
img.save(out, "PNG")
print(f"Saved: {out} ({SIZE}x{SIZE})")

# Tạo thêm feature graphic 1024x500
fg = Image.new("RGBA", (1024, 500), (26, 35, 126, 255))
fg_draw = ImageDraw.Draw(fg)
# Paste icon vào giữa
icon_resized = img.resize((300, 300), Image.LANCZOS)
fg.paste(icon_resized, (50, 100), icon_resized)
try:
    font_big = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 72)
    font_med = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 32)
except:
    font_big = ImageFont.load_default()
    font_med = font_big

fg_draw.text((400, 140), "Cờ Caro", font=font_big, fill=(255,255,255,255))
fg_draw.text((400, 230), "Gomoku 5-in-a-row", font=font_med, fill=(255,255,255,180))
fg_draw.text((400, 290), "Chơi với AI • 2 người • Bảng xếp hạng", font=font_med, fill=(255,255,255,140))
fg.save("feature-graphic-1024x500.png", "PNG")
print("Saved: feature-graphic-1024x500.png")
