# OnePlus 5 / 5T SailFish OS fastboot 刷机包 (CI)

从根文件系统快照自动重建 OnePlus 5T (dumpling) / OnePlus 5 (cheeseburger) 的
SailFish OS 5.3.0.10 fastboot 刷机包，并通过 GitHub Actions 发布到 Releases。

## 下载刷机包

到 [Releases](../../releases) 下载对应机型：

| 文件 | 说明 |
| --- | --- |
| `boot.img` | 引导镜像（5/5T 通用，内核内嵌全部 8 个 DTB） |
| `userdata.img.gz.part-*` | 系统镜像分片（合并解压后 8GiB） |
| `flash.sh` | 一键刷机（合并分片→校验→解压→fastboot 刷入） |
| `join-and-verify.sh` | 只合并分片+校验+解压 |
| `SHA256SUMS` | 校验和 |
| `README-刷机说明.md` | 详细说明 |

刷机（Linux/macOS，需已安装 fastboot / android-tools）：

```sh
sh flash.sh
```

或手动：

```sh
sh join-and-verify.sh
fastboot flash boot boot.img
fastboot -S 256M flash userdata userdata.img
fastboot reboot
```

注意：
- 前置：手机已刷 OOS 10.0.1 firmware 底包
- 切勿执行 `fastboot format userdata`（会清掉刚写入的系统）
- 首次开机较慢：会自动扩展 userdata 并进入初始设置向导

## 仓库结构

```
.github/workflows/
  fastboot-dumpling.yml       # 5T：快照重建 + 发布
  fastboot-cheeseburger.yml   # 一加5：快照 + LOS vendor 重建 + 发布
fastboot/
  build-userdata.sh           # 重建 userdata.img（mkfs+解包+清扫+补丁+设备换装）
  patch-wizard.py             # 向导 QML 补丁（以后新修复都加在这里）
  make-cheeseburger.sh        # 一加5 换装（vendor.img + 设备标识 + ssu 映射）
  fetch-vendor-cheeseburger.sh# 从公开 LOS 20 包提取一加5 vendor.img
  make-package.sh             # gzip + 分片 + SHA256SUMS + README
  flash.sh.tmpl               # 刷机脚本模板（按机型生成）
  join-and-verify.sh          # 下载者合并/校验/解压脚本
boot/boot.img                 # 5/5T 通用引导镜像（内嵌全部 8 个 DTB）
sources/SOURCES.md            # 快照资产说明（名称 + sha256）
```

## CI 工作方式

1. `sources-*` Release 存放**清洗过的根文件系统快照**
   （`rootfs-snapshot-clean-5.3.0.10.tar.gz`，见 `sources/SOURCES.md`）
2. Actions → `Build dumpling fastboot package` / `Build cheeseburger fastboot package`
   → Run workflow
3. CI 下载快照 → 重建 8GiB 镜像 → 应用补丁 + 个人数据清扫 + 设备换装
   → gzip + 分片（<2GiB/文件）→ 自动创建 Release

首次使用请在仓库 Settings → Actions → General → Workflow permissions
选择 **Read and write permissions**（否则创建 Release 会 403）。

## 维护流程

1. 修改 `fastboot/` 下的脚本/补丁并提交推送
2. Actions 里重新运行对应 workflow（同名 tag 会自动覆盖更新资产）
3. 若要更换基础快照：把新快照作为资产上传到新的 `sources-*` Release，
   更新 `sources/SOURCES.md` 和对应 workflow 里 `snapshot_sha256` 的默认值

## 本地构建（与 CI 相同）

```sh
# 一加5 需要先取 vendor.img（下载 LOS 20 包并校验）
bash fastboot/fetch-vendor-cheeseburger.sh dist/vendor.img

sudo bash fastboot/build-userdata.sh dumpling     dist/rootfs-snapshot-clean-5.3.0.10.tar.gz dist
sudo bash fastboot/build-userdata.sh cheeseburger dist/rootfs-snapshot-clean-5.3.0.10.tar.gz dist dist/vendor.img

sudo bash fastboot/make-package.sh dumpling dist dist/pkg-dumpling
```

## 已知问题（本移植）

- 向导中的教程步骤已绕过（教程入口页在本移植上卡住）；向导指纹步骤已修复
  （进入指纹设置时会要求重新输入锁屏码，然后正常录入）
- WebGL 不可用；B 站等网页视频可能跳 "cannot open link"（可将浏览器 UA 设为桌面版）
- 镜像已清除个人数据（用户文件/账号/WiFi/锁屏码/日志），
  machine-id 与 SSH 主机密钥在每次构建时重新生成

## License

本仓库脚本为 MIT。生成的镜像包含 SailFish OS（Jolla 许可条款）与
LineageOS vendor 组件，再分发请遵守相应许可。
