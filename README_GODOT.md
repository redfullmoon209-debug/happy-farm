# Happy Farm - Godot 4.4.1
โปรเจกต์ใหม่ เริ่มจากศูนย์ ไม่เกี่ยวข้องกับโปรเจกต์อื่น

## เปิดใน Godot
1. ติดตั้ง Godot 4.4.1 Standard (ไม่จำเป็นต้อง Mono).
2. กด Import > เลือกไฟล์ project.godot ใน Repository นี้
3. กด F6 ขณะเปิด Main.tscn หรือ F5 เพื่อรันเกม
4. เกมเก็บเงิน, แปลงปลูก, เมล็ด, หมู ใน user://happy_farm.json

## ทดสอบผ่าน Google Chrome
GitHub Actions จะ Export เกมเป็น Web เมื่อ push ไปยัง main
1. ไป Settings > Pages
2. เลือก Source: GitHub Actions (ไม่ใช้ Deploy from a branch)
3. ไป Actions > Export Godot Web & publish เพื่อตรวจ workflow
4. เปิด https://redfullmoon209-debug.github.io/happy-farm/ บน PC หรือมือถือ Chrome

ตั้ง GitHub Pages เป็นสาธารณะ เพราะ repository เป็น public.
ชุด Kenney Tiny Farm sprites มีลิขสิทธิ์ CC0; เครดิตอยู่ใน assets/CREDITS.md.
UI ทั้งหมดเป็น native Godot ไม่ใช้ HTML เว็บเดิม.
