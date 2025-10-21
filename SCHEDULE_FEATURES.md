# 📅 Fitur Penjadwalan Otomatis

## ✨ Fitur Baru

### 1. **Schedule Engine Otomatis**
- ✅ Sistem penjadwalan berjalan otomatis saat aplikasi dimulai
- ✅ Memeriksa jadwal setiap 10 detik untuk akurasi
- ✅ Eksekusi pompa otomatis sesuai waktu yang ditentukan
- ✅ Support untuk multiple jadwal dengan hari yang berbeda

### 2. **Countdown Alerts**
- ⏰ Menampilkan countdown real-time untuk jadwal berikutnya
- 🔔 Notifikasi alert 2 menit sebelum pompa aktif
- 📊 Update countdown setiap detik
- 🎯 Hanya menampilkan jadwal dalam 5 menit ke depan

### 3. **Smart Execution**
- 🎯 Toleransi waktu ±5 detik untuk eksekusi akurat
- 💧 Kontrol otomatis pompa air (water pump)
- 🥤 Kontrol otomatis pompa nutrisi (nutrient pump)
- 🔔 Support notifikasi reminder

## 🔧 Cara Kerja

### Schedule Service
```dart
// Otomatis start saat aplikasi buka
ScheduleService().startScheduleEngine();

// Stream untuk countdown
Stream<String> countdownStream
Stream<ScheduleItem> activeScheduleStream
```

### Timer System
- **Schedule Check Timer**: Setiap 10 detik
- **Countdown Timer**: Setiap 1 detik
- **Execution Window**: ±5 detik dari waktu jadwal

### Countdown Display
- Menampilkan di home screen dengan format:
  - `[Nama Jadwal] dalam Xm Ys`
  - Contoh: `Penyiraman Pagi dalam 2m 30s`

## 📱 UI Features

### Home Screen
- **Countdown Alert Card**: Muncul otomatis 5 menit sebelum eksekusi
- **Real-time Update**: Countdown diupdate setiap detik
- **Visual Indicators**: Icon dan badge status AKTIF

### Alert Notifications
- 2 menit sebelum pompa aktif
- Menampilkan nama jadwal dan durasi
- Icon sesuai jenis aksi (💧 Air, 🥤 Nutrisi, 🔔 Notifikasi)

## 🎯 Contoh Penggunaan

### 1. Membuat Jadwal Penyiraman Pagi
```dart
ScheduleItem(
  id: 'morning-water',
  name: 'Penyiraman Pagi',
  time: TimeOfDay(hour: 6, minute: 0),
  days: [1, 2, 3, 4, 5], // Sen-Jum
  action: 'water',
  duration: 30, // 30 detik
  enabled: true,
);
```

### 2. Jadwal Nutrisi Sore
```dart
ScheduleItem(
  id: 'evening-nutrient',
  name: 'Nutrisi Sore',
  time: TimeOfDay(hour: 18, minute: 0),
  days: [1, 3, 5], // Sen, Rab, Jum
  action: 'nutrient',
  duration: 20, // 20 detik
  enabled: true,
);
```

## 🐛 Debugging

### Console Logs
- `🚀 Schedule Engine Started` - Engine berhasil start
- `⏰ Executing schedule: [nama]` - Jadwal dieksekusi
- `💧 Water pump ON for Xs` - Pompa air aktif
- `🥤 Nutrient pump ON for Xs` - Pompa nutrisi aktif
- `⏹️ Schedule Engine Stopped` - Engine berhenti

### Check Status
```dart
// Lihat console untuk log eksekusi
// Pastikan MQTT service terkoneksi
// Periksa jadwal enabled dan hari sesuai
```

## ⚙️ Konfigurasi

### Waktu Check Interval
```dart
// Di schedule_service.dart
_scheduleTimer = Timer.periodic(
  const Duration(seconds: 10), // Ubah interval check
  (timer) => _checkSchedules()
);
```

### Countdown Display Threshold
```dart
// Di schedule_service.dart  
if (nextSchedule != null && minSeconds <= 300) { // 5 menit
  // Ubah 300 untuk threshold berbeda
}
```

### Alert Timing
```dart
// Di schedule_service.dart
if (difference > 0 && difference <= 120) { // 2 menit
  _showCountdownAlert(schedule, difference);
}
```

## 📊 Status Monitoring

### Visual Indicators
- 🟢 **AKTIF** - Jadwal enabled dan countdown berjalan
- ⏰ **Countdown** - Waktu tersisa sampai eksekusi
- 💧 **Water Pump** - Status pompa air
- 🥤 **Nutrient Pump** - Status pompa nutrisi

### Notifications
- ⏰ Alert 2 menit sebelum
- ✅ Konfirmasi setelah selesai
- 🔔 Reminder untuk jadwal notify

## 🚀 Next Steps

Untuk testing:
1. Buat jadwal dengan waktu 2-3 menit dari sekarang
2. Tunggu countdown alert muncul di home screen
3. Lihat console log untuk eksekusi
4. Cek notifikasi setelah jadwal selesai

## 💡 Tips

1. **Multiple Schedules**: Sistem support unlimited jadwal
2. **Day Selection**: Pilih hari specific (1=Sen, 7=Min)
3. **Duration**: Set durasi sesuai kebutuhan tanaman
4. **Testing**: Gunakan waktu dekat untuk testing cepat
5. **MQTT**: Pastikan device ESP32 terkoneksi
