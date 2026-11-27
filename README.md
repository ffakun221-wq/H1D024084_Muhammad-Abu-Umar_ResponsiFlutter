# Responsi Flutter — Aplikasi Cuaca Open-Meteo (`responsi_flutter`)

Aplikasi Flutter prakiraan cuaca berbasis REST API **Open-Meteo** yang dibangun menggunakan bahasa pemrograman **Dart**, standar desain **Material Design 3**, manajemen state **Provider (`ChangeNotifier`)**, penyimpanan lokal **SharedPreferences**, serta pola arsitektur **Model-View-ViewModel (MVVM)**.

Seluruh data cuaca dan pencarian kota diambil secara langsung melalui HTTP `GET` ke layanan Open-Meteo tanpa data cuaca statis (`hardcoded`) maupun daftar pencarian palsu.

---

## Struktur Aplikasi

Aplikasi terdiri dari **2 layar utama** (`WeatherHomeScreen` dan `LocationSearchScreen`) dengan pemisahan direktori berbasis MVVM:

```text
lib/
├── main.dart                        # Entry point & ResponsiWeatherApp (MultiProvider DI)
├── models/
│   ├── location_model.dart          # Model lokasi (Geocoding JSON & Local Storage JSON)
│   └── weather_model.dart           # Model cuaca (WeatherModel, CurrentWeather, DailyForecast)
├── services/
│   ├── weather_api_service.dart     # HTTP GET ke Open-Meteo Weather Forecast API
│   ├── geocoding_api_service.dart   # HTTP GET ke Open-Meteo Geocoding API
│   └── local_storage_service.dart   # Persistensi SharedPreferences (favorit, riwayat, lokasi terpilih)
├── theme/
│   └── app_theme.dart               # Tema Material Design 3 & TextTheme yang konsisten
├── utils/
│   └── weather_code_mapper.dart     # Pemetaan kode cuaca WMO (0–99) ke teks Indonesia & ikon Material
├── viewmodels/
│   ├── view_state.dart              # Enum state (initial, loading, loaded, empty, error)
│   ├── weather_viewmodel.dart       # State & logika layar cuaca utama
│   └── search_viewmodel.dart        # State & logika pencarian kota, riwayat, serta favorit
└── views/
    ├── weather_home_screen.dart     # Screen 1: Home / Weather Screen (StatelessWidget)
    └── location_search_screen.dart  # Screen 2: Search / Location Screen (StatefulWidget)

test/
├── unit/                            # Unit tests untuk models, services, dan viewmodels
├── widget/                          # Widget tests untuk mapper dan kedua layar
├── widget_test.dart                 # Smoke test aplikasi
├── e2e/                             # End-to-end tests Tier 1–4
└── tier5/                           # Adversarial coverage & regression tests Tier 5
```

### Penjelasan Komponen Utama

1. **Screen 1 — `WeatherHomeScreen` (`StatelessWidget`)**:
   - Menampilkan nama kota terpilih, deskripsi & ikon kondisi cuaca terkini, suhu saat ini, suhu yang dirasakan, kelembapan udara, curah hujan, kecepatan angin, serta prakiraan cuaca harian beberapa hari ke depan.
   - Menangani state `loading`, `empty` (saat belum ada lokasi tersimpan), dan `error` (disertai tombol coba lagi dan navigasi ke pencarian), serta tata letak responsif melalui `LayoutBuilder` (breakpoint lebar `600 px`).
2. **Screen 2 — `LocationSearchScreen` (`StatefulWidget`)**:
   - Mengelola `TextEditingController` untuk input pencarian nama kota, menampilkan daftar hasil pencarian langsung dari Open-Meteo Geocoding API, menyediakan aksi memilih kota untuk melihat cuacanya, serta menyimpan/menghapus lokasi favorit dan menampilkan riwayat pencarian yang tersimpan di `SharedPreferences`.

---

## Implementasi API Open-Meteo

Seluruh permintaan jaringan dijalankan menggunakan `package:http` (`http.Client`) dengan metode **HTTP `GET`** dan validasi status HTTP `200`.

