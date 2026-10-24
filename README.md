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
- CAN 終端抵抗は基板に載せず、モータ内蔵の切替終端で運用（バス最遠の 1 台のみ ON）。DM4310 には切替終端が無い（公式説明書に記載なし）ので、CAN2 の末端は DM2325 にする。用意できるまでは gamma_chassis の CAN 用 PH に挿す自作 120Ω プラグで終端
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

- HP が 0 になるとゲームモジュールが 24V 幹線を切る。P4 キャリアも幹線から給電しているのでモータと一緒に落ちる（v1.0 に切られない電源は無い）。Jetson は別電源。復電後はファームが試合中にコールドスタートするので、起動時に勝手に動かない作り（制御の設計書）と、無通電でメカストが車体を支えることが前提
- **対策（2026-10-24 決定）**: Jetson の USB ポートから Stamp-P4 の USB-C へケーブルをつないでおく。Stamp-P4 の VBUS は基板の +5V ネットに直結しているので（10/18 の通電メモで実測）、24V が切れても P4・CAN トランシーバ・IMU は動き続け、beta と同じ「マイコンは落ちない」構成になる。復電時はファームがモータを再イネーブルし、脚は現在角から復帰する。注意: USB → +5V ネットの逆流は v1.0 の設計意図ではなく v1.1 で逆流防止を入れる予定。Jetson の USB は他の機器とハブで共用しない。副産物として Jetson からファームのログ取得・書き込みができる。ファームの起動時に待ちを入れない方針（復電後に素早く動き出す）は USB 給電が無い場合のために維持する

### 組立時の注意

> ⚠️ gamma_neck のリング電源入力と MHF5005 出力が同じ PH 6P コネクタ。挿し違えると 24V がモータの CAN ピンに入る。
> シルク表記と組立時確認で担保する。

- DAMIAO モータの XT30(2+2): 太い 2 本が VCC / GND、細い 2 本が CAN。付属ケーブルは細い線も赤 / 黒で、**赤 = CAN_H、黒 = CAN_L**（2026-10-22 DM4310 で確認。コネクタの図ではキー突起側が CAN_H）

## アクチュエータ一覧

| 部位 | モータ | バス | 状態 |
|---|---|---|---|
| 首 Yaw | MHF5005（LK） | CAN1 | 💭 |
| 首 Pitch / Roll | DM3507 × 2（DAMIAO） | CAN1 | 💭 |
| 車輪 | DM2325 × 4、オムニ | CAN2 | 💭 |
| 脚 | DM4310 × 4、アクティブダンパ・車高調整 | CAN2 | 💭 |
| 射出 | ESC × 2 | PWM（50Hz） | 💭 |
| 装填 | ST3215 | 半二重 UART | 💭 |

## 操作と制御の仕様（2026-10-23 時点、💭）

### 操作（本番はキーボードとマウス。ゲームパッドはデバッグ用）

| 入力 | 動作 |
|---|---|
| W / S / A / D | 車体の並進 |
| Z / C | 車体の旋回 |
| マウス移動 | 視点（砲塔 Yaw / Pitch）。地面に対するカメラの向きを動かす。マウスを動かさない限り、車体が傾いたり回ったりしても視点は変わらない |
| マウス右（押している間） | 射出 |
| マウス左（右と同時） / R | 装填 / 装填の逆転 |
| Ctrl（押している間） | 歩き（低速）。離すと走り（高速）が既定 |
| Shift（押している間） | しゃがみ。弾除け用。素早く最低車高まで沈み、離すと通常の車高に戻る |
| Space（押している間） | 無限回転（胴体の当たり判定を避ける）。視点は保たれる |
| Q / E（押している間） | リーン（胴体を左右に傾ける）。首のロールを併用するかは保留 |
| X ほか | 未割り当て（安定化の入切などの候補） |

### 制御の 2 層構造

| 層 | バス / 周期 | 役割 |
|---|---|---|
| 首（Yaw / Pitch / Roll） | CAN1、各 500 Hz | 視点の安定化。IMU（カメラと同じリンク）で測った向きを、マウスで決めた目標の向きに保つ（ジンバル）。無限回転中の Yaw の打ち消しもここ |
| 脚（4 本） | CAN2、各 250 Hz | アクティブダンパ。段差の衝撃を吸収しつつ、車高（通常 / しゃがみ）とリーン（ロール / ピッチ）で車体の姿勢を作る。ジャンプは保留 |
| 車輪（4 輪） | CAN2、各 250 Hz | オムニの速度制御。歩き / 走りの速度上限、無限回転の旋回成分 |

- CAN2 は 0.5 ms ごとに 1 台（車輪 4 + 脚 4 を 4 ms で一巡）、CAN1 は 0.67 ms ごとに 1 台。等間隔に送り、送る直前にその関節の指令を計算する
- IMU は BNO055（UART、融合出力 100 Hz が上限）。首のループは 500 Hz だが姿勢の更新は 100 Hz。追い込む段階で足りなければ基板 v1.1 で SPI の IMU に替える（IMU の読み出しは差し替えられる形にする）

### PC → ファームの指令（rabcl の共通プロトコル）

| 内容 | メッセージ |
|---|---|
| 車体速度（vx, vy, wz） | `CHASSIS_VEL` |
| 砲塔の向きの目標（yaw_joint / pitch_joint / roll_joint） | `JOINT_CMD` |
| 車高（0〜1、0 = 最低）、ロール、ピッチの目標 | `BODY_POSE`（新規。脚の角度への変換はファームの機体定義に閉じる） |
| 射出 / 装填 / 歩き・走り / 無限回転 / 安定化の入切 | `MODE` |

### 脚の扱い

- 原点（SaveZero、0 rad）が最低車高、約 1.6 rad が最高。柔らかさ（目標の両側に動ける余裕）を保つため、メカストの手前に余裕を取り、使える範囲は「0 + 余裕 〜 1.6 − 余裕」。しゃがみはその下限、通常の車高は中間
- 制御は MIT モードで「弱い kp + kd + 荷重分と摩擦分のフィードフォワード tff」。摩擦 + 自重の実測 0.2〜0.3 Nm（出力軸）は **脚モータ単体、車体を載せていない状態**の値で、機体が組み上がると大きく変わる。tff の値は組み上がった状態で取り直す

### 通信が途絶えたとき

PC からの指令が 0.5 秒来なければ「立ったまま止まる」: 車輪は停止、射出と装填は停止、無限回転は解除、首は今の向きを保持、脚は姿勢と減衰を保つ。指令が戻れば自動で復帰する。

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
