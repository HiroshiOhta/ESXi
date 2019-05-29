#!/bin/sh
com_env="$(cd $(dirname $0); pwd)/../conf/com_vars.sh"

# 引数チェック
if [[ -n "${1}" ]]; then
    backup_directory=${1}
else
    log_priority=Error
    log_message="The path for a backup must be specified and must exist."
    return_code=1
    \logger -s -t ${0##*/} "[${log_priority}] ${log_message} RC=${return_code}"
    exit ${return_code}
fi

# 環境変数の読み込み
if [[ -f "${com_env}" ]]; then
    source ${com_env}
else
    log_priority=Error
    log_message="Environment variable file does not exist."
    return_code=2
    \logger -s -t ${0##*/} "[${log_priority}] ${log_message} RC=${return_code}"
    exit ${return_code}
fi

# trapの設定
# 0:EXIT 1:SIGHUP  2:SIGINT  3:SIGQUIT  15:SIGTERM
trap '\rm -f ${SCRIPT_TMP_ALL}' 1 2 3 15 EXIT

# バックアップ除外リスト
export exclude_def=${SCRIPT_CONF_DIR}/exclude.def

# 除外キーワード設定(最後に|が含まれる)
record_count=$(wc -l ${exclude_def})
exclude_key=$(\awk -v LR=${record_count% *} '{printf((NR==LR)?"%s":"%s|", $0)}' ${exclude_def})

# 収容しているVM一覧(vmid:vmxファイルパス)
\vim-cmd vmsvc/getallvms | grep -Ev "${exclude_key}" | awk '{gsub(/\[|\]/,""); if($0 ~ "vmx") print $1":/vmfs/volumes/"$3"/"$4}' > ${SCRIPT_TMP1}

# バックアップ取得
# ----------------------------------------------------------------------------------------------------------------------
for target_vm_data in $(cat ${SCRIPT_TMP1}); do

    vmid=${target_vm_data%%:*}

    vmx_file=${target_vm_data##*:}
    vm_file_tmp=${vmx_file/.vmx/}
    target_vm_name=${vm_file_tmp##*/}
    vmsd_file=${vm_file_tmp}.vmsd
    vmxf_file=${vmx_file}f

    # バックアップ開始メッセージ
    log_priority=Info
    log_message="${target_vm_name} backup start."
    \logger -s -t ${0##*/} "[${log_priority}] ${log_message}" >> ${SCRIPT_LOG}

    # 仮想マシンの起動フラグ設定
    is_running=$(\vim-cmd vmsvc/power.getstat ${vmid} | awk '{if($1 ~ "Powered") print $NF}')

    backup_dir=${backup_directory}/backup/${target_vm_name}/${SCRIPT_EXEC_DATE}
    if [[ ! -d "${backup_dir}" ]]; then
        \mkdir -p ${backup_dir}
    fi

    # バックアップ対象のVMDK一覧の取得
    \awk -F'"' '{if($0 ~ "vmdk") print $2}' ${vmx_file} > ${SCRIPT_TMP2}

    # 構成ファイルのバックアップ
    for backup_file in ${vmx_file} ${vmsd_file} ${vmxf_file}; do
        if [[ -f "${backup_file}" ]]; then
            cp -p ${backup_file} ${backup_dir}
        else
            log_priority=Warning
            log_message="${backup_file} does not exist."
            return_code=3
            \logger -s -t ${0##*/} "[${log_priority}] ${log_message} RC=${return_code}" >> ${SCRIPT_LOG}
        fi
    done

    # スナップショットの作成
    if [[ ${is_running} == "on" ]]; then
        \vim-cmd vmsvc/snapshot.create ${vmid} "for Online Bkup"

        if [[ -z "$(\vim-cmd vmsvc/snapshot.get ${vmid} | grep "ROOT")" ]]; then
            log_priority=Error
            log_message="Create Snapshot has failed."
            return_code=3
            \logger -s -t ${0##*/} "[${log_priority}] ${log_message} RC=${return_code}" >> ${SCRIPT_LOG}
            continue
        fi
    fi

    # VMDKファイルのバックアップ
    for vmdk_file in $(grep -Ev "\-rdm.vmdk|\-rdmp.vmdk" ${SCRIPT_TMP2}); do

        if [[ -n "$(echo ${vmdk_file} | grep "vmfs")" ]]; then
            target_vmdk_file=${vmdk_file}
            backup_vmdk_name=$(echo ${vmdk_file} | awk -F'/' '{print $4"-"$6}')
        else
            target_vmdk_file=${vmx_file%/*}/${vmdk_file}
            backup_vmdk_name=${vmdk_file}
        fi

        vmkfstools -d monosparse -i ${target_vmdk_file} ${backup_dir}/${backup_vmdk_name} >> ${SCRIPT_LOG}
        if [[ $? != 0 ]]; then
            log_priority=Error
            log_message="${target_vmdk_file} backup has failed."
            return_code=4
            \logger -s -t ${0##*/} "[${log_priority}] ${log_message} RC=${return_code}" >> ${SCRIPT_LOG}
            continue
        fi
    done

    # スナップショットの削除
    if [[ ${is_running} == "on" ]]; then
        \vim-cmd vmsvc/snapshot.removeall ${vmid}

        if [[ -n "$(\vim-cmd vmsvc/snapshot.get ${vmid} | grep "ROOT")" ]]; then
            log_priority=Error
            log_message="Delete Snapshot has failed."
            return_code=5
            \logger -s -t ${0##*/} "[${log_priority}] ${log_message} RC=${return_code}" >> ${SCRIPT_LOG}
            continue
        fi
    fi

    (cd ${backup_directory}/backup/${target_vm_name} ; tar -cvf ${SCRIPT_EXEC_DATE}.tgz ${SCRIPT_EXEC_DATE} >> ${SCRIPT_LOG})
    if [[ -f "${backup_directory}/backup/${target_vm_name}/${SCRIPT_EXEC_DATE}.tgz" ]]; then
        rm -fr ${backup_dir}
    else
        log_priority=Error
        log_message="Compress backup data has failed."
        return_code=6
        \logger -s -t ${0##*/} "[${log_priority}] ${log_message} RC=${return_code}" >> ${SCRIPT_LOG}
    fi

    # バックアップ開始メッセージ
    log_priority=Info
    log_message="${target_vm_name} backup finish."
    \logger -s -t ${0##*/} "[${log_priority}] ${log_message}" >> ${SCRIPT_LOG}

done