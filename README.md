# cfy
CFY - 节点优选生成器 (混合版)
这是一个基于 Bash 编写的轻量级 VMess 节点处理工具。它能读取你的原始节点，并将其批量替换为速度更快、延迟更低的优选 IP。

✨ 核心亮点：支持“本地实测数据”与“云端公共数据”双模式切换。

🚀 功能特性
一键安装: 脚本内置自我安装程序，运行一次后自动部署为系统命令 cfy，支持任意目录调用。

双模驱动:

本地测速模式 (推荐): 自动读取 CloudflareSpeedTest 生成的 result.csv 文件，提取你自己网络环境下实测最快的 IP。

云端优选模式 (懒人): 自动爬取第三方 (wetest.vip) 维护的公共优选 IP 库，包含移动/联通/电信优化线路。

智能路径识别: 自动寻找 /root/cfst 目录下的测速结果，也支持在当前目录下运行。

自定义数量: 用户可自由输入想要生成的节点数量（例如前 5 个或前 20 个）。

智能命名:

模式1: 自动在节点后备注 -优选[IP地址]-[延迟ms]，一眼看出谁最快。

模式2: 自动备注 -优选[运营商]（如优选移动）。

无损转换: 完美保留原节点的 UUID、路径、TLS 等所有配置，仅替换 IP 地址。

🛠️ 依赖要求
在运行脚本之前，请确保系统中安装了以下工具（脚本会尝试自动安装 jq）：

jq: 处理 JSON 数据的核心工具（必须）。

curl: 用于爬取云端数据。

awk / sed / grep: 文本处理标准工具。

CloudflareSpeedTest: (仅模式1需要) 你需要先运行测速工具生成 result.csv。

Debian / Ubuntu 手动安装依赖:

Bash
apt update && apt install -y jq curl
📥 一键安装与运行
方式 1：复制粘贴安装 (推荐)
直接复制下方代码在终端运行，即可完成安装并立即启动：

Bash
bash <(curl -sL https://gist.githubusercontent.com/dgag-kj
cfy/main/cfy.sh)
(注：请将上面的链接替换为你上传脚本后的真实 Raw 链接)

方式 2：手动安装
如果你已经把脚本保存为 cfy.sh，直接运行：

Bash
chmod +x cfy.sh && ./cfy.sh
🚀 如何使用
安装成功后，你在任何目录下输入以下命令即可启动：

Bash
cfy
操作流程示例：

(可选) 先运行 ./CloudflareST 跑一遍测速。

输入 cfy 启动脚本。

粘贴你的 VMess 链接。

选择 1 (本地测速结果) 或 2 (云端公共优选)。

输入生成数量 (例如 10)。

复制生成的链接导入软件即可。

🔄 更新与卸载
更新脚本: 重新运行一遍“一键安装”命令即可覆盖旧版本。

卸载脚本: 只需删除系统路径下的文件：

Bash
sudo rm /usr/local/bin/cfy
📝 常见问题
Q: 为什么选择模式 1 提示找不到 result.csv？ A: 模式 1 依赖本地测速文件。请确保你已经安装了 CloudflareSpeedTest 并在 /root/cfst 或当前目录下运行过测速。

Q: 生成的节点可以导入哪些软件？ A: 支持所有兼容 V2Ray (VMess) 格式的软件，如 v2rayN, Clash (需转换), Shadowrocket (小火箭), v2rayNG 等。
