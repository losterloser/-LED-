# 提交要求对应表

本表依据用户给出的推荐目录与 3.3.5 提交要求截图整理，只列实际采用的 RTL 和电脑 Python。

| 要求 | 当前材料 | 核验方法与边界 |
| --- | --- | --- |
| 3.3.5.1 完整源码与工程 | src/rtl、src/pc、src/constraints、build/create_project.tcl | 由配置脚本重新创建 .xpr、FFT 和 ILA IP，不依赖原机缓存 |
| 仿真或验证结果 | sim/tb、sim/results、report/docs/validation.md | 21 项 RTL、33 组电脑回归；数字参考和实物结果分开 |
| 综合与实现报告 | build/reports、report/docs/performance.md | 资源、时钟、setup、hold、CDC、DRC、总线偏斜；本次未重新实现 |
| 上板工程及运行脚本 | board/artifacts、board/jtag_device.tcl、src/pc/start.cmd、board/hardware.md | SHA256、器件和 USR_ACCESS 共同确认镜像，不写 Flash |
| 实测与参考对比 | sim/tools、sim/results、board/results/line_known_matrix.json、line_unknown_matrix.json | FFT 对 NumPy、UART 逐采样、LCD 像素，以及历史真实 LINE IN 结果 |
| 可复现构建脚本 | build/build.ps1、build/run_checks.tcl、report/docs/reproduce.md | 在新目录重建和验证；工具安装由复现者提供 |
| 3.3.5.2 技能包说明 | skill/README.md、skill/fpga-audio-reproduce/README.md | 场景、方法、失效条件、经验来源和验证效果 |
| 提示词工作流 | skill/fpga-audio-reproduce/references/prompts.md | 需求划分、接口核对、指标定位与证据归档 |
| 案例模板 | skill/fpga-audio-reproduce/assets | 报告预算和验收 JSON 模板 |
| 可复用校验脚本 | skill/fpga-audio-reproduce/scripts/check_reports.py、sim/host_tests | 检查时序和资源，验证缺失报告及负余量等应失败情形 |
| 踩坑清单 | skill/fpga-audio-reproduce/references/pitfalls.md | 引脚冲突、BRAM 推断、长路径、声道和 MIC 跟踪 |
| 3.3.5.3 设计报告 | report/design_report.pdf、design_report.docx | 用户指定最终版，31 页；背景、原理、接口、优化、复现及待测指标 |
| 大模型协作记录 | report/collaboration.md、最终报告 4.3 节 | 可追溯技术提示和回应摘要，不伪造逐字历史或模型型号 |
| 技能包提炼过程 | 最终报告 4.4 节、skill/README.md | 失败与观察、提炼规则、验证及边界对应 |
| 视频与海报 | report/media/demo.mp4、report/poster | 已制作材料；演示视频独立提交，不放入代码 RAR |

没有采用 PYNQ，不声明通用 PYNQ Skill 加分。尚未提供签署授权书，本整理不生成代签材料。当前实物验收以 board/results/acceptance.json 为准；视频完成不改变稳定性验收项。


GitHub 源码版本补充：视频和压缩指纹库作为可选 Release 附件，未内嵌仓库；本机完整交付 RAR 和原技术资料保持原样。
