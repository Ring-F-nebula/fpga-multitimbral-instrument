# 基于 FPGA 的多模态交互数字乐器

基于 **Tang Mega NEO 138K B** 的数字乐器工程，将触摸屏、4×4 数字压力键、四个实体旋钮、手机蓝牙控制和七路激光琴接入同一声音通路。FPGA 完成音符控制、32 声部 DDS 合成、独立包络与力度处理、混音、音效和音频输出；手机端“触感”负责设备交互、曲目组织、演奏与跟练界面。

本仓库包含 FPGA 工程和 **TouchPiano 0.4.3 手机 App 源码**。项目介绍依据[设计报告](docs/design-report.pdf)，完整硬件与算法说明可查阅报告。

## 功能

| 部分 | 功能 |
| --- | --- |
| 声音合成 | 32 个独立演奏声部，钢琴、吉他和鼓组三类音色 |
| 触摸交互 | 黑白琴键、琴弦和鼓组交互，音色、包络和音效设置 |
| 压力演奏 | 16 路独立压力键，逐键校准、起音判定和持续力度控制 |
| 实体控制 | 四个 EC11 分别控制主音量、目标单音变调、颤音和 ADSR 包络 |
| 音高与包络 | 变调、触屏滑音、颤音，独立 ADSR 与预设 |
| 音效 | 延迟、合唱与混响，共享混音后处理通路 |
| 显示分析 | 实际输出波形、频谱和李萨如图形 |
| 音乐练习 | 目标按键、进度与评分；压力矩阵跟练只按真实压力输入计分 |
| 演奏记录 | 按时间戳记录音符事件并重新合成回放；另有最终 PCM 采集 |
| 手机联动 | 蓝牙设备连接、曲库、演奏、跟练、记录及手势钢琴和手势吉他入口 |
| 激光琴 | 七路光敏分压经 AD7606 SPI 采集，转换为音符状态 |

STOP 统一停止演奏与输出。恢复后，先释放此前按住的输入，再重新触发。

## 系统结构

```text
触摸屏 ─────────────┐
4×4 压力键 → WAX UART ┤
四个 EC11 旋钮 ──────┤
手机 App → 蓝牙串口 ──┼→ 统一控制 → 32 声部 DDS / ADSR / 力度
电脑 → USB 串口 ─────┤                    ↓
七路光敏 → AD7606 SPI ┘             混音 → 延迟 / 合唱 / 混响
                                           ↓
                                  滤波 / 主音量 → PT8211 → 音频口
                                           ├→ 波形 / 频谱 / 李萨如
                                           └→ PCM 采集
```

事件回放重新进入音符控制入口；PCM 采集保存最终输出样本，两者是独立通路。事件记录保存音符与时序，不保存每个时刻完整的力度、音色和音效参数。

| 参数 | 配置 |
| --- | --- |
| FPGA | Tang Mega NEO 138K B，GW5AST-LV138PG484AC1/I0，B 版 |
| 输入参考时钟 | 50 MHz |
| 显示时钟 | 52.5 MHz |
| 音频逻辑时钟 | 26.25 MHz |
| 音频采样率 | 26,250,000 ÷ 576 ≈ 45,572.9167 Hz |
| PCM 格式 | 16 位有符号，左右声道同源 |
| 显示与触摸 | 7 英寸 1024×600 RGB 屏，I²C 电容触摸 |
| 压力输入 | WAX-RX-M，4×4 共 16 单元 |
| 主音量 | 0～15 档 |

## 目录

```text
.
├── README.md                  # 工程总说明
├── .gitignore                 # 缓存、构建输出和本地签名文件忽略规则
├── docs/
│   └── design-report.pdf      # 项目设计报告
├── firmware/
│   ├── instrument_B.gprj      # Gowin 工程入口
│   ├── src/                   # 当前 RTL、头文件、ROM 数据与引脚/时钟约束
│   ├── scripts/               # 构建与仿真入口
│   ├── sim/                   # 当前功能的仿真测试及必要模型
│   └── bitstream/             # 当前版本烧录文件
├── mobile/
│   ├── app/
│   │   ├── public/            # 手机界面、协议、浏览器试听与手势识别资源
│   │   ├── android/           # Android 蓝牙壳、Java 源码与 APK 构建入口
│   │   ├── tests/             # App 协议、连接与交互测试
│   │   ├── package.json       # 启动和测试命令
│   │   └── server.mjs         # 本地浏览器预览服务
│   ├── build_bundled_scores.mjs
│   └── version.json
└── verification.json          # 当前整理版的文件完整性与验证记录
```

