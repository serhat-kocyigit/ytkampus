import os
from PIL import Image, ImageDraw, ImageFont

output_dir = r"c:\Users\Administrator\Desktop\New folder\halisaha\frontend\assets\images"
os.makedirs(output_dir, exist_ok=True)

slots = [
    (1, "Hero Ana Görsel", "Futbol / Ana Kompleks"),
    (2, "Hakkımızda", "Tesis & Yaşam Stili"),
    (3, "Futbol Sahası (UEFA)", "UEFA Standartlarında Profesyonel Saha"),
    (4, "Halı Saha (INTER)", "Sentetik Çim Halı Saha"),
    (5, "Tenis Kortu", "Akrilik Zemin Tenis Kortu"),
    (6, "Voleybol Sahası", "Kapalı Salon Voleybol Sahası"),
    (7, "Basketbol Sahası", "Tam Saha Potalı Basketbol Alanı"),
    (8, "Padel Kortu", "Yeni Nesil Padel Kortu (Yakında)"),
    (9, "Yüzme Havuzu", "Yarı Olimpik Kapalı Havuz (Yakında)"),
    (10, "Müzik Stüdyosu", "Akustik Yalıtımlı Prova Stüdyosu"),
    (11, "Sanat Atölyesi", "Resim & Sanat Çalışma Atölyesi"),
    (12, "Dans Stüdyosu", "Aynalı Özel Parkeli Dans Salonu"),
    (13, "YT Tenis Akademi", "Çocuk & Yetişkin Tenis Eğitimi"),
    (14, "Inter Akademi", "Futbol Eğitimi & Altyapı"),
    (16, "Sanat Merkezi Eğitimi", "Hasan Gürpınar Resim Eğitimi"),
    (17, "YT Dans Okulu", "İlk Dans, Zeybek, Oryantal, Zumba"),
    (18, "Dil Akademisi", "İngilizce & Korece Eğitimleri"),
    (19, "Çocuk Akademisi", "Çocuk Gelişim & Spor Programları"),
    (20, "Uzman Kadro", "Pedagojik Formasyonlu Elit Eğitmenler"),
    (21, "Galeri 1", "Kompleksten Kareler 1"),
    (22, "Galeri 2", "Kompleksten Kareler 2"),
    (23, "Galeri 3", "Kompleksten Kareler 3"),
    (24, "Galeri 4", "Kompleksten Kareler 4"),
    (25, "Galeri 5", "Kompleksten Kareler 5"),
    (26, "Galeri 6", "Kompleksten Kareler 6"),
    (27, "Galeri 7", "Kompleksten Kareler 7"),
    (28, "Galeri 8", "Kompleksten Kareler 8"),
]

W, H = 1200, 800

font_bold = "C:\\Windows\\Fonts\\segoeuib.ttf"
font_regular = "C:\\Windows\\Fonts\\segoeui.ttf"

font_num = ImageFont.truetype(font_bold, 150)
font_title = ImageFont.truetype(font_bold, 44)
font_sub = ImageFont.truetype(font_regular, 28)
font_hint = ImageFont.truetype(font_regular, 20)

for num, title, desc in slots:
    img = Image.new("RGB", (W, H), color="#090d16")
    draw = ImageDraw.Draw(img)

    # Subtle gradient background
    for y in range(H):
        ratio = y / H
        r = int(10 + ratio * 15)
        g = int(14 + ratio * 20)
        b = int(24 + ratio * 32)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # Grid effect
    grid_size = 50
    for x in range(0, W, grid_size):
        draw.line([(x, 0), (x, H)], fill=(255, 255, 255, 10), width=1)
    for y in range(0, H, grid_size):
        draw.line([(0, y), (W, y)], fill=(255, 255, 255, 10), width=1)

    # Outer border
    draw.rounded_rectangle([30, 30, W - 30, H - 30], radius=24, outline="#334155", width=3)

    # Center Badge Box
    badge_w, badge_h = 240, 240
    badge_x = (W - badge_w) // 2
    badge_y = 150
    
    # Outer glow / border
    draw.rounded_rectangle(
        [badge_x - 4, badge_y - 4, badge_x + badge_w + 4, badge_y + badge_h + 4],
        radius=40,
        outline="#f59e0b",
        width=4
    )
    draw.rounded_rectangle(
        [badge_x, badge_y, badge_x + badge_w, badge_y + badge_h],
        radius=36,
        fill="#1e293b",
        outline="#475569",
        width=2
    )

    # Number inside badge
    num_str = str(num)
    bbox = draw.textbbox((0, 0), num_str, font=font_num)
    nw = bbox[2] - bbox[0]
    nh = bbox[3] - bbox[1]
    nx = badge_x + (badge_w - nw) // 2
    ny = badge_y + (badge_h - nh) // 2 - 15
    draw.text((nx, ny), num_str, fill="#f59e0b", font=font_num)

    # Title: GÖRSEL ALANI {num}
    label = f"GÖRSEL ALANI {num}"
    bbox_l = draw.textbbox((0, 0), label, font=font_title)
    lw = bbox_l[2] - bbox_l[0]
    draw.text(((W - lw) // 2, 450), label, fill="#ffffff", font=font_title)

    # Subtitle: {desc}
    sub_label = f"{title} · {desc}"
    bbox_s = draw.textbbox((0, 0), sub_label, font=font_sub)
    sw = bbox_s[2] - bbox_s[0]
    draw.text(((W - sw) // 2, 520), sub_label, fill="#94a3b8", font=font_sub)

    # Recommendation hint box
    hint = f"Önerilen Görsel: {num}.jpg veya {num}.png (1200 x 800 px / 3:2)"
    bbox_h = draw.textbbox((0, 0), hint, font=font_hint)
    hw = bbox_h[2] - bbox_h[0]
    hx = (W - hw) // 2
    hy = 640
    draw.rounded_rectangle([hx - 20, hy - 8, hx + hw + 20, hy + 32], radius=16, fill="#1e293b", outline="#334155", width=1)
    draw.text((hx, hy), hint, fill="#38bdf8", font=font_hint)

    # Save as both .jpg and .png
    jpg_path = os.path.join(output_dir, f"{num}.jpg")
    png_path = os.path.join(output_dir, f"{num}.png")
    img.save(jpg_path, quality=95)
    img.save(png_path)

print(f"Başarıyla {len(slots)} adet görsel alanı (jpg & png) oluşturuldu.")
