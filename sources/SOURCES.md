# Sources（大文件资产）

CI 构建所需的根文件系统快照存放在本仓库的 GitHub Releases 里
（不进 git：单文件 100MiB 限制；Release 单文件上限 2GiB）。

## sources-5.3.0.10

| 资产 | 文件 | sha256 |
| --- | --- | --- |
| 根文件系统快照（已清洗个人数据） | `rootfs-snapshot-clean-5.3.0.10.tar.gz` | `81a9e2e32786f476e178eefe9071d592c4c3026dc4a18529f062d80b0f2f9ffd` |

快照内容：SFOS 5.3.0.10 + 全部移植修复的设备根文件系统（`halium-rootfs/`）。
上传前已清除：用户文件 / Jolla 账号 / Wi-Fi 凭据 / 锁屏码 / 应用数据 /
登录记录(wtmp,lastlog,btmp) / journal / 安装器日志 / 树莓缓存；
SSH 主机密钥已删除（CI 每次构建重新生成）；
machine-id 已清空（CI 每次构建随机生成）；
`/etc/ssu/ssu.ini` 商店凭据已清空。

一加5 的 `vendor.img`（约 1GiB）不在快照里由 CI 现取：
`fastboot/fetch-vendor-cheeseburger.sh` 从公开的
`lineage-20.0-20240129-nightly-cheeseburger-signed.zip`
（b4.timschumi.net）下载并校验（zip sha256 与 vendor.img sha256 均已锁定）。

## 上传（一次性）

```sh
# 需要 gh (github.com/cli/cli) 并已登录
gh release create sources-5.3.0.10 \
  --repo gmicroul/oneplus5-sfos-fastboot \
  --title "Sources: rootfs snapshot 5.3.0.10" \
  --notes "cleaned rootfs snapshot for fastboot package builds (see sources/SOURCES.md)" \
  dist/rootfs-snapshot-clean-5.3.0.10.tar.gz
```

## 更换快照

1. 上传新的 `sources-*` Release（新快照文件）
2. 更新本文件里的 sha256
3. 更新 `.github/workflows/fastboot-*.yml` 里 `snapshot_sha256` 的默认值