### FPGA 主要模块

| 模块 | 职责 |
| --- | --- |
| `dualmode_top.v` | 顶层连接、时钟、输入汇聚及输出 |
| `competition_control.v` | 统一按键、参数、映射与 STOP 状态 |
| `capacitive_touch.v`、`panel_ui.v` | 触摸采集、页面命中与交互控制 |
| `knob5_controls.v` | 旋钮相对调节、参数读回与事件排队 |
| `wax_pressure_frontend.v` 及 `wax_*` | 压力协议、采集器设置、逐键校准与力度 |
| `ad7606_spi.v`、`ad7606_laser_keys.v` | 激光琴采集、阈值、迟滞与稳定判定 |
| `poly32_synth.v`、`frequency_bank4.v`、`adsr_envelope.v` | 多声部音高、波表、包络与混音 |
| `audio_effects.v`、`audio_conditioner.v`、`audio_master.v` | 音效、滤波、主音量与输出保护 |
| `instrument_screen.v`、`panel_renderer.v`、`audio_analyzer.v`、`xy_scope.v` | 页面、波形、频谱与二维轨迹 |
| `practice32.v`、`event_recorder.v`、`audio_capture.v` | 跟练、事件记录与 PCM 采集 |

`knob5_controls` 保留 HDL 实现中的模块名。四个实体旋钮使用第 1、2、4、5 输入槽；滑音通过触屏控制。

## 硬件连接

外设与主板共地，FPGA 数字接口使用 3.3 V 电平。电源电压与数字信号电平分别配置。完整 FPGA 管脚分配以 [`piano.cst`](firmware/src/piano.cst) 为准，时钟约束见 [`piano.sdc`](firmware/src/piano.sdc)。

### 压力键与板载音频

- WAX 采集器发送端接 **J14-39 / R14（WAX_RX）**，接收端接 **J14-40 / P14（WAX_TX）**，UART 方向交叉连接。
- WAX 使用 115200 bit/s、8N1。上电时保持压力键空载，完成稳定帧校准后再演奏。
- 板载音频信号为 HP_BCK/Y17、HP_WS/AB17、HP_DIN/AA16、PA_EN/AB16；音箱或耳机使用板载音频口。

### AD7606 激光琴

本工程使用 SPI 串行模式。模块配置为 **R1 安装 10 kΩ、R2 留空**，DB15/BYTE SEL 由 FPGA 保持低电平。

**当前合并版的 ADC CS 接 J14-1/R19。若沿用此前线束，先拔掉 DB0→J14-1 的线，再将 ADC CS 移到 J14-1。J14-33/AA18 留给旋钮按压输入。**

| ADC 模块端 | 主板连接 | FPGA 封装脚 |
| --- | --- | --- |
| CS | J14-1 | R19 |
| RD / SCLK | J14-34 | AB18 |
| DB7 / DOUTA | J14-8 | R18 |
| DB15 / BYTE SEL | J14-18 | N13 |
| RST | J14-19 | V20 |
| CVA 与 CVB 并接 | J14-20 | U20 |
| BUSY | J14-35 | U18 |
| FRST | J14-36 | U17 |
| 5V / GND | J14-11 / J14-12 | 电源 / 地 |
| VIO | J8-1 | 3.3 V 电源 |

RAGE 和 OS0、OS1、OS2 接地，使用 ±5 V 量程且关闭过采样。FRST 用于有效帧校验，需要连接；定时读取不依赖 BUSY。VIO、RST 和 FRST 是不同信号。DB8/DOUTB 为 ADC 输出，不接地。

