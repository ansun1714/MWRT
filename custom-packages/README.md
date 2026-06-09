# custom-packages

固件自定义软件包目录，编译时自动复制进 LEDE 源码的 `package/` 目录。

## 目录结构
custom-packages/
└── luci-app-iptv-manager/   # IPTV 管理器（msd_lite / rtp2HTTPd 二合一界面）
## 说明

- msd_lite 主程序：由 diy-part1.sh 直接 git clone 到 package/msd_lite
- rtp2httpd 主程序：由 diy-part1.sh 通过 feeds 引入
- luci-app-iptv-manager：本目录提供，统一管理界面

## 在 .config 中启用
CONFIG_PACKAGE_msd_lite=y
CONFIG_PACKAGE_rtp2httpd=y
CONFIG_PACKAGE_luci-app-iptv-manager=y
