#!/usr/bin/env bash
# btwtemplates 模板打包脚本 (CI 用)
# 扫描 templates/ 目录，从 template.json 读取版本，打包 zip，输出 template-index.json
#
# 用法: bash scripts/pack.sh
# 环境要求: jq, zip
#
# 版本信息单一来源: templates/{id}/template.json 的 version 字段
# 不再需要 versions.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_DIR/templates"
OUTPUT_DIR="$REPO_DIR/releases"
INDEX_PATH="$REPO_DIR/template-index.json"

REPO="${GITHUB_REPOSITORY:-raojm/btwtemplates}"

# 下载 URL 基础路径 — 根据平台环境变量自动选择
# 支持: GITHUB / GITEE / GITLAB / ALIYUN
PLATFORM="${BTWTEMPLATES_PLATFORM:-GITHUB}"

if [ "$PLATFORM" = "GITEE" ]; then
    GITEE_REPO="${GITEE_REPO:-raojm/btwtemplates}"
    DOWNLOAD_BASE="https://gitee.com/${GITEE_REPO}/releases/download"
elif [ "$PLATFORM" = "GITLAB" ]; then
    # GitLab Generic Package URL 格式: {project_url}/-/packages/generic/{package_name}/{version}/{filename}
    GITLAB_PROJECT_URL="${GITLAB_PROJECT_URL:-https://gitlab.com/raojm/btwtemplates}"
    DOWNLOAD_BASE="${GITLAB_PROJECT_URL}/-/packages/generic/btwtemplates"
elif [ "$PLATFORM" = "ALIYUN" ]; then
    # 阿里云效制品库 URL，需要配置 BTWTEMPLATES_ARTIFACT_BASE
    DOWNLOAD_BASE="${BTWTEMPLATES_ARTIFACT_BASE:-https://packages.aliyun.com/generic/btwtemplates/releases}"
else
    # 默认 GitHub
    DOWNLOAD_BASE="https://github.com/${REPO}/releases/download"
fi

mkdir -p "$OUTPUT_DIR"

# 扫描 templates/ 目录，找到所有包含 template.json 的子目录
TEMPLATE_IDS=""
for DIR in "$TEMPLATES_DIR"/*/; do
    if [ -f "$DIR/template.json" ]; then
        ID=$(basename "$DIR")
        TEMPLATE_IDS="$TEMPLATE_IDS $ID"
    fi
done
TEMPLATE_IDS=$(echo "$TEMPLATE_IDS" | xargs)  # trim whitespace

if [ -z "$TEMPLATE_IDS" ]; then
    echo "⚠ No templates found in $TEMPLATES_DIR"
    exit 1
fi

INDEX_ENTRIES="[]"

for ID in $TEMPLATE_IDS; do
    TEMPLATE_DIR="$TEMPLATES_DIR/$ID"

    if [ ! -f "$TEMPLATE_DIR/template.json" ]; then
        echo "⚠ template.json not found in: $TEMPLATE_DIR"
        continue
    fi

    # 从 template.json 读取版本号（单一来源）
    VERSION=$(jq -r '.version // "1.0.0"' "$TEMPLATE_DIR/template.json")

    echo "Packing: $ID v$VERSION"

    # 读取 template.json 元数据
    NAME=$(jq -r '.name // "'"$ID"'"' "$TEMPLATE_DIR/template.json")
    DESC=$(jq -r '.description // ""' "$TEMPLATE_DIR/template.json")
    AUTHOR=$(jq -r '.author // "ByteWorld"' "$TEMPLATE_DIR/template.json")
    MIN_VER=$(jq -r '.min_engine_version // "4.6"' "$TEMPLATE_DIR/template.json")
    TAGS=$(jq -c '.tags // []' "$TEMPLATE_DIR/template.json")

    # 打包 zip（template.json 已包含正确版本，无需修改）
    ZIP_PATH="$OUTPUT_DIR/$ID.zip"
    rm -f "$ZIP_PATH"
    (cd "$TEMPLATE_DIR" && zip -r "$ZIP_PATH" . -x "*.DS_Store" -x "__MACOSX/*")
    echo "  ✓ $ID.zip ($(du -k "$ZIP_PATH" | cut -f1) KB, version=$VERSION)"

    # 计算 SHA256
    CHECKSUM=$(sha256sum "$ZIP_PATH" | cut -d' ' -f1)

    # 构建 download URL — tag 格式: {id}-v{version}，避免多模板 tag 冲突
    DOWNLOAD_URL="${DOWNLOAD_BASE}/${ID}-v${VERSION}/${ID}.zip"

    # 构建索引条目
    ENTRY=$(jq -n \
        --arg id "$ID" \
        --arg name "$NAME" \
        --arg desc "$DESC" \
        --arg author "$AUTHOR" \
        --arg version "$VERSION" \
        --arg min_ver "$MIN_VER" \
        --argjson tags "$TAGS" \
        --arg url "$DOWNLOAD_URL" \
        --arg checksum "$CHECKSUM" \
        '{
            id: $id,
            name: $name,
            description: $desc,
            author: $author,
            version: $version,
            min_engine_version: $min_ver,
            tags: $tags,
            download_url: $url,
            checksum: $checksum
        }')

    INDEX_ENTRIES=$(echo "$INDEX_ENTRIES" | jq --argjson entry "$ENTRY" '. += [$entry]')
done

# 写入 template-index.json（自动生成，勿手动编辑，所有数据来源于 templates/{id}/template.json）
TODAY=$(date +%Y-%m-%d)
jq -n \
    --arg version "1" \
    --arg updated "$TODAY" \
    --argjson templates "$INDEX_ENTRIES" \
    '{
        _comment: "自动生成，勿手动编辑。运行 bash scripts/pack.sh 更新。数据来源: templates/{id}/template.json",
        version: ($version | tonumber),
        updated: $updated,
        templates: $templates
    }' > "$INDEX_PATH"

echo ""
echo "✓ Index updated: $INDEX_PATH"
echo "✓ Templates: $(echo "$INDEX_ENTRIES" | jq 'length')"
