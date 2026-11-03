# FPGA 实时多音色电子乐器系统

基于 Tang Mega NEO 138K B（GW5AST-138B）的 Verilog 数字乐器工程。本仓库按提供的源码压缩包整理，包含 RTL、约束、ROM、仿真测试、构建脚本、归档报告和可烧录比特流。

## 功能与硬件

- 32 声部音频合成，逐声部 DDS、ADSR 包络和力度控制。
- 钢琴、吉他、鼓组音色；延迟、合唱、混响及音频可视化。
- RGB 电容触摸屏、WAX 数字压力输入、USB UART 与蓝牙串口控制。
- 编码器参数调节、压力跟练、音符事件记录及最终 PCM 采集。
- 板载 PT8211 DAC 输出，16 位 PCM；音频逻辑时钟 26.25 MHz，采样率约 45.573 kHz。

本次归档顶层保留五路 EC11 输入槽，旧式激光、RC 和模拟 FSR 输入默认关闭。实际接线以 `firmware/src/piano.cst` 和顶层端口为准。此仓库不包含手机 App 工程，也不应与其他激光琴集成版本混同。

## 目录

| 路径 | 内容 |
|---|---|
| `firmware/laser_touch_bt_fsr_B.gprj` | Gowin 工程入口 |
| `firmware/src/` | RTL、物理约束、时序约束与 ROM 数据 |
| `firmware/sim/` | Verilog / SystemVerilog 仿真测试 |
| `firmware/scripts/` | 构建、测试及界面生成脚本 |
| `firmware/bitstream/` | 提供的 B 版烧录文件 |
| `firmware/reports/` | 提供的构建与仿真报告 |
| `pressure_port/` | WAX 压力输入移植模块、约束与测试 |
| `reference/` | 原始压力模块参考 |
| `verification.json` | 该归档版本的验证摘要 |
| `SHA256SUMS.txt` | 原始归档附带的文件校验记录 |

## 打开与编译

在 Gowin IDE 中打开 `firmware/laser_touch_bt_fsr_B.gprj`，目标器件为 GW5AST-138B。工程所需的 `.hex`、`.mem` 和 `.vh` 文件必须与 RTL 一同保留。

也可以使用 Windows 下的 Python 构建脚本；将示例路径改为本机的 Gowin 安装位置：

```powershell
python firmware/scripts/build.py --eda "E:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/bin/gw_sh.exe"
```

脚本使用临时盘符映射规避 EDA 的中文路径问题；完整参数通过 `--help` 查看。

## 烧录

使用 Gowin Programmer，选择 GW5AST-138B → SRAM Mode → SRAM Program，加载：

`firmware/bitstream/Mega138K_KNOB_WAX_RESTORE32_B_20261102.fs`

SRAM 配置在断电后失效。引脚、电压和外设连接应与此版本约束匹配。

## 仿真与验证记录

测试脚本为 `firmware/scripts/run_tests.py`，需要已安装 ModelSim 和 Gowin GW5A 仿真库。通过 `MODELSIM_BIN` 指定 ModelSim 可执行文件目录，通过 `GOWIN_PRIMITIVES` 指定 `prim_sim.v`，再运行：

```powershell
python firmware/scripts/run_tests.py
```

`verification.json` 记录该压缩包的 15 组已通过测试、建立/保持时序违规端点均为 0，并标记 `hardware_tested: false`。这些是随源码提供的归档结果，本次上传没有重新运行编译、仿真或实板测试。

归档比特流 SHA-256：

`9ef971b6662e68f17f7decc8171b69b5510cbf2c23ba8301733e759e0c358165`

## 来源与许可

源码、参考文件及原有版权说明保持原样。此仓库未新增统一开源许可证；第三方组件的使用范围以其原有声明与授权为准。
