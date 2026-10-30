#!/bin/sh
# 合并 userdata.img.gz 分片 → 校验 → 解压
# 用法: 在本目录执行 sh join-and-verify.sh
set -e

if [ ! -f userdata.img.gz ]; then
    echo "== 合并分片 =="
    cat userdata.img.gz.part-* > userdata.img.gz
fi

echo "== 校验 =="
sha256sum -c SHA256SUMS --ignore-missing

if [ ! -f userdata.img ]; then
    echo "== 解压 =="
    gunzip -kf userdata.img.gz
fi

echo "完成: userdata.img ($(du -h userdata.img | cut -f1))"
