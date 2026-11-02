# 音乐频谱可视化与 LED 灯效同步

正点原子领航者 ATK-DF7010/7020P V3.9，XC7Z010CLG400-1，Vivado 2022.2，电脑辅助本地识曲 local-v0.3.2。板载 ES8388 采音，PL 完成 1024 点 FFT、16 段频谱、1024×600 RGB LCD 和 16 灯 WS2812B 驱动；电脑接收 12 kHz PCM，匹配本地曲库，回传中文歌名和演唱者。

本目录于 2026-11-02 从“方案2”“写报告”聊天和最终提交资料整理。保留最终报告原始字节，未连接串口、JTAG，未重新进行实物验收。本工程使用 RTL 和电脑 Python，没有采用 HLS、PS 应用、PYNQ 或云端识曲接口。

## 目录

```text
navigator7010_audio_visualizer/
├── README.md
├── src/
│   ├── rtl/                     Verilog 设计源码
│   ├── constraints/             板级引脚与时钟约束
│   └── pc/                      电脑识曲界面、协议、匹配与回归
├── sim/
│   ├── tb/                      21 个 RTL 测试平台及辅助模型
│   ├── tools/                   FFT、UART、LCD 输出参考对比
│   ├── host_tests/              曲库恢复与报告校验测试
│   └── results/                 已保存仿真、软件回归与复现记录
├── build/
│   ├── build.ps1                构建统一入口
│   ├── create_project.tcl       创建工程与 FFT、ILA IP
│   ├── run_checks.tcl           仿真、综合、实现及输出
│   ├── verify_project.py        目录、摘要、证据与材料检查
│   ├── config/                 随包报告与新构建报告检查配置
│   └── reports/                已有综合实现与资源时序报告
├── board/
│   ├── artifacts/              已上板 bit、ltx 和文件摘要
│   ├── jtag_device.tcl          链路检测与易失 JTAG 下载
│   ├── hardware.md             精确接线、按键、验收与断电
│   └── results/                现场矩阵、JTAG、UART 与验收状态
├── data/
│   ├── *.mem                   定点参考向量与仿真输入
│   ├── tone_*.wav              人工合成测试音
│   ├── restore_library.py      校验并恢复指纹库
│   └── library/                16 首曲目标签和压缩指纹库
├── skill/
│   ├── README.md               复用入口、范围、方法与失效条件
│   └── fpga-audio-reproduce/   SKILL.md、校验器、提示词与模板
└── report/
    ├── design_report.pdf       用户指定的最终 31 页报告
    ├── design_report.docx      对应的可编辑修订稿
    ├── requirements_map.md     3.3.5.1、3.3.5.2、3.3.5.3 材料索引
    ├── directory_map.md        旧目录到本次目录的迁移说明
    ├── collaboration.md        大模型协作与纠错记录摘要
    ├── docs/                   架构、指标、验证与复现说明
    ├── provenance/             同步来源、材料摘要与迁移清单
    ├── poster/                 中文、英文两页海报 PDF 和 PPTX
    └── media/                  最终演示视频和实际配音文案
```

文件名使用英文、数字、下划线或连字符。扩展名保留句点；按截图入口示例保留 `README.md`，可安装技能入口保留 `SKILL.md`，Git 配置保留 `.gitignore` 和 `.gitattributes`。中文仅位于内容中。

## GitHub 源码版与附件

本目录可作为 GitHub 仓库根目录，已保留七个推荐目录和本次重检证据。源码版不含视频与压缩指纹库，最大单文件约 5.74 MB；完整技术资料及代码 RAR 仍在本机交付目录。

首次使用有两种路径：直接在界面录入自己的原版录音，或者先从仓库的 Release 下载 `fingerprints.zip`，放到 `data/library/fingerprints.zip`，再执行下列恢复命令。`demo.mp4` 与可选代码 RAR 也作为 Release 附件分发。附件通过本仓库的 local-v0.3.2 Release 分发；未录入自己的歌曲时可选择恢复附带的派生指纹库。

不下载附件也能运行默认源码检查、33 组电脑回归与 21 项 RTL 仿真；检查结果会明确列出未包含的可选附件。`--check-library` 用于附件到位后的额外指纹完整性检查。

## 运行电脑识曲

从本目录根路径打开 PowerShell。准备 Python 3.12，修改下面的 Python 路径为本机位置：

```powershell
.\src\pc\setup.ps1 -PythonPath "C:\Python312\python.exe"
# 先从 Release 下载指纹附件；若选择自行录入歌曲，则跳过这一行。
.\src\pc\.venv\Scripts\python.exe data/restore_library.py data/library/fingerprints.zip
.\src\pc\start.cmd
```

恢复前先关闭识曲程序；目标 `src/pc/library.sqlite3` 已存在时脚本会停止，保留已有库。也可以不恢复，直接从界面录入自己的原版录音。压缩附件只有派生指纹和标签，含 16 首、11 位歌手，不含原始歌曲音频；三首库外测试歌及《夜曲》均不在库中。运行识曲需要电脑参与，不将曲库烧入 FPGA。

