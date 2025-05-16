#!/bin/bash
# datsync - Simple Backup Script
# Copyright 2025 datsforge
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0

NAME="datsync"
VERSION="1.0.0"
VERBOSE=false
MIRRORING=false

# Define config directory and file path
CONFIG_DIR="$HOME/.config"
CONFIG_FILE="$CONFIG_DIR/datsync.conf"

# Default values:
DEFAULT_LOCAL_PATH="$HOME/backups/sync/local"
DEFAULT_OUT_PATH="/backups/sync/local"
# This can be overridden by config file.
LOCAL_PATH="$DEFAULT_LOCAL_PATH"
OUT_PATH="$DEFAULT_OUT_PATH"
ANDROID_INTERNAL_PATH="/sdcard$OUT_PATH"
BACKUP_PATHS=()

init_config() {
  # Create config if it doesn't exist.
   if [[ ! -f "$CONFIG_FILE" ]]; then
      # Create .config directory if it doesn't exist.
       if [[ ! -d "$CONFIG_DIR" ]]; then
         mkdir -p "$CONFIG_DIR"
         chmod 700 "$CONFIG_DIR"
       fi
      # Create the default config file.
        cat > "$CONFIG_FILE" <<EOF
# datsync configuration
OUT_PATH="$DEFAULT_OUT_PATH"
LOCAL_PATH="$DEFAULT_LOCAL_PATH"
EOF
        chmod 600 "$CONFIG_FILE"
        echo "Created new config file at $CONFIG_FILE"
   fi

   # Load the config
   source "$CONFIG_FILE"

   # Verify LOCAL_PATH exists after loading config, else create one.
    if [[ ! -d "$LOCAL_PATH" ]]; then
        echo "No local path creating one."
        mkdir -p "$LOCAL_PATH" || {
          echo "Error: Failed to create local path: $LOCAL_PATH"
          return 1
        }
        echo "Created local path: $LOCAL_PATH"
    fi
}

configure() {
  echo "Current configuration:"
  echo "1. Out path: $OUT_PATH"
  echo "2. Local path: $LOCAL_PATH"
  echo "3. Set to default"
  echo "4. Exit"

  read -r -p "Select option to change [1-3]: " choice
  case "$choice" in
    1)
      read -r -p "Enter new destination path: " new_path
      escaped_path=$(printf '%s\n' "$new_path" | sed 's/[\/&]/\\&/g')
      sed -i "s|^[[:space:]]*OUT_PATH=.*|OUT_PATH=\"$escaped_path\"|" "$CONFIG_FILE"
      ;;
    2)
      read -r -p "Enter new local path: " new_path
      escaped_path=$(printf '%s\n' "$new_path" | sed 's/[\/&]/\\&/g')
      sed -i "s|^[[:space:]]*LOCAL_PATH=.*|LOCAL_PATH=\"$new_path\"|" "$CONFIG_FILE"
      ;;
    3)
      sed -i "s|^[[:space:]]*OUT_PATH=.*|OUT_PATH=\"$DEFAULT_OUT_PATH\"|" "$CONFIG_FILE"
      sed -i "s|^[[:space:]]*LOCAL_PATH=.*|LOCAL_PATH=\"$DEFAULT_LOCAL_PATH\"|" "$CONFIG_FILE"
      echo "Configuration set to default."
      ;;
    4)
      exit 0
      ;;
    *)
      echo "Invalid option"
      exit 0
      ;;
  esac

  # Reload config
  source "$CONFIG_FILE"
  echo "Configuration updated:"
  echo "OUT_PATH=$OUT_PATH"
  echo "LOCAL_PATH=$LOCAL_PATH"
}


show_help() {
  cat << EOF
syncdat v$VERSION — Android Data Sync Tool with Persistent Settings

Usage:
  push      <target> [storage]       Push files from local path to device
  pull      <target> [storage]       Pull files from device to local path
  push-m    <target> [storage]       Mirror push: remove files on device not in local
  pull-m    <target> [storage]       Mirror pull: remove files locally not in device

Arguments:
  <target>                           android | usb
  [storage] (android only)           internal | external | all
                                     or use short options:
                                       -an    (same as "android internal")
                                       -ax    (same as "android external")

Options:
  -l, --local <PATH>                 Override default local path for this operation
  -c, --config                       Configure default paths and preferences
  -h, --help                         Show this help message

Examples:
  push android internal              Push to Android’s internal storage (/sdcard/)
  pull android -ax                   Pull from Android’s external storage (/storage/)
  push-m android                     Mirror-push to Android (prompts for storage)
  pull-m usb                         Mirror-pull from USB drive
  push usb                           Push to USB from local backup path
  pull android                       Pull from Android (prompts for storage)

Notes:
  - Mirror operations (-m) will delete files not present in the source — use with caution.
  - If [storage] is omitted for Android, a prompt will let you select internal, external, or both.
EOF
}

