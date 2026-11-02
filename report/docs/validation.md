# 正确性如何确认

## 分层证据

| 层次 | 检查方法 | 随包证据 |
| --- | --- | --- |
| 基础控制与采音 | 复位、消抖、测试源、I2C 初始化及故障、I2S 左右声道、音频时钟 | `sim/tb/tb_*` 与 `sim/results/archived_rtl/tb_*.log` |
| FFT 与可视化 | 流协议检查、1024 点 FFT 对 NumPy、频段峰值、RGB 时序、LCD 时序、整帧图像与系统集成 | FFT CSV、21 项仿真日志和渲染图 |
| 识曲通信 | 127 抽头 FIR 定点参考、抽取、音频分包、CRC、模式/epoch 切换、中文位图与显示缓冲 | FIR 向量、`pcm_uart_capture.hex`、`uart_host_crosscheck.json` |
| 主机算法与状态 | 33 项生产模块回归，包含未知与歧义、左右声道、冻结采样进度、错误偏移、低分保持、停声和恢复 | `sim/results/archived_pc/regression_33.log` |
| 保存录音回放 | 7 项显示、11 项取得身份与拒识，保存数值和时间线 | `sim/results/archived_pc/display_replay/`、`mic_acquisition_summary.json` |
| 历史歌曲矩阵 | 已入库原录音、降增益加噪、左声道/FIR/串口模型、三首未录入歌曲、静音和白噪声 | `sim/results/archived_pc/historical_155_cases/` |
| 实物现场 | JTAG 身份、连续串口、实际中文 LCD、已知与库外 LINE IN、人工确认的采音及灯环自检 | `board/results/` |

## 数值参考复现

完整 RTL 仿真后，从仓库根目录运行：

```powershell
python sim/tools/fft_reference_check.py
python sim/tools/verify_serial_capture.py
python sim/tools/verify_lcd_frame.py
```

新输出读取 `build/current/`。FFT 要求 1024 个顺序 bin、主峰为 16 与 64、相对 L2 误差小于 0.001。串口检查要求 4 包、CRC 为零、序号与模式切换正确、每一个采样与参考相等。程序中断或缺失输入会失败，不会把缺失文件当作通过。

## 实物与算法边界

历史 LINE IN 实测含 5 首歌、15 个不同片段；用户逐首确认了 5 种歌名/演唱者与实物 LCD 一致，没有假定每个片段都逐段人工观察。库外 3 首正确拒识。矩阵引用的结果 JSON 位于 `board/results/line_cases/`。

MIC 曾出现正确歌名随后丢失，也出现过无首次确认的试验。V0.3.2 修订了连续时间证据确认和保持，33 项回归及保存录音回放通过；这些不代替新版现场稳定性测试。用于设计修订的正例录音不作为独立准确率样本；公开包不包含用户原始歌曲或 MIC 音频。

本轮用户已确认两路采音、屏幕彩条和灯环逐灯自检。当前音乐驱动灯环、歌名持续保持、换歌/停声/异常恢复和 30 分钟整机运行仍为待验收。ACK 只说明文字数据被接收，不自动证明物理屏幕与灯环显示正确。

## 独立目录重检

本仓库从不带 `.xpr`、IP 缓存、虚拟环境和曲库的干净目录创建。此前重检记录集中放入 `sim/results/previous_reproduction/`：主机回归、RTL 仿真、数值参考、报告校验与曲库附件恢复。重检只进行离线构建和检查，不重新操作串口、JTAG 或外部接口。