### 1. Weather Forecast API
- **Dokumentasi Resmi**: <https://open-meteo.com/en/docs>
- **Endpoint**: `https://api.open-meteo.com/v1/forecast`
- **5 Parameter Query Penting**:
  | Parameter | Nilai / Fungsi |
  |---|---|
  | `latitude` | Koordinat lintang lokasi terpilih |
  | `longitude` | Koordinat bujur lokasi terpilih |
  | `current` | `temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m` |
  | `daily` | `temperature_2m_max,temperature_2m_min,precipitation_probability_max` |
  | `timezone` | `auto` (menyesuaikan zona waktu lokal secara otomatis) |

- **9 Field Data Wajib yang Ditampilkan** (beserta `daily.time` untuk label tanggal prakiraan harian):
  | No. | Informasi di UI | Field API |
  |---|---|---|
  | 1 | Suhu saat ini | `current.temperature_2m` |
  | 2 | Kelembapan | `current.relative_humidity_2m` |
  | 3 | Suhu yang dirasakan | `current.apparent_temperature` |
  | 4 | Curah hujan | `current.precipitation` |
  | 5 | Kode kondisi cuaca | `current.weather_code` (dipetakan via `WeatherCodeMapper`) |
  | 6 | Kecepatan angin | `current.wind_speed_10m` |
  | 7 | Suhu maksimum harian | `daily.temperature_2m_max` |
  | 8 | Suhu minimum harian | `daily.temperature_2m_min` |
  | 9 | Peluang hujan maksimum | `daily.precipitation_probability_max` |

### 2. Geocoding API
- **Dokumentasi Resmi**: <https://open-meteo.com/en/docs/geocoding-api>
- **Endpoint**: `https://geocoding-api.open-meteo.com/v1/search`
- **Parameter Query**: `name=<kata_kunci>`, `count=10`, `language=id`, `format=json`.
- **Penanganan Kondisi**: Mengembalikan daftar `LocationModel` secara langsung dari respons JSON (`results`), menangani hasil kosong (`[]`) tanpa error saat kunci `results` tidak tersedia, serta menampilkan state `loading`, `empty`, dan `error` dengan tombol coba lagi.

---

## Penerapan Arsitektur MVVM

Aplikasi menerapkan pemisahan tanggung jawab (*Separation of Concerns*) berbasis **Model-View-ViewModel (MVVM)**:

- **Model (`lib/models/`)**: Kelas data imutabel (`LocationModel`, `WeatherModel`, `CurrentWeather`, `DailyForecast`) dengan konversi `fromJson`/`toStorageJson` yang aman terhadap tipe numerik dan nilai opsional (`nullable`).
- **Service (`lib/services/`)**: Lapisan akses data tanpa state untuk komunikasi HTTP (`WeatherApiService`, `GeocodingApiService`) dan penyimpanan lokal `SharedPreferences` (`LocalStorageService`).
- **ViewModel (`lib/viewmodels/`)**: `WeatherViewModel` dan `SearchViewModel` mewarisi `ChangeNotifier`, mengelola `ViewState` (`initial`, `loading`, `loaded`, `empty`, `error`), menjaga konsistensi permintaan terbaru (*stale-request cancellation*), serta memberi tahu View via `Provider`.
- **View (`lib/views/`, `lib/theme/`, `lib/utils/`)**: Widget antarmuka murni yang mendengarkan perubahan state melalui `Consumer` dan meneruskan interaksi pengguna ke ViewModel tanpa logika bisnis maupun pemanggilan HTTP langsung.

---

## Screenshot Aplikasi

Bagian ini disiapkan untuk menampilkan tangkapan layar aplikasi yang dijalankan secara langsung di perangkat atau emulator sebelum pengumpulan tugas.

### Langkah Mengambil Screenshot
1. Jalankan aplikasi pada emulator atau perangkat Android/Desktop:
   ```bash
   flutter run
   ```
2. Ambil tangkapan layar saat kedua layar aktif (`WeatherHomeScreen` dan `LocationSearchScreen`), simpan ke folder `screenshots/` (misalnya `screenshots/home_screen.png` dan `screenshots/search_screen.png`), lalu buka komentar tag gambar di bawah ini.

### Screen 1: Home / Weather Screen (`WeatherHomeScreen`)



### Screen 2: Search / Location Screen (`LocationSearchScreen`)



---

## Cara Menjalankan & Pengujian

```bash
# 1. Unduh dependensi
flutter pub get

# 2. Jalankan analisis statis
flutter analyze

# 3. Jalankan pengujian otomatis (unit, widget, dan E2E)
flutter test --no-pub

# 4. Jalankan aplikasi
flutter run
```
