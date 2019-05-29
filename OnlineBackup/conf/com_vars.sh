#!/usr/bin/bash
# ------------------------------------------------------------------------------
# 共通変数定義
# ------------------------------------------------------------------------------
export LANG=C
export SCRIPT_NAME=${0##*/}

# 共通ディレクトリ定義
# ------------------------------------------------------------------------------
SCRIPT_EXEC_BIN=${0%/*}
SCRIPT_ROOT_DIR=$(cd ${SCRIPT_EXEC_BIN}/../; pwd)
SCRIPT_CONF_DIR=${SCRIPT_ROOT_DIR}/conf
SCRIPT_BIN_DIR=${SCRIPT_ROOT_DIR}/bin
SCRIPT_LOG_DIR=${SCRIPT_ROOT_DIR}/log
SCRIPT_TMP_DIR=${SCRIPT_ROOT_DIR}/tmp


# 共通シェル定義
# ------------------------------------------------------------------------------
export COMMON_FUNCTION=${SCRIPT_BIN}/com_func.sh
export SCRIPT_EXEC_NODE=$(uname -n)                                             # 実行ノード名取得


# 実行時刻取得
export SCRIPT_EXEC_TIME=$(date +"%Y%m%d-%H%M%S")                                # YYYYmmdd-HHMMSS
export SCRIPT_EXEC_DATE=${SCRIPT_EXEC_TIME%-*}                                  # YYYYmmdd

# ファイル定義
export SCRIPT_LOG=${SCRIPT_LOG_DIR}/${SCRIPT_NAME/.sh/}-${SCRIPT_EXEC_TIME}.log
export SCRIPT_TMP=${SCRIPT_LOG/.log/.tmp}

export SCRIPT_TMP1=${SCRIPT_TMP}.1
export SCRIPT_TMP2=${SCRIPT_TMP}.2
export SCRIPT_TMP_ALL=${SCRIPT_TMP}.*

# バックアップ除外リスト
export EXCLUDE_DEF=${SCRIPT_CONF_DIR}/exclude.def
