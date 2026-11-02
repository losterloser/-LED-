# 仿真与验证

tb 包含 21 个 RTL 测试平台和 I2C 辅助模型。用 build/build.ps1 -Mode simulate 运行全套，PASS、FATAL 和仿真输出均由脚本核对。tools 包含 FFT 数值、UART 每采样及 LCD 像素参考对比；完整仿真结束后再运行这些依赖脚本。

results/archived_rtl、archived_pc 是原始归档结果；results/previous_reproduction 是前一次干净目录复现。results/current_delivery 为本次整理后的独立重检，不能将历史日志当作本次重跑。host_tests 验证交付脚本的正确行为与应该失败的情形。
