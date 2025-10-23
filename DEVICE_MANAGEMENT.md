# Device Management Feature

## Fitur Baru: Manajemen Device ESP32

Aplikasi sekarang memiliki sistem manajemen device ESP32 yang memungkinkan Anda untuk:

### 1. **Setup Device ID Saat Pertama Kali**
   - Setelah splash screen selesai, Anda akan diminta memasukkan Device ID ESP32
   - Device ID adalah 8 karakter hexadecimal (0-9, a-f)
   - Contoh: `a93c1c78`

### 2. **Cara Mendapatkan Device ID ESP32:**
   - Buka Arduino IDE Serial Monitor
   - Upload sketch ESP32 Anda
   - Cari baris yang menampilkan "Device ID: xxxxxxxx"
   - Copy 8 karakter hexadecimal tersebut
   - Paste di aplikasi

### 3. **Menyimpan Multiple Devices**
   - Anda bisa menyimpan banyak device ESP32
   - Setiap device bisa diberi nama custom (opsional)
   - Contoh: "Hidroponik Rumah", "Greenhouse A", dll

### 4. **Auto-Connect ke Last Device**
   - Aplikasi otomatis mencoba connect ke device terakhir yang digunakan
   - Jika gagal, akan muncul screen setup device
   - Anda bisa switch device kapan saja

### 5. **Manajemen Device**
   Akses melalui 2 cara:
   
   **A. Dari Device Setup Screen:**
   - Klik "Kelola" di bagian "Device Tersimpan"
   - Atau klik "Lihat semua (X device)"
   
   **B. Dari Settings Screen:**
   - Buka Settings (⚙️)
   - Lihat card "ESP32 Device" di bagian atas
   - Klik "Switch Device" atau icon settings (⚙️)

### 6. **Fitur Device Manager:**
   - **Connect**: Tap device untuk langsung connect
   - **Rename**: Ubah nama device untuk identifikasi mudah
   - **Delete**: Hapus device dari daftar tersimpan

### 7. **Validasi Input:**
   - Device ID harus 8 karakter
   - Hanya menerima hexadecimal (0-9, a-f, A-F)
   - Case insensitive (otomatis lowercase)
   - Error message jelas jika format salah

## Flow Aplikasi:

```
Splash Screen (Video/Animation)
        ↓
    Cek Last Device
        ↓
   ┌────┴────┐
   │         │
Last Device  No Device
   Found     Saved
   ↓         ↓
Try Auto-  Device
Connect    Setup
   │       Screen
   │         ↓
   │      Input ID
   │         ↓
   │      Connect
   │         │
   └────┬────┘
        ↓
   Home Screen
```

## Struktur Data:

Device disimpan di SharedPreferences dengan format:
```
saved_devices: ["device_id|device_name", ...]
last_device_id: "a93c1c78"
```

## Screen Baru:

### 1. DeviceSetupScreen
**Path:** `lib/screens/device_setup_screen.dart`

**Features:**
- Input Device ID dengan validasi
- Input nama device (opsional)
- List device tersimpan (max 3 preview)
- Quick connect dari saved devices
- Help section dengan instruksi
- Auto-connect dengan loading state
- Error handling dengan pesan jelas

### 2. DeviceManagerScreen
**Path:** `lib/screens/device_manager_screen.dart`

**Features:**
- Full list semua saved devices
- Connect, Rename, Delete actions
- Confirmation dialog untuk delete
- Beautiful glass morphism design
- Empty state jika belum ada device

## Update pada Screen Lama:

### 1. SplashScreen
- Auto-check last device
- Auto-connect jika ada
- Navigate ke DeviceSetup jika tidak ada

### 2. SettingsScreen
- Card "ESP32 Device" di bagian atas
- Display current device ID
- Button "Switch Device" untuk ganti device
- Icon settings untuk manage devices

### 3. AppTheme
- Added `errorColor` untuk error messages

## Testing Checklist:

- [ ] Install aplikasi pertama kali → muncul Device Setup Screen
- [ ] Input Device ID valid → connect berhasil → navigate ke Home
- [ ] Input Device ID invalid → muncul error message
- [ ] Save multiple devices → semua tersimpan
- [ ] Restart app → auto-connect ke last device
- [ ] Switch device dari Settings → connect ke device baru
- [ ] Rename device → nama berubah
- [ ] Delete device → device terhapus
- [ ] Delete last used device → next startup ke Setup Screen

## Notes:

- Semua device management menggunakan SharedPreferences
- MQTTService deviceId bisa diubah dinamis
- Topics MQTT di-generate otomatis berdasarkan deviceId
- Connection status ditampilkan dengan jelas
- Loading state untuk semua async operations
- Error handling comprehensive di semua flow

## Cara Test:

1. **Uninstall aplikasi** (untuk clear SharedPreferences)
2. **Install fresh** dari flutter run
3. Setelah splash, akan muncul Device Setup Screen
4. Input device ID ESP32 Anda
5. Jika connect berhasil, akan navigate ke Home
6. Coba switch device dari Settings
7. Test rename dan delete dari Device Manager

## ESP32 Device ID Example:
```
a93c1c78
12ab34cd
00112233
```

Format: 8 karakter hexadecimal (0-9, a-f)
