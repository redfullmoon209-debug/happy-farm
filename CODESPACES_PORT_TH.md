# ทดสอบ Happy Farm บน Chrome ผ่าน GitHub Codespaces Ports

## 1) เปิด Codespaces
ไปที่ https://github.com/redfullmoon209-debug/happy-farm
กด **Code > Codespaces > Create codespace on main**

## 2) รันเกมผ่านพอร์ต
เปิด Terminal ของ Codespaces แล้วรัน:

```bash
bash tools/run_port.sh
```

สคริปต์จะติดตั้ง Godot 4.4.1 และ Web export templates ลงใน Codespace ถ้ายังไม่มี จากนั้น Import ภาพและฟอนต์, Export เป็น HTML5 และเปิด web server ที่ port 8080.

## 3) เปิดเล่นใน Chrome (PC)
คลิกแท็บ **PORTS** ด้านล่าง VS Code / Codespaces เลือก **8080** แล้วคลิกไอคอนโลก **Open in Browser**.

## 4) เปิดเล่นใน Chrome (มือถือ)
ในแท็บ PORTS ให้คัดลอก **Forwarded Address** ของ 8080 ไปวางใน Chrome มือถือ
ถ้าไม่ได้ล็อกอิน GitHub บนมือถือ ให้กดขวาที่พอร์ต 8080 > Port Visibility > Public; **Public หมายถึงคนที่รู้ลิงก์จะเข้าถึงได้** จึงควรเปลี่ยนกลับเป็น Private หลังทดสอบ.
พอร์ตต้องมี Codespace ที่กำลังรันเซิร์ฟเวอร์อยู่ และหยุดเมื่อปิด Codespace.

## 5) หลังแก้ไขโค้ด
กด Ctrl+C เพื่อหยุดเซิร์ฟเวอร์ แล้วรัน `bash tools/run_port.sh` ใหม่และรีเฟรช Chrome เพื่อ Export เวอร์ชันล่าสุด.

**ข้อควรทราบ:** GitHub Pages เป็นลิงก์เผยแพร่ถาวรกว่า แต่พอร์ต Codespaces เป็นลิงก์ทดสอบชั่วคราว.
