# 目录迁移与版本说明

最终 PDF 是用户指定的定稿，按原字节保存；其中表 19 记载的是报告成稿时的工程目录映射。实际交付目录随后依照推荐结构调整，本文件给出准确入口，不修改定稿内容。

| 旧目录 | 当前目录 |
| --- | --- |
| src | src/rtl |
| pc | src/pc |
| constraints | src/constraints |
| sim | sim/tb |
| scripts 中构建脚本 | build |
| scripts 中参考对比 | sim/tools |
| scripts/jtag_device.tcl | board/jtag_device.tcl |
| scripts/restore_library.py | data/restore_library.py |
| artifacts | board/artifacts |
| evidence/simulation | sim/results/archived_rtl |
| evidence/pc | sim/results/archived_pc |
| evidence/reproduction | sim/results/previous_reproduction |
| evidence/implementation | build/reports |
| evidence/hardware | board/results |
| song_library | data/library |
| docs | report/docs；接线说明为 board/hardware.md |
| tests | sim/host_tests |
| config | build/config |

本次保持 local-v0.3.2 的识别规则与算法不变。仅修改路径、日志目录、复现命令和交付索引。RTL、测试平台、XDC 与参考数据共 54 个条目的摘要保存在 build/compiled_inputs.json。完整逐文件迁移与改动摘要在 report/provenance/relocation_manifest.json。

旧仿真日志、综合实现报告、回放 JSON、现场结果保留原字节，内部出现的旧路径是证据发生时的记录；不要将这些历史路径当作当前执行命令。新的构建与主机运行结果使用 README 所列目录。旧复现记录中的 21 项仿真不冒充本次重跑；本次重检日志单独放在 sim/results/current_delivery。

最终报告、最终视频、海报、派生曲库的摘要见 report/provenance/materials.json。原始工程、旧版交付、原报告和其他聊天的 GitHub 材料均保留。本次没有上传、播放、串口操作、JTAG 下载或 Flash 编程。


GitHub 源码版本补充：视频和压缩指纹库作为可选 Release 附件，未内嵌仓库；本机完整交付 RAR 和原技术资料保持原样。
