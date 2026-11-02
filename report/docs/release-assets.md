# 曲库附件

可选 Release 附件 fingerprints.zip（下载后放到 data/library/fingerprints.zip） 是 16 首、11 位歌手的派生指纹库，不包含原始歌曲。catalog.json 保存库字节数、SHA256、曲目数与标签。恢复命令为 `python data/restore_library.py data/library/fingerprints.zip`，默认恢复到 src/pc/library.sqlite3；已有目标不会覆盖。

源音频、holdout 与排除音频保留在用户原目录，不复制入交付。若使用新录音版本，应自行录入并重建验收集，不把既有结果外推为任意歌曲准确率。