七路光敏节点接 V1～V7，V8 接地。接收分压为受光电压低、遮光电压高；程序通过独立阈值、迟滞和连续有效采样判定音符。接线调整在断电状态完成。

## FPGA 构建与烧录

使用 Gowin V1.9.11.03 Education x64。打开 [`firmware/instrument_B.gprj`](firmware/instrument_B.gprj)，目标器件选择 **GW5AST-LV138PG484AC1/I0，B 版**，顶层为 `dualmode_top`。

在仓库根目录用 PowerShell 构建，`--eda` 替换为本机工具路径：

```powershell
python firmware/scripts/build.py --eda 'C:\Tools\Gowin\IDE\bin\gw_sh.exe' --place-option 1 --route-option 2
```

脚本在独立工作目录构建，并使用临时盘符处理非 ASCII 路径。ROM 使用 `src/` 相对路径，应保留工程目录结构。

当前烧录文件为 [`firmware/bitstream/multimodal_instrument_B.fs`](firmware/bitstream/multimodal_instrument_B.fs)。原工程的采集、音频与显示逻辑保持不变；整理版移除了历史副本与未引用的模块。

## 手机 App

### 浏览器预览

安装 Node.js 后执行：

```powershell
cd mobile/app
npm start
```

浏览器打开 `http://127.0.0.1:4177`。浏览器试听在本机生成声音；连接 FPGA 时，手机发送音符和参数，FPGA 完成合成与模拟发声。

### Android 构建

原生入口为 [`MainActivity.java`](mobile/app/android/src/cn/touchpiano/app/MainActivity.java)。工程通过 Android SDK 工具直接构建 APK。将 `PIANO_ANDROID_TOOLS` 指向工具根目录，其中应有：

```text
android-15/              aapt2.exe、zipalign.exe、core-lambda-stubs.jar
└── lib/                 d8.jar、apksigner.jar
android-35-ext15/        android.jar
```

在仓库根目录设置本机路径后运行：

```powershell
$env:PIANO_ANDROID_TOOLS='C:\Android\piano-tools'
$env:PIANO_JDK='C:\Java\jdk'
$env:PIANO_SIGNING_KEY='C:\Keys\touch-piano.jks'
# PIANO_SIGNING_STORE_PASS 设置为所用签名库的密码
python mobile/app/android/build.py
```

输出位于 `mobile/build/android/`。源码包不包含签名私钥。现有构建脚本使用 `piano` 签名别名，覆盖安装需使用与原安装包一致的签名。

### 连接与演奏

在 Android 系统蓝牙设置中配对经典蓝牙 SPP 模块，再从 App 设备页连接。分别确认蓝牙连接和 FPGA 状态回传。设备页显示模式、音色与主音量；演奏页提供琴键、力度显示、记录和全部松音操作。

曲库和跟练页面负责选曲、节奏设置、判定反馈与结果显示。手机键位编号与 FPGA 压力单元 A0～A15 的编号方向不同，上传曲谱时通过适配层进行转换。手势钢琴和手势吉他在手机端识别，连接板卡后通过统一音符协议控制 FPGA 发声。

## 验证

FPGA 整理前的 SPI 集成版已完成 18 组 RTL 测试及完整布局布线。当前仓库保留 17 组功能测试；使用历史压力实现作为对照的旧版本测试已移除。当前生产 RTL、ROM 与约束逐字节保留，校验值及打包检查记录见 [`verification.json`](verification.json)。整机模拟输出和传感器联调与数字验证分别记录。

FPGA 仿真需 ModelSim 和 Gowin GW5A 原语库，在仓库根目录执行：

```powershell
$env:MODELSIM_BIN='C:\Tools\ModelSim\win32aloem'
$env:GOWIN_PRIMITIVES='C:\Tools\Gowin\IDE\simlib\gw5a\prim_sim.v'
$env:SIM_LCD_STUB='1'
python firmware/scripts/run_tests.py
```

App 测试：

```powershell
cd mobile/app
npm test
```
