# gamma

ATTRACTS 向け対戦ロボット gamma（beta の次世代機）の機体管理リポジトリ。
機体全体の構成、基板、配線、関連リポジトリへの入口をここに集約する。

> **ステータス凡例**
> - ✅ 確定・実装済み
> - 🔧 実装中
> - 💭 構想段階（変更の可能性あり）

## 関連リポジトリ

| 役割 | リポジトリ | 備考 |
|---|---|---|
| 制御基板（砲塔） | [gamma_turret_pcb](https://github.com/rabbits-robotics/gamma_turret_pcb) | [v1.0](https://github.com/rabbits-robotics/gamma_turret_pcb/releases/tag/v1.0)（2026-08-12 発注） |
| 受動分配基板（首） | [gamma_neck_pcb](https://github.com/rabbits-robotics/gamma_neck_pcb) | [v1.0](https://github.com/rabbits-robotics/gamma_neck_pcb/releases/tag/v1.0)（2026-08-13 発注） |
| 受動分配基板（車体） | [gamma_chassis_pcb](https://github.com/rabbits-robotics/gamma_chassis_pcb) | [v1.0](https://github.com/rabbits-robotics/gamma_chassis_pcb/releases/tag/v1.0)（2026-08-10 発注） |
| 制御基板ファームウェア | [gamma_turret_fw](https://github.com/rabbits-robotics/gamma_turret_fw) | ESP32-P4、PlatformIO |
| 共通ライブラリ | [rabcl](https://github.com/rabbits-robotics/rabcl) | ファームと ROS 2 で共用。コミット固定 |
| ROS 2 ワークスペース | [rabbits_ws](https://github.com/rabbits-robotics/rabbits_ws) | `gamma.repos` を使う（作成予定） |
| 機体固有設定（launch / パラメータ / URDF） | [rabbits_description](https://github.com/rabbits-robotics/rabbits_description) | |
| メカ CAD | 本リポジトリの Releases | 節目ごとに SolidWorks 一式を zip で添付。CERN-OHL-P-2.0 |

## 環境構築（Jetson 側）

```bash
git clone https://github.com/rabbits-robotics/rabbits_ws.git
cd rabbits_ws
vcs import src < gamma.repos
colcon build
```

`gamma.repos` は `vcs export --exact src` で生成したコミット固定版。
更新は機体のマイルストーンごとに行い、rabcl は gamma_turret_fw の submodule と同じコミットを指す。💭

## システム構成

```
[ Jetson Orin Nano ]
  │ UART（3.3V TTL）
  ▼
[ gamma_turret（M5Stack Stamp-P4 / ESP32-P4） ]  ← BNO055 IMU（UART、基板直載せ）
  ├── CAN1（砲塔・ジンバル系）
  │     ├── DM3507  × 2 → 首 Roll / Pitch 軸
  │     └── MHF5005 × 1 → 首 Yaw 軸
  ├── CAN2（車体系）
  │     │   スリップリング経由で gamma_neck → gamma_chassis へ
  │     ├── CAN_CHASSIS 1〜4 → DM2325 × 4（オムニ 4 輪）
  │     └── CAN_LEG 1〜4     → DM4310 × 4（各車輪の持ち上げ機構）
  ├── PWM × 2 → ESC → 射出ローラー × 2
  └── UART（半二重、1kΩ 合流） → ST3215 サーボ（装填）
```

## 基板構成

| 基板 | 役割 | 状態 |
|---|---|---|
| gamma_turret | 制御基板。Stamp-P4、CAN × 2、ESC PWM × 2、ST3215 UART、Jetson UART、BNO055 | 部品実装中 🔧 |
| gamma_neck | 受動分配。スリップリング受け口、24V / CAN 分配 | 部品実装中 🔧 |
| gamma_chassis | 受動分配ハブ。24V / CAN2 分配 | 部品実装中 🔧 |

マイコンを載せるのは `gamma_turret` のみ。`gamma_neck` / `gamma_chassis` はマイコン無しの受動分配基板（電源・CAN の分配のみ）。

### gamma_neck（受動分配基板）

- スリップリング（車体 ⇔ 砲塔）の受け口
- 24V 分配（首モータ 3 台 + P4 キャリア）
- CAN 分配（CAN1 → 首モータ、CAN2 → P4 へパススルー）
- ゲームモジュール線（PA 4P）パススルー
- CAN 終端抵抗は基板に載せず、モータ内蔵の切替終端で運用（バス最遠の 1 台のみ ON）
- 状態: 案 A（純受動・最小構成）で設計確定。生基板到着、部品実装中 🔧

### gamma_chassis（受動分配ハブ）

- 24V 入力（6P）と電源分配（Power1〜8 / Vout1）
- CAN2 分配: CAN_CHASSIS1〜4（DM2325 車輪）/ CAN_LEG1〜4（DM4310 脚）/ CAN_TURRET1
- 状態: 生基板到着、部品実装中 🔧

### 基板間接続

| 区間 | 内容 |
|---|---|
| gamma_turret ⇔ gamma_neck | 24V 幹線、CAN1（首モータへ）、CAN2（パススルー） |
| gamma_neck ⇔ gamma_chassis | スリップリング経由。24V、CAN2、ゲームモジュール線（PA 4P） |
| gamma_chassis → 各脚・車体機構 | 24V 分配、CAN2 分配（CAN_CHASSIS1〜4 / CAN_LEG1〜4） |

### 電源系統

| 電圧 | 生成元 | 供給先 |
|---|---|---|
| 24V | 幹線 | 首モータ 3 台、P4 キャリア、車体側 |
| 7.4V | 外部 DCDC（XT30 で往復） | ST3215 サーボ、ESC |
| 5V | M78AR05-1（1A、24V から） | Stamp-P4 |
| 3.3V | Stamp-P4 内蔵 DCDC | BNO055、CAN トランシーバ VIO、Jetson UART |

### 組立時の注意

> ⚠️ gamma_neck のリング電源入力と MHF5005 出力が同じ PH 6P コネクタ。挿し違えると 24V がモータの CAN ピンに入る。
> シルク表記と組立時確認で担保する。

## アクチュエータ一覧

| 部位 | モータ | バス | 状態 |
|---|---|---|---|
| 首 Yaw | MHF5005（LK） | CAN1 | 💭 |
| 首 Pitch / Roll | DM3507 × 2（DAMIAO） | CAN1 | 💭 |
| 車輪 | DM2325 × 4、オムニ | CAN2 | 💭 |
| 脚 | DM4310 × 4、アクティブダンパ・車高調整 | CAN2 | 💭 |
| 射出 | ESC × 2 | PWM（50Hz） | 💭 |
| 装填 | ST3215 | 半二重 UART | 💭 |

## beta からの変更点

| 項目 | beta | gamma | 状態 |
|---|---|---|---|
| マイコン | STM32F303K8（Nucleo） | **ESP32-P4（M5Stack Stamp-P4）** | ✅ |
| ボード構成 | 1 枚 | **3 枚（turret = 制御、neck / chassis = 受動分配）** | ✅ |
| 上位コントローラ | Raspberry Pi 5 | **Jetson Orin Nano** | ✅ |
| CAN | 1 系統（1 Mbps） | **2 系統（CAN1 = 砲塔・ジンバル、CAN2 = 車体）** | ✅ |
| 砲塔軸 | Yaw + Pitch の 2 軸 | **Yaw + Pitch + Roll の 3 軸ジンバル** | ✅ |
| Yaw 軸モータ | MHF5005（LK、トルク制御） | MHF5005（LK） | 🔧 |
| Pitch 軸モータ | DM3507（DAMIAO MIT モード） | DM3507（DAMIAO） | 🔧 |
| Roll 軸モータ | なし | **DM3507（DAMIAO）** | 🔧 |
| 車輪 | DM2325 × 4（CAN 速度制御、オムニ） | DM2325 × 4（CAN2、オムニ） | 💭 |
| 脚 | なし | **DM4310 × 4（CAN2）。アクティブダンパ・車高調整** | 💭 |
| 装填 | 市販 MD + DC モータ（PWM） | **ST3215 サーボ（半二重 UART）** | 💭 |
| 射出 | ESC × 2（PWM 50Hz） | ESC × 2（PWM 50Hz、パルス幅は beta 踏襲） | 💭 |
| IMU | BNO055（I2C、無効化中） | **BNO055（UART、基板直載せ）** | 💭 |
| 車体 ⇔ 砲塔接続 | スリップリング | スリップリング（継続） | ✅ |
| 開発環境 | PlatformIO + stm32pio（STM32Cube） | PlatformIO（ESP32-P4） | 🔧 |
| 共通ライブラリ | rabcl（サブモジュール） | rabcl（サブモジュール、継続して拡張） | ✅ |

## 設計メモ

機体全体に関わる設計判断は `docs/` に日付付きで残す。

## ライセンス

このリポジトリの文書は © Rabbits Robotics、[CC BY 4.0](./LICENSE)。
Releases に添付するメカ CAD は CERN-OHL-P-2.0（リリースノートに明記）。