show_version() {
  echo "$NAME v$VERSION"
}

error() {
  echo "Error: $1" >&2
}

parse_options() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
      push|pull|push-m|pull-m)
        MODE="$key"
        TARGET="$2"
        STORAGE=""
        case "$TARGET" in
          -usb|-u)
            TARGET="usb"
            shift 1
            ;;
          -an)
            TARGET="android"
            STORAGE="internal"
            shift 2
            ;;
          -ax)
            TARGET="android"
            STORAGE="external"
            shift 2
            ;;
           -aa)
            TARGET="android"
            STORAGE="all"
            shift 2
            ;;
          -android|-a)
            TARGET="android"
            STORAGE="$3"
            if [[ -z "$STORAGE" ]]; then
              echo "Please choose target :"
              select choice in "internal" "external" "all"; do
                case "$choice" in
                  internal|external|all)
                    STORAGE="$choice"
                    break
                    ;;
                  *)
                    echo "Invalid option. Please choose a number."
                    ;;
                esac
              done
              shift 2
            else
              if [[ "$STORAGE" != "internal" && "$STORAGE" != "external" && "$STORAGE" != "all" ]]; then
                error "Invalid android storage option: $STORAGE (must be 'internal' , 'external' or 'all')"
                return 1
              fi
              shift 3
            fi
            ;;
          *)
            error "Invalid target for '$MODE': $TARGET"
            return 1
            ;;
        esac

        # At this point you have MODE, TARGET, STORAGE
        echo "Mode: $MODE"
        echo "Target: $TARGET"
        echo "Storage: $STORAGE"
        return 0
        ;;


      -l|--local)
        LOCAL_PATH="$2"
        shift 2
        return 0
        ;;
      -a|--android)
        ANDROID_PATH="$2"
        shift 2
        return 0
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        return 0
        ;;
      -c|--config)
        configure
        exit 0
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      --version)
        show_version
        exit 0
        ;;
      *)
        error "Unknown option: $key"
        exit 1
        ;;
    esac
  done

  # Validation
  [[ -z "$MODE" ]] && error "You must specify -push or -pull"
  [[ ! -d "$LOCAL_PATH" ]] && error "Local path does not exist: $LOCAL_PATH"
}

main() {
  init_config
  if parse_options "$@";then
  case "$MODE" in
    push) sync_push ;;
    mirror-push)
      MIRRORING=true
      sync_push ;;
    pull) sync_pull ;;
    mirror-pull)
      MIRRORING=true
      sync_pull ;;
  esac
  fi
}

start_adb(){
  if ! command -v adb &> /dev/null; then
      echo "❌ ADB not installed. Run: sudo apt install adb"
      return 1
  else
      adb start-server &> /dev/null
      return 0
  fi
}

detect_android_device(){
  if ! adb devices | grep -w "device" &>/dev/null; then
    echo "❌ No android device detected."
    echo "-make sure usb debugging is enabled."
    return 1
  else
    echo "✅ Android device detected."
  fi
}

detect_removable_device() {
  device=$(lsblk -o NAME,RM,TYPE,MOUNTPOINT -nr |
    awk '($3 == "part" && $4 != "" && $1 !~ /^zram/ && ($2 == 1 || ($1 ~ /^mmcblk/ && $4 != ""))) {print $1; exit}')

  if [[ -n "$device" ]]; then
    REMOVABLE_MOUNT_POINT=$(lsblk -o NAME,MOUNTPOINT -nr | awk -v dev="$device" '$1 == dev {print $2}')
    echo "✅ Detected mounted removable device: /dev/$device mounted at $REMOVABLE_MOUNT_POINT"
    export USB_MOUNT_PATH="$REMOVABLE_MOUNT_POINT"
    return 0
  else
    echo "❌ No mounted removable device found. Make sure device is mounted."
    return 1
  fi
}

