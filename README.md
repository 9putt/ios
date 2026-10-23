# Tube EQ Pro — Full Source & IPA Build Guide

โปรเจกต์แอปพลิเคชันเครื่องเล่นสื่อออนไลน์พร้อมระบบประมวลผลเสียง Equalizer 10-Band และการเล่นเบื้องหลัง (Background Playback) พัฒนาด้วย Swift และ Native Frameworks ของ Apple โดยตรง

---

## 📁 โครงสร้างโปรเจกต์ (Project Structure)

```text
TubeEQ_Pro/
├── TubeEQ/
│   ├── TubeEQApp.swift               # จุดเริ่มต้นของแอปพลิเคชัน (SwiftUI Entry Point)
│   ├── Info.plist                    # กำหนดสิทธิ์ Background Modes (audio)
│   ├── Audio/
│   │   ├── AudioEngineManager.swift  # ระบบ AVAudioEngine + 10-Band Parametric EQ + Reverb
│   │   └── EqualizerPreset.swift     # พรีเซ็ตเสียง (Bass Boost, Rock, Pop, Jazz, ฯลฯ)
│   ├── Views/
│   │   ├── MainContentView.swift     # แท็บหลัก (Web Player, Equalizer, Playlists)
│   │   ├── WebPlayerView.swift       # WKWebView ควบคุมการเล่นมีเดียแบบ Full-Screen / PiP
│   │   ├── EqualizerView.swift       # UI สไลเดอร์ปรับย่านความถี่ 10 ย่าน พร้อม Reverb
│   │   └── PlaylistView.swift        # บันทึกรายการโปรดและบุ๊กมาร์กเพลง
│   └── Resources/
└── HOW_TO_BUILD_IPA.md               # ขั้นตอนการคอมไพล์และแพ็กไฟล์ .ipa
```

---

## 🛠️ จุดเด่นของโปรเจกต์นี้
* ✅ **ไม่มีโฆษณาแทรกซ้อน (No Third-Party Ads):** ไม่มี SDK ของ AdMob หรือ Google Ads เข้ามารบกวน
* ✅ **10-Band Parametric EQ:** ปรับแต่งความถี่ได้ตั้งแต่ 32 Hz ถึง 16 kHz ละเอียดระดับ ±15 dB
* ✅ **Acoustic Reverb Ambience:** ระบบมิติเสียงสะท้อนแบบสมจริง
* ✅ **Background Playback:** รองรับการเล่นเสียงต่อเนื่องแม้ล็อกหน้าจอหรือสลับแอป
* ✅ **Playlists & Bookmarks:** เก็บรายการเพลง/คลิปที่ชื่นชอบไว้ในเครื่อง

---

## 📦 วิธีการคอมไพล์และแพ็กเป็นไฟล์ `.ipa`

### วิธีที่ 1: ใช้ Xcode บน macOS (วิธีมาตรฐาน)
1. เปิด Xcode -> เลือก **Create a new Xcode Project** -> **iOS App (Swift / SwiftUI)**
2. ตั้งชื่อโปรเจกต์ว่า `TubeEQ` และ Bundle Identifier เช่น `com.custom.tubeeq`
3. ลากโฟลเดอร์ `TubeEQ/` ในโปรเจกต์นี้เข้าไปแทนที่ไฟล์เดิมใน Xcode
4. เสียบอุปกรณ์ iPhone หรือเลือก Target เป็น `Any iOS Device (arm64)`
5. ไปที่เมนู **Product -> Archive**
6. เมื่อคอมไพล์เสร็จ หน้าต่าง Organizer จะเปิดขึ้นมา -> กด **Distribute App** -> เลือก **Ad Hoc** หรือ **Development** -> กด **Export**
7. จะได้ไฟล์ **`TubeEQ.ipa`** ทันที!

### วิธีที่ 2: คอมไพล์ผ่าน Command Line (`xcodebuild`)
```bash
# 1. สร้าง Archive
xcodebuild archive \
  -scheme TubeEQ \
  -destination 'generic/platform=iOS' \
  -archivePath ./build/TubeEQ.xcarchive

# 2. Export เป็น .ipa
xcodebuild -exportArchive \
  -archivePath ./build/TubeEQ.xcarchive \
  -exportPath ./build/TubeEQ_IPA \
  -exportOptionsPlist ExportOptions.plist
```

### วิธีที่ 3: คอมไพล์ฟรีผ่าน GitHub Actions (ไม่ต้องมี Mac)
คุณสามารถนำโค้ดในโฟลเดอร์นี้อัปขึ้น GitHub Repo ส่วนตัว แล้วใช้ GitHub Actions (macOS Runner ฟรี) สั่งรันคำสั่ง `xcodebuild` ด้านบน เพื่อดาวน์โหลดไฟล์ `.ipa` ที่เสร็จสมบูรณ์ออกมาได้โดยอัตโนมัติ

---

## 📲 การติดตั้งไฟล์ `.ipa` ลงบน iPhone
เมื่อได้ไฟล์ `.ipa` แล้ว สามารถติดตั้งผ่านโปรแกรมฟรีได้ง่ายๆ:
* **Sideloadly / AltStore:** ลากไฟล์ `.ipa` วางแล้วกรอก Apple ID เพื่อติดตั้งและเซ็นชื่อรับรองได้ทันที
* **TrollStore (สำหรับ iOS ที่รองรับ):** ติดตั้งแบบถาวรได้ทันทีโดยไม่ต้องต่ออายุใบรับรอง
