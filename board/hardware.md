# 上板、接线与验收

适用板卡为 ATK-DF7010/7020P V3.9，核心芯片 xc7z010clg400-1；屏幕为 ATK-MD0700R-1024600-IPS，16 灯 WS2812B 经 TXS0108E 转换。换板型或 PCB 版本应先核对原理图和约束。

## 断电接线

屏幕使用配套 RGB LCD 连接器和 FPC，插拔排线前完全断电。识曲数据通过底板 USB UART，JTAG 仅用于配置。

| 起点 | 终点 |
| --- | --- |
| 底板 P5 第 3 针 CH34C_RX | 底板 P5 第 5 针 PL_TX，用一只跳帽短接 |
| 底板 P5 第 4 针 CH34C_TX | 底板 P5 第 6 针 PL_RX，用另一只跳帽短接 |
| 电脑 USB 数据线 | 开发板标有 USB UART 的 Type-C 接口 |
| JTAG 下载器板端排线 | 开发板 JTAG 接口 |

P5 位于白色 RGB TFTLCD 屏幕排线插座正上方，在 P3 下方，是三排两列针座。将板上文字摆正，以网口和电源接口一侧为上方：

```text
上排：第 1 针 PS_TX       第 2 针 PS_RX
中排：第 3 针 CH34C_RX    第 4 针 CH34C_TX
下排：第 5 针 PL_TX       第 6 针 PL_RX
```

左列中排与下排竖直短接；右列中排与下排竖直短接。上排两针不接跳帽。历史接法照片见 [P5 实物照片](photos/p5_pl_uart_20261031.jpg)。

灯环采用独立稳压 5 V 电源，下面每条都是明确的点到点连接；实物针号以第一脚标志核对，不按照片朝向猜测。

| 起点 | 终点 |
| --- | --- |
| 底板 ATK MODULE 区 U4 第 1 针 LED | TXS0108E 的 A1 |
| TXS0108E 的 B1 | 灯环黄色 DIN |
| 核心板扩展排针 J3 第 38 针 +3.3 V | TXS0108E 的 VA |
| TXS0108E 的 VA | TXS0108E 的 OE，用短线连接 |
| 独立 5 V 电源正极 | TXS0108E 的 VB |
| 同一独立 5 V 电源正极 | 灯环红色 VCC |
| 底板 ATK MODULE 区 U4 第 5 针 GND | TXS0108E 的 GND |
| 独立 5 V 电源负极 | TXS0108E 的 GND |
| 灯环黑色 GND | TXS0108E 的 GND |

灯环数据输出是 N15，旧 J3 第 33 针 T15 已用于 LCD_R3。不要把灯环接回该旧数据针。独立 5 V 的正极不与开发板另一个 5 V 电源正极并接；FPGA 数据端保持 3.3 V，经转换器驱动灯环。其余转换通道空置。

## 下载入口

从仓库根目录调用已安装的 Vivado：

```powershell
& "C:\Xilinx\Vivado\2022.2\bin\vivado.bat" -mode batch -source board/jtag_device.tcl -tclargs probe
& "C:\Xilinx\Vivado\2022.2\bin\vivado.bat" -mode batch -source board/jtag_device.tcl -tclargs program artifacts
```

示例路径换成本机安装位置。`probe` 只检查链路；`program artifacts` 下载随包镜像，`program output` 下载刚重建的镜像。目标要求恰好一个下载器与一个 XC7Z010；配置应为 DONE=1、CRC_ERROR=0、USR_ACCESS=4E375231。本脚本不写 Flash，断电后应重新核对镜像。

## 按键与现场顺序

1. 上电下载后保持 ROM，确认 750 Hz 与 3000 Hz 的参考频谱柱。电脑程序选择 CH340 对应串口，固定 500000、8N1，连接并确认屏幕中文回显。
2. PL_KEY1 开启八色竖条与逐灯自检，再按退出。本轮用户已确认“彩条正确，灯环逐灯点亮”。这不代替音乐联动验收。
3. PL_KEY0 在 ROM、MIC、LINE IN 间切换。LINE IN 接模拟音源输出，先沿用已验证的小音量，再按实际频谱调整。
4. 分别在 LINE IN 与 MIC 下播放已入库原版音乐，核对频谱、灯环、电脑与实物 LCD 的歌名。首次采样与一致性确认需要时间，ROM 不识曲。
5. 已知歌曲持续播放、换歌、库外歌、停声、模式切换、断开恢复和 30 分钟连续运行分别记录。

历史 LINE IN 识曲已有记录。两路采集和本轮灯环自检已确认，其余当前版本项目以 `board/results/acceptance.json` 为准。没有新的现场观察就保留待验收。

## 下机

停止音乐，断开电脑识曲程序，关闭灯环独立 5 V；拔下 LINE IN、USB UART 和 JTAG 的电脑端 USB，关闭开发板电源并拔下直流电源，确认屏幕与电源灯熄灭。USB 可能形成供电路径，调整接线前应完整断电。