按 [接线与验收](board/hardware.md) 接好 USB UART 和 P5，界面选择实际 CH340 串口，点击“连接开发板”。不要根据历史记录假定当前仍为 COM4。PL_KEY0 依次切换 ROM、MIC、LINE；ROM 是测试模式。PL_KEY1 切换屏幕彩条和逐灯自检。

## 复现与验证

```powershell
# 离线检查，不接触开发板。
python build/verify_project.py
python -m unittest discover -s src/pc -p selftest.py -v
python -m unittest discover -s sim/host_tests -v
python skill/fpga-audio-reproduce/scripts/check_reports.py --root . --config build/config/report_checks.json

# 只创建工程与 IP。
.\build\build.ps1 -Mode create -VivadoExe "D:\hyit\Vivado\2022.2\bin\vivado.bat"

# 全部 21 项仿真。
.\build\build.ps1 -Mode simulate -VivadoExe "D:\hyit\Vivado\2022.2\bin\vivado.bat"

# 从源码完整构建。
.\build\build.ps1 -Mode all -VivadoExe "D:\hyit\Vivado\2022.2\bin\vivado.bat"
```

上例 `python` 指装好依赖的 Python 3.12，可替换为 `src/pc/.venv/Scripts/python.exe`。Vivado 路径按本机修改。构建通过临时空闲 R 盘缩短路径；已有 R 盘时传 `-Drive Q`。生成工程位于 `board/vivado/`，新报告位于 `build/current/`，新镜像位于 `board/output/`；随包历史证据不会被构建覆盖。

54 个随包 FPGA 输入与已有构建证据的摘要逐一对应，RTL、测试平台、约束和参考数据保持原字节。目录整理只调整构建、导航和日志输出路径。原实现 WNS +0.379 ns、WHS +0.025 ns；LUT 7232、FF 10560、BRAM Tile 23、DSP 7。没有将目录整理描述为重新布局布线。

完整复现说明见 [reproduce.md](report/docs/reproduce.md)，数值参考见 [validation.md](report/docs/validation.md)，指标见 [performance.md](report/docs/performance.md)。

## 上板与当前验收边界

[board/hardware.md](board/hardware.md) 包含接线、下载、操作与安全断电。随包镜像 USR_ACCESS 为 `0x4E375231`，下载脚本仅写易失 PL 配置，不写 Flash。

已保存 21 项 RTL 仿真、33 组电脑回归、7 项显示回放、11 项 MIC 取得身份和拒识检查，以及历史 155 个指定离线用例。历史 LINE IN 实测覆盖 5 首、15 个片段。当前 LINE IN 和 MIC 采集、LCD 彩条与灯环逐灯自检有用户确认。持续识曲、换歌与停声恢复、当前音乐灯效和 30 分钟整机稳定性仍分别待验收，见 [acceptance.json](board/results/acceptance.json)。视频已制作完成，视频剪辑不代替连续稳定性测试。

## 最终材料

- [最终设计报告](report/design_report.pdf)：按用户指定文件直接复制，未改正文；对应 Word 稿同时保留。
- 最终演示视频 `demo.mp4`：作为独立 Release 附件，H.264，175.08 秒，约 284.4 MB；从高码率配音成片制作兼容副本，原音轨保持。
- [双语海报 PDF](report/poster/poster_bilingual.pdf) 与 [可编辑 PPTX](report/poster/poster_bilingual.pptx)：保留用户在其他聊天明确要求的署名。
- [协作记录](report/collaboration.md)、[要求索引](report/requirements_map.md)、[整理来源与摘要](report/provenance/materials.json)。

本机完整交付目录另有代码 RAR；源码仓库不内嵌此压缩包。该 RAR 不包含演示视频、虚拟环境、数据库解压文件和构建缓存。完整本机整理目录保留视频。普通 Git 提交忽略视频和压缩曲库，曲库可作为独立附件；仓库地址为 https://github.com/losterloser/-LED-。第三方 IP 与素材边界见 [third_party_notices.md](report/third_party_notices.md)。


## 发布附件下载

- [源码与最终报告 RAR](https://github.com/losterloser/-LED-/releases/download/local-v0.3.2/github_source_with_report_20261102.rar)
- [16 首歌曲的派生指纹库](https://github.com/losterloser/-LED-/releases/download/local-v0.3.2/fingerprints.zip)：下载后放到 data/library/fingerprints.zip；不含原始歌曲。
- [H.264 演示视频](https://github.com/losterloser/-LED-/releases/download/local-v0.3.2/demo.mp4)：175.08 秒，284.4 MB。

仓库根目录直接提供源码、报告、双语海报、技能包及重检证据。Release 附件与源码分开下载；已入库原版录音、当前实物持续识曲及长时稳定性的边界见 board/results/acceptance.json。
