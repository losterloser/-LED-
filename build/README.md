# 构建与综合实现

统一入口 build.ps1 支持 create、simulate、synth、implement、bitstream、all，使用相对路径创建工程及 FFT/ILA IP。示例见根 README。归档报告在 reports，新构建报告在 current，生成 .xpr 和输出分别在 board/vivado 与 board/output。

compiled_inputs.json 的 54 个条目将 RTL、测试平台、参考数据和 XDC 与归档实现联系。资源和时序指标来自已有报告；本次目录迁移没有重新布局布线。config/report_checks.json 检查随包报告，config/current_report_checks.json 检查新结果。verify_project.py 检查结构、摘要和证据完整性，不执行下载或识曲。
