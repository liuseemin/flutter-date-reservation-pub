# 排班 JSON Builder

一個 **Flutter Web** 應用程式，用於建立、管理和匯出排班 / 預假表單的 JSON 檔案。可以匯入員工資料、分配代表字元、管理預填班表，並輸出結構化的 JSON。

---

## 功能

* **全域參數設定**

  * 設定開始日期、天數、工作區域、以及科別的星期限制。
* **員工管理**

  * 新增、編輯、刪除員工。
  * 從預設名單自動填入員工 ID。
  * 自動分配員工代表字元。
  * 設定最大班數、偏好休假日與可排班區域。
* **預填班表管理**

  * 新增、編輯、刪除預填班表。
  * 支援多選列批次刪除。
  * 支援從 CSV 匯入預填班表。
* **匯入與匯出**

  * 匯入員工 JSON。
  * 匯入包含員工與預填班表的完整設定 JSON。
  * 匯出完整排班 JSON。
* **響應式介面**

  * 員工列表與預填班表皆可捲動。
  * 支援即時編輯，使用 debounce 避免效能問題。

---

## 技術棧

* **Flutter Web**：互動式排班介面。
* **Firebase Firestore**：員工資料來源（可選，本地 JSON 亦可）。
* **Dart**：應用邏輯與狀態管理。
* **Web API**：透過 `Blob` 與 `FileReader` 進行檔案匯入/匯出。

---

## 安裝

1. Clone專案：

```bash
git clone <repository-url>
cd roster-json-builder
```

2. 安裝相依套件：

```bash
flutter pub get
```

3. 以 Web 模式啟動：

```bash
flutter run -d chrome
```

---

## 使用說明

1. **設定全域參數**：
   填入開始日期、天數、工作區域、科別週期限制 JSON。

2. **管理員工**：

   * 手動新增員工或匯入 JSON。
   * 使用「自動 ID」填入員工 ID。
   * 使用「自動字元」分配代表字元。

3. **管理預填班表**：

   * 手動新增或從 CSV 匯入。
   * 選取列後可批次刪除。

4. **匯出 JSON**：

   * 點擊「下載 JSON」生成 `roster_input.json`。

---

## CSV 匯入格式

* 第一列為表頭，可包含天數偏移。
* 後續列為各區域每日代表字元。

範例：

```
Area,0,1,2
A,X,Y,Z
B,A,B,C
```

---

## 專案目錄結構與檔案說明

```
roster-json-builder/
│
├─ lib/
│   ├─ main.dart               # 程式進入點
│   ├─ pages/                  # 各頁面元件
│   │   ├─ home_page.dart
│   │   ├─ employee_page.dart
│   │   └─ prefill_page.dart
│   ├─ models/                 # 資料模型 (Employee, Prefill, Config)
│   ├─ widgets/                # 共用元件 (表格、按鈕、輸入欄位)
│   ├─ services/               # JSON 匯入匯出、CSV 解析
│   └─ utils/                  # 工具函式 (debounce、字元分配等)
│
├─ assets/
│   ├─ sample_csv/             # CSV 範例檔
│   └─ sample_json/            # JSON 範例檔
│
├─ web/
│   └─ index.html              # Web 入口頁
│
├─ pubspec.yaml                # Flutter 套件與資源設定
└─ README.md                   # 專案說明文件
```

---

## 注意事項

* 所有輸入欄位支援即時編輯，並使用 debounce 提升效能。
* 預填班表多選功能使用 `ValueNotifier` 管理，確保 UI 即時更新。
* 匯出 JSON 時會自動將巢狀列表攤平成一維。
* CSV 中的字元需對應員工代表字元，以正確映射員工 ID。
