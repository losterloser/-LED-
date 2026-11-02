# GitHub 提交

本目录是仓库根目录：README.md、.gitignore、.gitattributes 与 src、sim、build、board、data、skill、report 同级。

可通过 GitHub Desktop 或 Git 命令提交目录内容。本项目使用 main 分支，远端为 https://github.com/losterloser/-LED-.git。不要将外层 github_ready 目录、Git 内部 .git 目录或本地交付 RAR 当作源码文件上传。

源码版排除了 demo.mp4 和 fingerprints.zip。发布时在 Release 中另附这两项；可选再附正式代码 RAR。各附件摘要保留在 report/provenance/materials.json，源码检查允许这两项暂缺，并明确显示该状态；--check-library 仍要求实际指纹附件存在。

GitHub 网页单文件上限 25 MiB、每批最多 100 文件。源码版单文件均小于此限制；总文件数超过单批上限，网页上传需分批。GitHub Desktop 或 Git 可保留隐藏配置和目录结构。普通 Git 仓库阻止超过 100 MiB 的单文件，视频应走 Release。

官方依据：https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
网页上传依据：https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository

源码、报告与重检证据保存在本仓库；视频、派生指纹库和源码报告 RAR 保存在 local-v0.3.2 Release。
