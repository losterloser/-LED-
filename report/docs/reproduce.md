# 从当前目录复现

所有命令从项目根目录执行。验证环境为 Windows、Python 3.12、Vivado 2022.2，器件 xc7z010clg400-1。安装工具时启用 Zynq-7000 器件、FFT 9.1 与 ILA 6.2 IP。依赖见 `src/pc/requirements.txt`。

1. 执行 `src/pc/setup.ps1` 安装独立环境。离线算法测试不需要歌曲和硬件。
2. 可选：从 Release 下载 fingerprints.zip 并放到 data/library，然后用 Python 运行 `data/restore_library.py data/library/fingerprints.zip` 恢复随包库，或者通过界面录入自己的原版录音。此操作不覆盖已存在的库。
3. 用 Python 运行 `build/verify_project.py`，核对 54 个输入、镜像摘要、归档日志、资源时序报告和已包含的最终材料；缺失的视频及压缩曲库会明确标为可选附件。
4. 执行 `python -m unittest discover -s src/pc -p selftest.py -v` 和 `python -m unittest discover -s sim/host_tests -v`，分别检查生产电脑模块和交付校验器。新电脑测试结果写入 `sim/results/current_pc/`。
5. 执行 `build/build.ps1 -Mode simulate -VivadoExe <本机的vivado.bat绝对路径>`，从脚本创建工程和 FFT、ILA IP，运行全部 21 个 RTL 测试平台。仿真不访问开发板。过程中的顶层显示仿真耗时较长；以日志中的 PASS 和 CHECKS_COMPLETE 为准。
6. 全部仿真结束后执行下列参考对比：

```powershell
python sim/tools/fft_reference_check.py
python sim/tools/verify_serial_capture.py
python sim/tools/verify_lcd_frame.py
```

这些脚本读取本次 `build/current/` 的 FFT CSV、UART HEX 与 LCD PPM，缺失输入会失败。要求 FFT bin 16、64，FFT 相对 L2 误差小于 0.001；UART 每个采样匹配、CRC 为零；LCD 1024×600，指定柱的位置、颜色和面积一致。

7. 需要新综合实现时执行 `build/build.ps1 -Mode all`，随后运行：

```powershell
python skill/fpga-audio-reproduce/scripts/check_reports.py --root . --config build/config/current_report_checks.json
```

创建工程、仿真、综合、实现也可分别使用 create、simulate、synth、implement、bitstream。脚本临时映射空闲 R 盘，盘符冲突时用 `-Drive Q`；只移除本次创建且仍指向工程的映射。

生成 `.xpr` 在 `board/vivado/`，新综合实现报告与仿真原始输出在 `build/current/`，新 bit、ltx 在 `board/output/`。归档实现报告保存在 `build/reports/`，历史仿真与复现记录在 `sim/results/`；二者不被新构建覆盖。

8. 上板前逐条核对 `board/hardware.md`，再明确选择归档镜像或新镜像下载。下载器要求唯一 XC7Z010，核对 DONE、CRC、USR_ACCESS；没有自动 Flash 编程步骤。电脑识曲程序在点击连接后才占用串口。
9. 按当前验收 JSON，分别记录已知、库外、换歌、停声、模式切换、断连恢复、音乐灯效和 30 分钟连续运行。

重新布局布线的 bit 可能因工具执行条件变化而不逐字节相同；重建成功以功能、参考对比、器件与约束、资源时序为判据。归档 bit 的 SHA256 用来确认所用镜像身份。

歌曲原音频、MIC 实录及完整数字录音矩阵输入不随本包分发。历史 155 个用例和基于同一诊断录音的回放结果仅作为既有证据；陌生团队可使用自己的录音重建测试集。当前结构与最终 PDF 中旧目录对照的关系见 `report/directory_map.md`。
