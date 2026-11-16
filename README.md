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
| ROS 2 ワークスペース | [rabbits_ws](https://github.com/rabbits-robotics/rabbits_ws) | Dev Container と取り込み一覧（`default_package_list.repos`） |
| 横断 launch と機体一覧 | [rabbits_bringup](https://github.com/rabbits-robotics/rabbits_bringup) | `gamma.launch.py`（実機）/ `gamma_sim.launch.py`（偽ファーム）、**`gamma.repos`**（gamma に要るパッケージ一覧） |
| 機体固有設定（URDF / 脚リンクの寸法 / ミキサー） | [rabbits_description](https://github.com/rabbits-robotics/rabbits_description) | `urdf/gamma/`、`config/gamma_linkage.yaml` |
| 操作者が見る道具（rviz の 2 体表示） | [rabbits_gui](https://github.com/rabbits-robotics/rabbits_gui) | Command（マイコンの指令）と Actual（フィードバック）を重ねて表示 |
| 偽ファーム | [rabbits_sim](https://github.com/rabbits-robotics/rabbits_sim) | 実機なしで bridge から先を動かす |
| メカ CAD | 本リポジトリの Releases | 節目ごとに SolidWorks 一式を zip で添付。CERN-OHL-P-2.0。ローカルは `mech_ws/gamma_proto3`（ロール軸なしの版。proto1 / proto2 は旧案） |

## 環境構築（Raspberry Pi 5 側）💭

```bash
git clone https://github.com/rabbits-robotics/rabbits_ws.git
cd rabbits_ws
vcs import src < src/rabbits_bringup/gamma.repos   # 先に rabbits_bringup だけ取る
colcon build
```

`gamma.repos` は rabbits_bringup にある（今は全パッケージ `main`。実機で動いた時点で `vcs export --exact` でコミット固定し、rabcl は gamma_turret_fw の submodule と同じコミットを指す）。Pi 5 の OS は Ubuntu 24.04（arm64）+ ROS 2 Jazzy で、beta と同じ構成。セットアップ手順は Pi を載せる段階で rabbits_ws の README に書く。

## システム構成

```
[ Raspberry Pi 5 ]  ← ゲーム中は Wi-Fi / Bluetooth を切る（ルール III-5.2）
  │ USB-A ×4: FT234X（P4 へ）、CH9102F（トランシーバーから）、P4 の 5V 給電、予備（練習用ゲームパッド受信機）
  ├─ USB-UART（AE-FT234X、3.3V TTL、230400）→ gamma_turret の PC_UART
  └─ USB-UART（AE-CH9102F-TYPEC-BO、3.3V TTL、115200、受信のみ）← トランシーバーモジュール（ゲームモジュール）
  ▼
[ gamma_turret（M5Stack Stamp-P4 / ESP32-P4） ]  ← BNO055 IMU（UART、基板直載せ）
  ├── CAN1（砲塔・ジンバル系）
  │     ├── MHF5005 × 1 → 首 Yaw 軸
  │     └── DM3507  × 1 → 首 Pitch 軸（ロール軸なし）
  ├── CAN2（車体系）
  │     │   スリップリング経由で gamma_neck → gamma_chassis へ
  │     ├── CAN_CHASSIS 1〜4 → DM2325 × 4（オムニ 4 輪）
  │     └── CAN_LEG 1〜4     → DM4310 × 4（各車輪の持ち上げ機構）
  ├── PWM × 2 → ESC → 射出ローラー × 2
  └── UART（半二重、1kΩ 合流） → ST3215 サーボ（装填、増速 3:1）
```

- 上位コントローラは **Raspberry Pi 5**（beta と同じ）。Jetson Orin Nano の案（2026-10）はレイアウトの都合で取り下げた（2026-11-14）
- Pi 5 と P4 / トランシーバーの UART は **USB-UART 変換で取る**（2026-11-15 決定）。P4 側は AE-FT234X（FTDI FT234X）、トランシーバー側は秋月 AE-CH9102F-TYPEC-BO（WCH CH9102F、Linux は ch341 ドライバ）。Pi のピンから直接取る案もあるが、変換基板なら Pi を外して PC に差し替えても同じ配線・同じ手順で動かせることを優先した。デバイス名は `/dev/serial/by-id/`（`usb-FTDI_FT230X_...` / `usb-1a86_USB_Single_Serial_...`）で固定する。CH9102F モジュールは IO 電圧が電源に従うので、トランシーバー側（3.3V TTL）に合わせて 3.3V で使うことを配線時に確認する
- 首は Yaw + Pitch の 2 軸。ロール軸は 2026-10-25 の検討（脚の可動域との取り合い、首を短くする）どおり廃止し、2026-11-14 のメカ設計で確定。ソフトでは `roll_joint` を論理関節として残し、ファームは 0 を返す（基板・ファーム・ROS 設定は共有、URDF は首の寸法だけ差し替え）

## 基板構成

| 基板 | 役割 | 状態 |
|---|---|---|
| gamma_turret | 制御基板。Stamp-P4、CAN × 2、ESC PWM × 2、ST3215 UART、PC UART、BNO055 | 実装済み。通電（2026-10-18）、CAN2 で脚 4 本、IMU UART、PC リンクを確認 ✅ |
| gamma_neck | 受動分配。スリップリング受け口、24V / CAN 分配 | 実装済み。首モータ待ち 🔧 |
| gamma_chassis | 受動分配ハブ。24V / CAN2 分配 | 実装済み。脚 4 本の試験で使用（CAN_TURRET1 ピン 1 はジャンパ対応） ✅ |

マイコンを載せるのは `gamma_turret` のみ。`gamma_neck` / `gamma_chassis` はマイコン無しの受動分配基板（電源・CAN の分配のみ）。

### gamma_neck（受動分配基板）

- スリップリング（車体 ⇔ 砲塔）の受け口
- 24V 分配（首モータ 2 台 + P4 キャリア）
- CAN 分配（CAN1 → 首モータ、CAN2 → P4 へパススルー）
- ゲームモジュール線（PA 4P）パススルー
- CAN 終端抵抗は基板に載せず、モータ内蔵の切替終端で運用（バス最遠の 1 台のみ ON）。DM4310 には切替終端が無い（公式説明書に記載なし）ので、CAN2 の末端は DM2325 にする。用意できるまでは gamma_chassis の CAN 用 PH に挿す自作 120Ω プラグで終端。DM2325 / DM3507 / MHF5005 の切替終端の有無は確認中（無ければ外付け 120Ω か基板 v1.1 で P4 側に切替終端）
- 状態: 案 A（純受動・最小構成）で設計確定。実装済み 🔧

### gamma_chassis（受動分配ハブ）

- 24V 入力（6P）と電源分配（Power1〜8 / Vout1）
- CAN2 分配: CAN_CHASSIS1〜4（DM2325 車輪）/ CAN_LEG1〜4（DM4310 脚）/ CAN_TURRET1
- 状態: 実装済み、脚 4 本で使用中 ✅

### 基板間接続

| 区間 | 内容 |
|---|---|
| gamma_turret ⇔ gamma_neck | 24V 幹線、CAN1（首モータへ）、CAN2（パススルー） |
| gamma_neck ⇔ gamma_chassis | スリップリング経由。24V、CAN2、ゲームモジュール線（PA 4P） |
| gamma_chassis → 各脚・車体機構 | 24V 分配、CAN2 分配（CAN_CHASSIS1〜4 / CAN_LEG1〜4） |
| Pi 5 ⇔ gamma_turret | USB-UART（AE-FT234X）で PC_UART へ。P4 の 5V 給電は Pi の USB-A から USB-C へ |
| トランシーバーモジュール → Pi 5 | UART 3.3V TTL（115200、受信のみ）を AE-CH9102F-TYPEC-BO で USB へ |

### 電源系統

| 電圧 | 生成元 | 供給先 |
|---|---|---|
| 24V | 幹線（パワーマネジメントモジュールのドライブ電源） | 首モータ 2 台、P4 キャリア、車体側 |
| 7.4V | 外部 DCDC（XT30 で往復） | ST3215 サーボ、ESC |
| 5V | M78AR05-1（1A、24V から） | Stamp-P4 |
| 5V | モバイルバッテリー（PD トリガー無しの素の 5V 出力。容量は機体のバッテリー合計 100 Wh に含める） | Raspberry Pi 5 |
| 3.3V | Stamp-P4 内蔵 DCDC | BNO055、CAN トランシーバ VIO、PC_UART |

- HP が 0 になるとゲームモジュールが 24V 幹線（ドライブ電源）を切る。P4 キャリアも幹線から給電しているのでモータと一緒に落ちる（v1.0 に切られない電源は無い）。Pi 5 はモバイルバッテリーで生きる。復電後はファームが試合中にコールドスタートするので、起動時に勝手に動かない作り（制御の設計書）と、無通電でメカストが車体を支えることが前提
- **P4 への USB 給電はしない（2026-11-16 決定。2026-10-24 の「Pi 5 の USB から Stamp-P4 の USB-C へ給電して 24V 断でもマイコンを落とさない」案を取り下げ）**: HP 0 で P4 はモータと一緒に落ち、復電でコールドスタートする。復電 → bridge 再接続 → モータ再イネーブルのラグは実機で確認して許容範囲（2026-11-16、USB-C 無しで 24V 断 → 復電）。取り下げた理由: Stamp-P4 の VBUS は基板の +5V ネットに直結で、USB の 5V が M78AR05 を逆流して 24V バスを約 4 V に保つ（11-16 実測 4.13 V）ため、USB 給電のままだと 24V 断で DAMIAO が低電圧エラーをラッチして Enable では戻らない。USB-C は書き込みとログ取得だけに使う（机上で 24V を切るときは USB-C も抜く）。ファームの起動時に待ちを入れない方針（復電後に素早く動き出す）はこの構成の要
- Pi 5 は PD 交渉で 5A 電源と認識しない限り USB の合計供給を 600 mA に制限する。Pi の USB から取るのは USB-UART 変換 2 枚（AE-FT234X、AE-CH9102F）だけになったので 600 mA で足りる見込み。足りなければ `config.txt` に **`usb_max_current_enable=1`**（1.6 A まで許可）。モバイルバッテリーの 5V 出力は Pi 5 本体ぶん（3 A 以上）を確認する 🔧

### 組立時の注意

> ⚠️ gamma_neck のリング電源入力と MHF5005 出力が同じ PH 6P コネクタ。挿し違えると 24V がモータの CAN ピンに入る。
> シルク表記と組立時確認で担保する。

- DAMIAO モータの XT30(2+2): 太い 2 本が VCC / GND、細い 2 本が CAN。付属ケーブルは細い線も赤 / 黒で、**赤 = CAN_H、黒 = CAN_L**（2026-10-22 DM4310 で確認。コネクタの図ではキー突起側が CAN_H）
- BNO055 モジュール（秋月 K-16996）のジャンパ: UART モードは J3 接続・J4 接続・**J5 を完全に除去**・J2 開放。J3 と J5 が同時に閉じていると VOUT が GND に短絡して LP5907 が発熱する（2026-11-01、2 台がこれで止まった）

## アクチュエータ一覧

| 部位 | モータ | バス | 状態 |
|---|---|---|---|
| 首 Yaw | MHF5005（LK） | CAN1 | 両持ち化・メカスト追加のメカ設計完了、部品待ち 🔧 |
| 首 Pitch | DM3507（DAMIAO） | CAN1 | 同上。可動角 −15°〜+30° 🔧 |
| 車輪 | DM2325 × 4、オムニ | CAN2 | 💭 |
| 脚 | DM4310 × 4、アクティブダンパ・車高調整 | CAN2 | 4 本で車高・ロール・ピッチ・途絶の据え置き・24V 断 → 復電を実機確認（2026-11-01、浮かせた状態）✅。接地後にゲイン調整 |
| 射出 | ESC × 2 | PWM（50Hz） | 💭 |
| 装填 | ST3215、**増速 3:1**（サーボ 1 回転で装填側 3 回転。2026-11-14 に 2:1 から変更、連射重視） | 半二重 UART | 単体確認済み（2026-10-31）、トルク試験はストッパー製作後 🔧 |

## メカ（2026-11-14 時点）

- 設計完了（`mech_ws/gamma_proto3`）、部品発注済み（2026-11-22 頃到着）。到着後に組み立て
- 首はロール軸なしの Yaw + Pitch。安定性のため両持ち、メカスト追加。Pitch の可動角 −15°〜+30°（URDF の `pitch_joint` の limit と同じ）
- 装填の ST3215 は増速 3:1。10-31 の単体試験（2:1 で決めた経緯: 行き過ぎと滞留時間）に対して 3:1 で穴に止まるかは、組み付け後に確認する
- 首のリンク長など、URDF と IMU 取り付け向きに関わる寸法は組み立て後に rabbits_description の `urdf/gamma/neck.xacro` と `config/gamma_linkage.yaml` に反映する
- 競技ルールの寸法制限（初期 300 × 300 × 300 mm、展開 450 × 450 × 400 mm）とバッテリー 100 Wh 以下の範囲で設計

## 競技ルールの要点（ATTRACTS ルールブック v1.0 から、機体設計に関わるもの）

| 項目 | 内容 |
|---|---|
| 寸法 | 初期 300 × 300 × 300 mm、ゲーム中の展開 450 × 450 × 400 mm（III-2.1） |
| 動力 | 電気（バッテリー合計 100 Wh 以下、公称電圧で計算）か弾性力。高圧エア不可（III-2.2） |
| 球 | 0.2 g 蓄光 BB 弾、弾速上限 30 m/s（車検で測定）（III-2.5） |
| 必須モジュール | マズル 1、ヒットパネル 4（対辺配置、取付角 75°、中心高さ 150 mm 以下、パネル面から勾配 60° の範囲を遮らない）、カメラ 1、パワーマネジメント 1、トランシーバー 1（III-3） |
| 電源 | パワーマネジメントモジュールが**ドライブ電源**（撃破・侵入・カウントダウンで遮断）と**ロジック電源**（遮断されない）を持つ。アクチュエータ・発光・発音はドライブ電源から。ユーザ MCU はロジック電源か別バッテリー可（III-3.5） |
| トランシーバー → ユーザ MCU | **UART 3.3V TTL、115200、受信のみ**。0xAE 始まりのフレーム（CRC-8 / CRC-16）で `DataInput`（9 B、キー・マウス）と `DataRobot`（11 B、HP・熱量）が 50 Hz（III-4.1）。途絶時は全入力を離した扱いで停止を推奨（III-4.2） |
| 無線 | ゲームモジュール以外の無線通信は禁止。デバッグ用の無線デバイスの搭載は可だがゲーム中の使用は禁止（III-5.2）→ Pi 5 の Wi-Fi / Bluetooth はゲーム中に切る |
| 通信切断 | 操縦アプリとの通信が切れたロボットは操縦不能のままフィールドに残る（再接続しても直ちには復帰できない）（II-10.1） |

ルールブック本体は運営の配布物（PDF、2 次配布不可）。git には置かず、版が上がったらこの表を見直す。

## 操作と制御の仕様（2026-10-23 時点、💭。ロール軸の廃止で 2026-11-14 に一部更新）

### 操作（本番はキーボードとマウス。ゲームパッドはデバッグ用）

| 入力 | 動作 |
|---|---|
| W / S / A / D | 車体の並進 |
| Z / C | 車体の旋回 |
| マウス移動 | 視点（砲塔 Yaw / Pitch）。マウスを動かさない限り、車体が傾いても視点は変わらない（pitch の安定化。ロールは首に軸が無いので脚のリーンで作る）。Yaw は無限回転中だけ地面に対して保ち、Z / C の旋回では車体と一緒に回る |
| マウス右（押している間） | 射出 |
| マウス左（右と同時） / R | 装填 / 装填の逆転 |
| Ctrl（押している間） | 歩き（低速）。離すと走り（高速）が既定 |
| Shift（押している間） | しゃがみ。弾除け用。素早く最低車高まで沈み、離すと通常の車高に戻る |
| Space（押している間） | 無限回転（胴体の当たり判定を避ける）。視点は保たれる |
| Q / E（押している間） | リーン（胴体を左右に傾ける） |
| X ほか | 未割り当て（安定化の入切などの候補） |

### 制御の 2 層構造

| 層 | バス / 周期 | 役割 |
|---|---|---|
| 首（Yaw / Pitch） | CAN1、各 500 Hz | 視点の安定化。IMU（カメラと同じリンク）で測った向きを、マウスで決めた目標の向きに保つ（ジンバル）。無限回転中の Yaw の打ち消しもここ |
| 脚（4 本） | CAN2、各 250 Hz | アクティブダンパ。段差の衝撃を吸収しつつ、車高（通常 / しゃがみ）とリーン（ロール / ピッチ）で車体の姿勢を作る。ジャンプは保留 |
| 車輪（4 輪） | CAN2、各 250 Hz | オムニの速度制御。歩き / 走りの速度上限、無限回転の旋回成分 |

- CAN2 は 0.5 ms ごとに 1 台（車輪 4 + 脚 4 を 4 ms で一巡）、CAN1 は 0.67 ms ごとに 1 台（Yaw / Pitch / Roll の 3 スロット。Roll は送らない）。等間隔に送り、送る直前にその関節の指令を計算する
- IMU は BNO055（UART、融合出力 100 Hz が上限）。首のループは 500 Hz だが姿勢の更新は 100 Hz。追い込む段階で足りなければ基板 v1.1 で SPI の IMU に替える（IMU の読み出しは差し替えられる形にする）

### PC ⇔ ファームの通信（rabcl の共通プロトコル）

| 向き | 内容 | メッセージ |
|---|---|---|
| 下り | 車体速度（vx, vy, wz） | `CHASSIS_VEL` |
| 下り | 砲塔の向きの目標（yaw_joint / pitch_joint。roll_joint は論理関節で 0） | `JOINT_CMD` |
| 下り | 車高（0〜1、0 = 最低）、ロール、ピッチの目標 | `BODY_POSE`（脚の角度への変換はファームの機体定義に閉じる） |
| 下り | 射出 / 装填 / 歩き・走り / 無限回転 / 安定化の入切 | `MODE` |
| 上り | モータのフィードバック（Actual） | `JOINT_STATE` |
| 上り | マイコンがモータに出した指令（Command。rviz で Actual と重ねて見る） | `MOTOR_COMMAND`（2026-11 追加） |
| 上り | IMU の姿勢・角速度・加速度、機体情報、エラーフラグ | `IMU`、`INFO`、`SYSTEM` |

### 脚の扱い

- 原点（SaveZero、0 rad）が最低車高、約 1.6 rad が最高。柔らかさ（目標の両側に動ける余裕）を保つため、メカストの手前に余裕を取り、使える範囲は 0.15〜1.42 rad（車高 0〜1）。しゃがみはその下限、通常の車高は中間
- 制御は MIT モードで「弱い kp + kd + 荷重分と摩擦分のフィードフォワード tff」。ランプは 4.0 rad/s、摩擦分は差に比例（2026-11-01 確定）。`LEG_KP / KD` と荷重分 `LEG_LOAD_FORCE` は機体を接地させてから取り直す

### 通信が途絶えたとき

PC からの指令が 0.5 秒来なければ「立ったまま止まる」: 車輪は停止、射出と装填は停止、無限回転は解除、首は今の向きを保持、脚は姿勢と減衰を保つ。指令が戻れば自動で復帰する（2026-11-01 実機確認）。

## beta からの変更点

| 項目 | beta | gamma | 状態 |
|---|---|---|---|
| マイコン | STM32F303K8（Nucleo） | **ESP32-P4（M5Stack Stamp-P4）** | ✅ |
| ボード構成 | 1 枚 | **3 枚（turret = 制御、neck / chassis = 受動分配）** | ✅ |
| 上位コントローラ | Raspberry Pi 5 | Raspberry Pi 5（Jetson Orin Nano の案はレイアウトの都合で 2026-11 に取り下げ） | ✅ |
| PC リンク | USB-UART 変換 | USB-UART 変換（P4: AE-FT234X、トランシーバー: AE-CH9102F-TYPEC-BO） | ✅ |
| CAN | 1 系統（1 Mbps） | **2 系統（CAN1 = 砲塔・ジンバル、CAN2 = 車体）** | ✅ |
| 砲塔軸 | Yaw + Pitch の 2 軸 | Yaw + Pitch の 2 軸（ロール軸の案は 2026-11 に廃止）。両持ち化・メカスト追加、Pitch −15°〜+30° | ✅ |
| Yaw 軸モータ | MHF5005（LK、トルク制御） | MHF5005（LK） | 🔧 |
| Pitch 軸モータ | DM3507（DAMIAO MIT モード） | DM3507（DAMIAO） | 🔧 |
| Roll 軸モータ | なし | なし（`roll_joint` は論理関節として残し 0） | ✅ |
| 車輪 | DM2325 × 4（CAN 速度制御、オムニ） | DM2325 × 4（CAN2、オムニ） | 💭 |
| 脚 | なし | **DM4310 × 4（CAN2）。アクティブダンパ・車高調整** | 実機で動作確認（2026-11-01）🔧 |
| 装填 | 市販 MD + DC モータ（PWM） | **ST3215 サーボ（半二重 UART）、増速 3:1** | 単体確認済み 🔧 |
| 射出 | ESC × 2（PWM 50Hz） | ESC × 2（PWM 50Hz、パルス幅は beta 踏襲） | 💭 |
| IMU | BNO055（I2C、無効化中） | **BNO055（UART、基板直載せ）** | UART で実機確認（2026-11-01）✅ |
| 車体 ⇔ 砲塔接続 | スリップリング | スリップリング（継続） | ✅ |
| 開発環境 | PlatformIO + stm32pio（STM32Cube） | PlatformIO（ESP32-P4、pioarduino 55.03.312） | ✅ |
| 共通ライブラリ | rabcl（サブモジュール） | rabcl（サブモジュール、継続して拡張） | ✅ |
| 可視化 | rviz（Reference のみ） | rviz で Command / Actual の 2 体表示（rabbits_gui、IMU の傾きを反映） | ✅ |

## 設計メモ

機体全体に関わる設計判断は `docs/` に日付付きで残す。

## ライセンス

このリポジトリの文書は © Rabbits Robotics、[CC BY 4.0](./LICENSE)。
Releases に添付するメカ CAD は CERN-OHL-P-2.0（リリースノートに明記）。
