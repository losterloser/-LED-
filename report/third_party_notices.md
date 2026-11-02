# 第三方组件与资料说明

- FPGA 工具和 IP：Vivado 2022.2、AMD/Xilinx FFT 9.1、ILA 6.2 及 7 系列原语。仓库提供创建配置与调用代码，不分发 Vivado 安装文件、预编译工具库或 vendor IP 生成源码。
- Python 依赖：NumPy、SciPy、Pillow、pyserial、SoundFile 与 Mutagen，具体版本见 `src/pc/requirements.txt`。依赖通过各自包管理渠道安装，不把本机虚拟环境提交到仓库。
- 音频指纹思想来源说明见 `src/pc/songid.py`；本工程实现为小规模本地原录音识别原型，没有接入第三方在线曲库。
- 板卡、ES8388 与屏幕的引脚和初始化依据用户提供的配套资料核对。仓库不重新分发完整厂商资料盘。
- `data/tone_*.wav` 是人工合成测试音。用户原始歌曲、MIC 实录、账号信息及截图中的接口凭证均不随源码包发布。