check_android_backup_paths() {
  local potential_mounts
  # Check internal storage
  echo "android internal path  = $ANDROID_INTERNAL_PATH"
  if adb shell "[ -d \"$ANDROID_INTERNAL_PATH\" ]"; then
    echo "✅ Found backup source path in internal storage: $ANDROID_INTERNAL_PATH"
    has_anroid_int_backup=true
    BACKUP_PATHS+=("$ANDROID_INTERNAL_PATH")
  fi
  # Check external storage (SD cards)
  potential_mounts=$(adb shell "ls /storage" | tr -d '\r')
  for mount in $potential_mounts; do
    if [[ "$mount" =~ ^[0-9A-Fa-f\-]{4,}$ ]]; then
      test_dest_path="/storage/$mount$OUT_PATH"
      if adb shell "[ -d \"$test_dest_path\" ]"; then
        BACKUP_PATHS+=("$test_dest_path")
        echo "✅ Found backup source_path in SD card: $test_dest_path"
        has_android_ext_backup=true
        break
      fi
    fi
  done
  if [ ${#BACKUP_PATHS[@]} -eq 0 ]; then
      echo "❌ No backup source_path found in Android device."
      create_dest_path_msg
      return 1
  fi
}

check_removable_backup_paths() {
    # Clear any existing paths
    BACKUP_PATHS=()
    # Find all removable devices (USB and MMC/SD cards)
    while read -r device mount_point; do
        full_path="${mount_point%/}${OUT_PATH}"
        echo "Checking: $full_path..."
        # Verify the path exists and is writable
        if [[ -d "$full_path" ]]; then
            if [[ -w "$full_path" ]]; then
                BACKUP_PATHS+=("$full_path")
                echo "✅ Found backup source path: $full_path"
            else
                echo "⚠️  Found but not writable: $full_path"
            fi
        else
            # Try to create the path if it doesn't exist
            echo "No backup path detected creating one..."
            if mkdir -p "$full_path" 2>/dev/null; then
                BACKUP_PATHS+=("$full_path")
                echo "✅ Created backup path: $full_path"
            else
                echo "❌ Cannot access: $full_path"
            fi
        fi
    done < <(lsblk -o NAME,MOUNTPOINT,RM,RO,HOTPLUG -nr | \
             awk '($3 == 1 || $5 == 1) && $2 != "" && $4 == 0 {print "/dev/"$1, $2}')

    if [[ ${#BACKUP_PATHS[@]} -eq 0 ]]; then
        echo "❌ No valid backup paths found on removable devices."
        echo "Please ensure:"
        echo "1. A USB drive or SD card is properly inserted"
        echo "2. The device is mounted and writable"
        echo "3. The path $OUT_PATH exists or can be created"
        return 1
    fi
    return 0
}

sync_push() {
   case "$TARGET" in
      android)
        echo "android push test"
        start_adb
        detect_android_device
        if check_android_backup_paths;then
           sync_pc_to_android
        fi;;
      usb)
        detect_removable_device
        if check_removable_backup_paths;then
           sync_pc_to_removable
        fi ;;
   esac
}

sync_pull() {
   case "$TARGET" in
        android)
         start_adb
         detect_android_device
          if check_android_backup_paths;then
             sync_android_to_pc
          fi ;;
        usb)
          detect_removable_device
          if check_removable_backup_paths;then
          sync_removable_to_pc
          fi ;;
     esac
}

sync_pc_to_android() {
    local ANDROID_TMP
    local success_flag=true
    local synced_items=0
    local skipped_items=0
    local failed_items=0
    local deleted_items=0
    local android_del_dirs=0
    local created_dirs=0
    local batch_size=100  # Number of files to delete per batch

    # Create temp directory
    ANDROID_TMP="/sdcard/tmp_sync_$(date +%s)"
    if ! adb shell "mkdir -p '$ANDROID_TMP'"; then
        echo >&2 "❌ Failed to create temp directory"
        return 1
    fi

    # Loop through all destination paths
    for source_path in "${BACKUP_PATHS[@]}"; do

        # Assign the storage path that is selected for syncing
        # TODO : not all android uses this path structure al least not most,
        # find a better way?
       case "$STORAGE" in
           internal)
             [[ "$source_path" == /sdcard/* || "$source_path" == /storage/emulated/0/* ]] || continue ;;
           external)
             [[ "$source_path" == /storage/* && "$source_path" != /storage/emulated/* ]] || continue ;;
           all) ;;
         esac

        # Sync to the selected source path
        echo "=== Syncing to $source_path ==="
        # Ensure destination directory exists
        if ! adb shell "mkdir -p '$source_path'"; then
            echo >&2 "❌ Failed to create destination directory: $source_path"
            ((failed_items++))
            success_flag=false
            continue
        fi
        # Get all local files with relative paths
        mapfile -t local_files < <(find "$LOCAL_PATH" -type f -printf '%P\n')
        # Process each local file
        for local_file in "${local_files[@]}"; do
            local_file_full="$LOCAL_PATH/$local_file"
            android_file="$source_path/$local_file"
            temp_file="$ANDROID_TMP/${local_file##*/}"
            # Get local MD5
            local_md5=$(md5sum "$local_file_full" | awk '{print $1}')
            # Get Android MD5 if file exists
            android_md5=$(adb shell "[ -f '$android_file' ] && md5sum '$android_file' 2>/dev/null" | awk '{print $1}')
            # Create parent directory if needed
            android_dir="${android_file%/*}"
            if ! adb shell "[ -d '$android_dir' ]" 2>/dev/null; then
                echo "📁 Creating directory: $android_dir"
                if ! adb shell "mkdir -p '$android_dir'"; then
                    echo >&2 "❌ Failed to create directory: $android_dir"
                    ((failed_items++))
                    success_flag=false
                    continue
                fi
            fi
            # Skip if files are identical
            if [[ -n "$android_md5" && "$local_md5" == "$android_md5" ]]; then
                echo "✓ Unchanged: $android_file"
                ((skipped_items++))
                continue
            fi
            # Atomic push via temp file
            echo "🔄 Syncing: $local_file -> $android_file"
            if adb push "$local_file_full" "$temp_file" >/dev/null && \
               adb shell "mv '$temp_file' '$android_file'"; then
                ((synced_items++))
            else
                echo >&2 "❌ Failed to sync: $local_file"
                ((failed_items++))
                success_flag=false
            fi
        done

        # Mirroring - this will delete all orphan files and empty directories in the target android path not present in the source path,
        # and also copies all empty directories in the source path not present in the target android path.
        if $MIRRORING; then
            # Handle file deletions
            echo "-------------- Checking for files to delete on Android..."
            local_files_set=$(find "$LOCAL_PATH" -type f -printf '%P\n' | sort)
            android_files_set=$(adb shell "cd '$source_path' && find . -type f" 2>/dev/null | tr -d '\r' | sed 's|^\./||' | sort)
            # Collect orphaned files
            orphans=()
            while read -r android_file; do
                if ! grep -Fxq "$android_file" <<< "$local_files_set"; then
                    orphans+=("'$source_path/$android_file'")
                fi
            done <<< "$android_files_set"
            # Batch deletion
            if (( ${#orphans[@]} > 0 )); then
                echo "🗑️ Found ${#orphans[@]} orphans to delete"
                for ((i=0; i<${#orphans[@]}; i+=batch_size)); do
                    batch=("${orphans[@]:i:batch_size}")
                    echo "  Deleting batch of ${#batch[@]} files..."
                    if adb shell "rm -f ${batch[*]}"; then
                        ((deleted_items += ${#batch[@]}))
                    else
                        echo >&2 "❌ Failed to delete batch"
                        ((failed_items += ${#batch[@]}))
                        success_flag=false
                    fi
                done
            else
              echo "No files to delete."
            fi

            # Create missing directories.
            echo "-------------- Syncing directory structure..."
            local_dirs=$(find "$LOCAL_PATH" -type d -empty -printf '%P\n' | sort)
            local android_dirs
            android_dirs=$(adb shell "cd \"$source_path\" && find . -type d | sed 's|^\./||'" | tr -d '\r' | sort)
            # Collect missing dirs
            missing_dirs=()
            while read -r local_dir; do
               [[ -z "$local_dir" ]] && continue
               if ! grep -Fxq "$local_dir" <<< "$android_dirs"; then
                   missing_dirs+=("\"$source_path/$local_dir\"")
               fi
            done <<< "$local_dirs"
            # Bulk-create
            if (( ${#missing_dirs[@]} > 0 )); then
               echo "📦 Creating ${#missing_dirs[@]} missing directories..."
               mkdir_command="mkdir -p ${missing_dirs[*]}"
               if adb shell "$mkdir_command"; then
                   created_dirs=${#missing_dirs[@]}
               else
                   echo "❌ Failed to create some directories"
               fi
            else
               echo "No directories to create."
            fi

            # Delete all empty directories not in the local source path.
            echo "-------------- Checking for obsolete empty directories..."
            android_del_dirs=0
            local found_obsolete=false
            ## Get all Android directories sorted by depth (deepest first)
            mapfile -t android_dirs < <(
                adb shell "cd \"$source_path\" && find . -type d | awk '{ print length, \$0 }' | sort -rn | cut -d' ' -f2-" |
                tr -d '\r' |
                sed 's|^\./||'
            )
            ## Process each directory (deepest first)
            deleted_paths=()
            for android_dir in "${android_dirs[@]}"; do
                # Skip if directory exists locally
                [[ -d "$LOCAL_PATH/$android_dir" ]] && continue
                full_path="$source_path/$android_dir"
                # Check if directory is empty (may have become empty after subdir deletions)
                is_empty=$(adb shell "[ -d '$full_path' ] && [ -z \"\$(ls -A '$full_path')\" ] && echo EMPTY")
                if [[ "$is_empty" == "EMPTY" ]]; then
                   found_obsolete=true
                    echo "  🗑️ Deleting empty directory : $full_path"
                    if adb shell "rmdir '$full_path'"; then
                        ((android_del_dirs++))
                        deleted_paths+=("$android_dir")
                    else
                        echo "  ❌ Failed to delete: $full_path (may not be empty)"
                    fi
                fi
            done
            if ! $found_obsolete; then
                echo "No obsolete empty directories found."
            fi

      fi
    done

    # Cleanup
    adb shell "rm -rf '$ANDROID_TMP'" 2>/dev/null

    # Summary
    echo "============================== Sync Summary =============================="
    echo " ✅ Synced: $synced_items files"
    echo " ➖ Unchanged: $skipped_items files"
    echo "🗑️ Deleted:"
    echo "   - Files: $deleted_items"
    echo "   - Directories: $android_del_dirs"
    echo " 📂 Created $created_dirs empty directories"
    echo "🗑️ Removed $android_del_dirs empty directories"
    echo " ❌ Failed: $failed_items operations"
    if $success_flag; then
        echo " 🌟 Sync completed successfully!"
        return 0
    else
        echo >&2 " ⚠️ Sync completed with errors!"
        return 1
    fi
}

sync_android_to_pc() {
    local ANDROID_TMP
    local success_flag=true
    local synced_items=0
    local skipped_items=0
    local failed_items=0
    local deleted_items=0
    local pc_del_dirs=0
    local created_dirs=0
    local batch_size=100

    # Create temp directory on PC
    ANDROID_TMP="/tmp/android_sync_$(date +%s)"
    mkdir -p "$ANDROID_TMP" || {
        echo >&2 "❌ Failed to create local temp directory"
        return 1
    }

    # Loop through destination paths
    for source_path in "${BACKUP_PATHS[@]}"; do
        echo "=== Syncing from $source_path ==="
        mkdir -p "$LOCAL_PATH" || {
            echo >&2 "❌ Failed to ensure local root directory exists"
            ((failed_items++))
            success_flag=false
            continue
        }

        # Get all Android files
        mapfile -t android_files < <(adb shell "cd '$source_path' && find . -type f" | tr -d '\r' | sed 's|^\./||')

        for android_file in "${android_files[@]}"; do
            local_file="$LOCAL_PATH/$android_file"
            android_file_full="$source_path/$android_file"
            temp_file="$ANDROID_TMP/$(basename "$android_file")"

            # Get Android MD5
            android_md5=$(adb shell "md5sum '$android_file_full' 2>/dev/null" | awk '{print $1}')
            # Get local MD5 if exists
            if [[ -f "$local_file" ]]; then
                local_md5=$(md5sum "$local_file" | awk '{print $1}')
            else
                local_md5=""
            fi

            # Skip if identical
            if [[ -n "$android_md5" && "$android_md5" == "$local_md5" ]]; then
                echo "✓ Unchanged: $android_file"
                ((skipped_items++))
                continue
            fi

            echo "🔄 Syncing: $android_file_full -> $local_file"
            local_dir="${local_file%/*}"
            mkdir -p "$local_dir"

            if adb pull "$android_file_full" "$temp_file" >/dev/null && mv "$temp_file" "$local_file"; then
                ((synced_items++))
            else
                echo >&2 "❌ Failed to sync: $android_file"
                ((failed_items++))
                success_flag=false
            fi
        done

        if $MIRRORING; then
            echo "-------------- Checking for local files to delete..."
            android_files_set=$(printf '%s\n' "${android_files[@]}" | sort)
            local_files_set=$(find "$LOCAL_PATH" -type f -printf '%P\n' | sort)
            orphans=()
            while read -r local_file; do
                if ! grep -Fxq "$local_file" <<< "$android_files_set"; then
                    orphans+=("'$LOCAL_PATH/$local_file'")
                fi
            done <<< "$local_files_set"

            if (( ${#orphans[@]} > 0 )); then
                echo "🗑️ Found ${#orphans[@]} orphan local files to delete"
                for ((i=0; i<${#orphans[@]}; i+=batch_size)); do
                    batch=("${orphans[@]:i:batch_size}")
                    echo "  Deleting batch of ${#batch[@]} files..."
                    if rm -f "${batch[@]}"; then
                        ((deleted_items += ${#batch[@]}))
                    else
                        echo >&2 "❌ Failed to delete local batch"
                        ((failed_items += ${#batch[@]}))
                        success_flag=false
                    fi
                done
            else
                echo "No local files to delete."
            fi

           echo "-------------- Syncing directory structure..."
           local android_dirs
           android_dirs=$(adb shell "cd '$source_path' && find . -type d | sed 's|^\./||'" | tr -d '\r' | sort)
           local_dirs=$(find "$LOCAL_PATH" -type d -printf '%P\n' | sort)

           missing_dirs=()
           while read -r android_dir; do
               [[ -z "$android_dir" ]] && continue
               if ! [[ -d "$LOCAL_PATH/$android_dir" ]]; then
                   missing_dirs+=("$LOCAL_PATH/$android_dir")
                   echo "Missing directory : $android_dir"
               fi
           done <<< "$android_dirs"

           if (( ${#missing_dirs[@]} > 0 )); then
               echo "📂 Creating ${#missing_dirs[@]} missing local directories..."
               for dir in "${missing_dirs[@]}"; do
                   if mkdir -p "$dir"; then
                       ((created_dirs++))
                   else
                       echo "❌ Failed to create: $dir"
                   fi
               done
               echo "Successfully created $created_dirs directories"
           else
               echo "Directory structure already in sync - nothing to create"
           fi

            echo "-------------- Checking for obsolete empty local directories..."
            mapfile -t local_dirs_rev < <(find "$LOCAL_PATH" -type d | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)
            deleted_paths=()
            local found_obsolete=false
            for local_dir in "${local_dirs_rev[@]}"; do
                rel_dir="${local_dir#"$LOCAL_PATH"/}"
                if printf '%s\n' "${android_dirs[@]}" | grep -Fxq "$rel_dir"; then
                    continue
                fi
                if [[ -z "$(ls -A "$local_dir")" ]]; then
                    echo "  🗑️ Deleting empty directory : $local_dir"
                    if rmdir "$local_dir"; then
                        ((pc_del_dirs++))
                        deleted_paths+=("$rel_dir")
                        found_obsolete=true
                    else
                        echo "  ❌ Failed to delete: $local_dir"
                    fi
                fi
            done

            if ! $found_obsolete; then
                echo "No obsolete local directories found."
            fi
        fi
    done

    rm -rf "$ANDROID_TMP" 2>/dev/null

    echo "=========================== Sync Summary ==========================="
    echo " ✅ Synced: $synced_items files"
    echo " ➖ Unchanged: $skipped_items files"
    echo "🗑️ Deleted:"
    echo "   - Files: $deleted_items"
    echo "   - Directories: $pc_del_dirs"
    echo " 📂 Created $created_dirs empty directories"
    echo " ❌ Failed: $failed_items operations"
    if $success_flag; then
        echo " 🌟 Sync from Android completed successfully!"
        return 0
    else
        echo >&2 " ⚠️ Sync from Android completed with errors!"
        return 1
    fi
}

sync_pc_to_removable() {
    local success_flag=true
    local synced_items=0
    local skipped_items=0
    local failed_items=0
    local deleted_items=0
    local removed_dirs=0
    local created_dirs=0
    local batch_size=100

    for source_path in "${BACKUP_PATHS[@]}"; do
        echo "=== Syncing to $source_path ==="

        mkdir -p "$source_path" || {
            echo >&2 "❌ Failed to create destination directory: $source_path"
            ((failed_items++))
            success_flag=false
            continue
        }

        mapfile -t local_files < <(find "$LOCAL_PATH" -type f -printf '%P\n')

        for local_file in "${local_files[@]}"; do
            local_file_full="$LOCAL_PATH/$local_file"
            removable_file="$source_path/$local_file"

            local_md5=$(md5sum "$local_file_full" | awk '{print $1}')
            if [[ -f "$removable_file" ]]; then
                remote_md5=$(md5sum "$removable_file" | awk '{print $1}')
            else
                remote_md5=""
            fi

            # Make sure parent dir exists
            dir_path="${removable_file%/*}"
            mkdir -p "$dir_path"

            if [[ -n "$remote_md5" && "$local_md5" == "$remote_md5" ]]; then
                echo "✓ Unchanged: $removable_file"
                ((skipped_items++))
                continue
            fi

            echo "🔄 Syncing: $local_file -> $removable_file"
            if cp "$local_file_full" "$removable_file"; then
                ((synced_items++))
            else
                echo >&2 "❌ Failed to sync: $local_file"
                ((failed_items++))
                success_flag=false
            fi
        done

        if $MIRRORING; then
            echo "-------------- Checking for files to delete on Removable..."
            local_files_set=$(find "$LOCAL_PATH" -type f -printf '%P\n' | sort)
            removable_files_set=$(cd "$source_path" && find . -type f | sed 's|^\./||' | sort)

            orphans=()
            while read -r f; do
                if ! grep -Fxq "$f" <<< "$local_files_set"; then
                    orphans+=("$source_path/$f")
                fi
            done <<< "$removable_files_set"

            if (( ${#orphans[@]} > 0 )); then
                echo "🗑️ Found ${#orphans[@]} orphans to delete"
                for ((i=0; i<${#orphans[@]}; i+=batch_size)); do
                    batch=("${orphans[@]:i:batch_size}")
                    echo "  Deleting batch of ${#batch[@]} files..."
                    if rm -f "${batch[@]}"; then
                        ((deleted_items += ${#batch[@]}))
                    else
                        echo >&2 "❌ Failed to delete batch"
                        ((failed_items += ${#batch[@]}))
                        success_flag=false
                    fi
                done
            else
                echo "No files to delete."
            fi

            echo "-------------- Syncing directory structure..."
            local_dirs=$(find "$LOCAL_PATH" -type d -empty -printf '%P\n' | sort)
            removable_dirs=$(cd "$source_path" && find . -type d | sed 's|^\./||' | sort)

            missing_dirs=()
            while read -r d; do
                [[ -z "$d" ]] && continue
                if ! grep -Fxq "$d" <<< "$removable_dirs"; then
                    missing_dirs+=("$source_path/$d")
                fi
            done <<< "$local_dirs"

            if (( ${#missing_dirs[@]} > 0 )); then
                echo "📦 Creating ${#missing_dirs[@]} missing directories..."
                if mkdir -p "${missing_dirs[@]}"; then
                    created_dirs=${#missing_dirs[@]}
                else
                    echo "❌ Failed to create some directories"
                fi
            else
                echo "No directories to create."
            fi

            echo "-------------- Checking for obsolete empty directories..."
            mapfile -t removable_dirs < <(cd "$source_path" && find . -type d | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- | sed 's|^\./||')

            for dir in "${removable_dirs[@]}"; do
                [[ -d "$LOCAL_PATH/$dir" ]] && continue
                full_path="$source_path/$dir"
                if [[ -d "$full_path" && -z "$(ls -A "$full_path")" ]]; then
                    echo "🗑️ Deleting empty directory: $full_path"
                    if rmdir "$full_path"; then
                        ((removed_dirs++))
                    else
                        echo "❌ Failed to delete: $full_path"
                    fi
                fi
            done
        fi
    done

    echo "============================== Sync Summary =============================="
    echo " ✅ Synced: $synced_items files"
    echo " ➖ Unchanged: $skipped_items files"
    echo "🗑️ Deleted:"
    echo "   - Files: $deleted_items"
    echo "   - Directories: $removed_dirs"
    echo " 📂 Created $created_dirs empty directories"
    echo " ❌ Failed: $failed_items operations"
    if $success_flag; then
        echo " 🌟 Sync completed successfully!"
        return 0
    else
        echo >&2 " ⚠️ Sync completed with errors!"
        return 1
    fi
}

sync_removable_to_pc() {
    local success_flag=true
    local synced_items=0
    local skipped_items=0
    local failed_items=0
    local deleted_items=0
    local removed_dirs=0
    local created_dirs=0
    local batch_size=100

    for source_path in "${BACKUP_PATHS[@]}"; do
        echo "=== Syncing from $source_path ==="

        mkdir -p "$LOCAL_PATH" || {
            echo >&2 "❌ Failed to create local directory: $LOCAL_PATH"
            ((failed_items++))
            success_flag=false
            continue
        }

        mapfile -t removable_files < <(find "$source_path" -type f -printf '%P\n')

        for removable_file in "${removable_files[@]}"; do
            removable_file_full="$source_path/$removable_file"
            local_file="$LOCAL_PATH/$removable_file"

            remote_md5=$(md5sum "$removable_file_full" | awk '{print $1}')
            if [[ -f "$local_file" ]]; then
                local_md5=$(md5sum "$local_file" | awk '{print $1}')
            else
                local_md5=""
            fi

            # Make sure parent dir exists
            dir_path="${local_file%/*}"
            mkdir -p "$dir_path"

            if [[ -n "$local_md5" && "$local_md5" == "$remote_md5" ]]; then
                echo "✓ Unchanged: $local_file"
                ((skipped_items++))
                continue
            fi

            echo "🔄 Syncing: $removable_file -> $local_file"
            if cp "$removable_file_full" "$local_file"; then
                ((synced_items++))
            else
                echo >&2 "❌ Failed to sync: $removable_file"
                ((failed_items++))
                success_flag=false
            fi
        done

        if $MIRRORING; then
            echo "-------------- Checking for files to delete on Local..."
            removable_files_set=$(find "$source_path" -type f -printf '%P\n' | sort)
            local_files_set=$(cd "$LOCAL_PATH" && find . -type f | sed 's|^\./||' | sort)

            orphans=()
            while read -r f; do
                if ! grep -Fxq "$f" <<< "$removable_files_set"; then
                    orphans+=("$LOCAL_PATH/$f")
                fi
            done <<< "$local_files_set"

            if (( ${#orphans[@]} > 0 )); then
                echo "🗑️ Found ${#orphans[@]} orphans to delete"
                for ((i=0; i<${#orphans[@]}; i+=batch_size)); do
                    batch=("${orphans[@]:i:batch_size}")
                    echo "  Deleting batch of ${#batch[@]} files..."
                    if rm -f "${batch[@]}"; then
                        ((deleted_items += ${#batch[@]}))
                    else
                        echo >&2 "❌ Failed to delete batch"
                        ((failed_items += ${#batch[@]}))
                        success_flag=false
                    fi
                done
            else
                echo "No files to delete."
            fi

            echo "-------------- Syncing directory structure..."
            local removable_dirs
            removable_dirs=$(find "$source_path" -type d -empty -printf '%P\n' | sort)
            local_dirs=$(cd "$LOCAL_PATH" && find . -type d | sed 's|^\./||' | sort)

            missing_dirs=()
            while read -r d; do
                [[ -z "$d" ]] && continue
                if ! grep -Fxq "$d" <<< "$local_dirs"; then
                    missing_dirs+=("$LOCAL_PATH/$d")
                fi
            done <<< "$removable_dirs"

            if (( ${#missing_dirs[@]} > 0 )); then
                echo "📦 Creating ${#missing_dirs[@]} missing directories..."
                if mkdir -p "${missing_dirs[@]}"; then
                    created_dirs=${#missing_dirs[@]}
                else
                    echo "❌ Failed to create some directories"
                fi
            else
                echo "No directories to create."
            fi

            echo "-------------- Checking for obsolete empty directories on Local..."
            mapfile -t local_dirs < <(cd "$LOCAL_PATH" && find . -type d | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- | sed 's|^\./||')

            for dir in "${local_dirs[@]}"; do
                [[ -d "$source_path/$dir" ]] && continue
                full_path="$LOCAL_PATH/$dir"
                if [[ -d "$full_path" && -z "$(ls -A "$full_path")" ]]; then
                    echo "🗑️ Deleting empty directory: $full_path"
                    if rmdir "$full_path"; then
                        ((removed_dirs++))
                    else
                        echo "❌ Failed to delete: $full_path"
                    fi
                fi
            done
        fi
    done

    echo "============================== Sync Summary =============================="
    echo " ✅ Synced: $synced_items files"
    echo " ➖ Unchanged: $skipped_items files"
    echo "🗑️ Deleted:"
    echo "   - Files: $deleted_items"
    echo "   - Directories: $removed_dirs"
    echo " 📂 Created $created_dirs empty directories"
    echo " ❌ Failed: $failed_items operations"
    if $success_flag; then
        echo " 🌟 Sync completed successfully!"
        return 0
    else
        echo >&2 " ⚠️ Sync completed with errors!"
        return 1
    fi
}


create_dest_path_msg(){
   echo "Please make sure the backup folder \"$OUT_PATH\" exists on your target device."
}

main "$@"