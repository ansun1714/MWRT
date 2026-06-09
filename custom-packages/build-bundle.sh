#!/bin/bash
# 把多个 IPK 合并成一个 Bundle IPK
# 用法：bash build-bundle.sh <版本> <架构> <IPK目录> <输出目录>

set -euo pipefail

BUNDLE_VERSION="${1:-1.0.0}"
BUNDLE_ARCH="${2:-aarch64_cortex-a53}"
IPK_DIR="${3:-built-ipks}"
OUTPUT_DIR="${4:-$(pwd)}"
BUNDLE_NAME="iptv-manager-bundle"

BUILD_DIR="$(mktemp -d)"
DATA_DIR="$BUILD_DIR/data"
CTRL_DIR="$BUILD_DIR/control"
mkdir -p "$DATA_DIR" "$CTRL_DIR"

echo ">>> 合并 IPK 文件..."

POSTINST_PARTS="$BUILD_DIR/postinst_parts"
touch "$POSTINST_PARTS"

for ipk in "$IPK_DIR"/*.ipk; do
    echo "  提取: $(basename "$ipk")"
    tmpdir="$(mktemp -d)"
    tar xzf "$ipk" -C "$tmpdir" 2>/dev/null || true

    # 合并 data 文件
    [ -f "$tmpdir/data.tar.gz" ] && tar xzf "$tmpdir/data.tar.gz" -C "$DATA_DIR"

    # 收集各包的 postinst 内容（去掉 shebang、IPKG_INSTROOT 检查和 exit）
    if [ -f "$tmpdir/control.tar.gz" ]; then
        ctrldir="$(mktemp -d)"
        tar xzf "$tmpdir/control.tar.gz" -C "$ctrldir"
        if [ -f "$ctrldir/postinst" ]; then
            grep -v '^#!' "$ctrldir/postinst" \
            | grep -v 'IPKG_INSTROOT' \
            | grep -v '^exit' \
            | grep -v '^[[:space:]]*$' \
            >> "$POSTINST_PARTS" || true
            echo "" >> "$POSTINST_PARTS"
        fi
        rm -rf "$ctrldir"
    fi

    rm -rf "$tmpdir"
done

# ── 计算大小 ──────────────────────────────────────────────────

SIZE_KB=$(du -sk "$DATA_DIR" | awk '{print $1}')

# ── control ────────────────────────────────────────────────────

cat > "$CTRL_DIR/control" << EOF
Package: $BUNDLE_NAME
Version: ${BUNDLE_VERSION}-1
Architecture: $BUNDLE_ARCH
Installed-Size: $SIZE_KB
Depends: luci-base
Section: net
Priority: optional
Maintainer: ansun1714
Description: IPTV Manager Bundle (msd_lite + rtp2httpd + LuCI)
 一键安装包，含 msd_lite、rtp2httpd 主程序及 LuCI 管理界面。
 引用的开源项目：
  msd_lite:   https://github.com/ximiTech/msd_lite
  rtp2httpd:  https://github.com/stackia/rtp2httpd
EOF

# ── conffiles（升级时保留用户配置）────────────────────────────

cat > "$CTRL_DIR/conffiles" << 'EOF'
/etc/config/iptv_manager
/etc/config/msd_lite
/etc/config/rtp2httpd
EOF

# ── 合并 postinst ──────────────────────────────────────────────

{
    echo '#!/bin/sh'
    echo '[ -n "${IPKG_INSTROOT}" ] && exit 0'
    cat "$POSTINST_PARTS"
    echo 'rm -rf /tmp/luci-indexcache'
    echo 'exit 0'
} > "$CTRL_DIR/postinst"
chmod +x "$CTRL_DIR/postinst"

# ── prerm ──────────────────────────────────────────────────────

cat > "$CTRL_DIR/prerm" << 'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/iptv_manager stop 2>/dev/null || true
rm -rf /tmp/luci-indexcache
exit 0
EOF
chmod +x "$CTRL_DIR/prerm"

# ── 打包 ───────────────────────────────────────────────────────

( cd "$DATA_DIR"  && tar czf "$BUILD_DIR/data.tar.gz"    . )
( cd "$CTRL_DIR"  && tar czf "$BUILD_DIR/control.tar.gz" . )
echo "2.0" > "$BUILD_DIR/debian-binary"

IPK_NAME="${BUNDLE_NAME}_${BUNDLE_VERSION}_${BUNDLE_ARCH}.ipk"
( cd "$BUILD_DIR" && tar czf "$OUTPUT_DIR/$IPK_NAME" \
    debian-binary control.tar.gz data.tar.gz )

rm -rf "$BUILD_DIR"

echo "✅ Bundle IPK：$OUTPUT_DIR/$IPK_NAME"
ls -lh "$OUTPUT_DIR/$IPK_NAME"
