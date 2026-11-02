# 测试数据与指纹库

根目录 MEM 为 FPGA 仿真输入和定点参考；tone WAV 为人工合成的 750 Hz、3000 Hz 与双音。库标签与指纹目录为 library，库内 16 首、11 位歌手；不包含原始音乐。

先从 Release 下载 fingerprints.zip 放到 data/library；也可跳过附件并通过界面自行录入歌曲。从项目根目录执行 `python data/restore_library.py data/library/fingerprints.zip`，按 catalog.json 校验原库字节、SHA256、SQLite 完整性和曲目数后恢复到 src/pc/library.sqlite3。已有库不会覆盖。解压库约 184.7 MB，压缩附件约 60.5 MB；不需将压缩库提交到普通 Git 源码目录。

历史参考矩阵在 sim/results/archived_pc/historical_155_cases，实物 LINE IN 输出在 board/results，数值参考脚本在 sim/tools。《夜曲》排除，三首 holdout 不在库中。数值/录音回放与当前实物验收分别记录。
