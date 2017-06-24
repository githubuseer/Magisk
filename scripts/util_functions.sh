##########################################################################################
# 
# Magisk General Utility Functions
# by topjohnwu
# 
# Used in flash_script.sh and addon.d.sh
# 
##########################################################################################

ui_print() {
  if $BOOTMODE; then
    echo "$1"
  else 
    echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD
    echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD
  fi
}

getvar() {
  local VARNAME=$1
  local VALUE=$(eval echo \$"$VARNAME");
  for FILE in /dev/.magisk /data/.magisk /cache/.magisk /system/.magisk; do
    if [ -z "$VALUE" ]; then
      LINE=$(cat $FILE 2>/dev/null | grep "$VARNAME=")
      if [ ! -z "$LINE" ]; then
        VALUE=${LINE#*=}
      fi
    fi
  done
  eval $VARNAME=\$VALUE
}

find_boot_image() {
  if [ -z "$BOOTIMAGE" ]; then
    for PARTITION in kern-a android_boot kernel boot lnx; do
      BOOTIMAGE=`find /dev/block -iname "$PARTITION" | head -n 1`
      [ ! -z $BOOTIMAGE ] && break
    done
  fi
  # Recovery fallback
  if [ -z "$BOOTIMAGE" ]; then
    for FSTAB in /etc/*fstab*; do
      BOOTIMAGE=`grep -E '\b/boot\b' $FSTAB | grep -oE '/dev/[a-zA-Z0-9_./-]*'`
      [ ! -z $BOOTIMAGE ] && break
    done
  fi
  [ -L "$BOOTIMAGE" ] && BOOTIMAGE=`readlink $BOOTIMAGE`
}

is_mounted() {
  if [ ! -z "$2" ]; then
    cat /proc/mounts | grep $1 | grep $2, >/dev/null
  else
    cat /proc/mounts | grep $1 >/dev/null
  fi
  return $?
}

grep_prop() {
  REGEX="s/^$1=//p"
  shift
  FILES=$@
  if [ -z "$FILES" ]; then
    FILES='/system/build.prop'
  fi
  cat $FILES 2>/dev/null | sed -n "$REGEX" | head -n 1
}

remove_system_su() {
  if [ -f /system/bin/su -o -f /system/xbin/su ] && [ ! -f /su/bin/su ]; then
    ui_print "! System installed root detected, mount rw :("
    mount -o rw,remount /system
    # SuperSU
    if [ -e /system/bin/.ext/.su ]; then
      mv -f /system/bin/app_process32_original /system/bin/app_process32 2>/dev/null
      mv -f /system/bin/app_process64_original /system/bin/app_process64 2>/dev/null
      mv -f /system/bin/install-recovery_original.sh /system/bin/install-recovery.sh 2>/dev/null
      cd /system/bin
      if [ -e app_process64 ]; then
        ln -sf app_process64 app_process
      else
        ln -sf app_process32 app_process
      fi
    fi
    rm -rf /system/.pin /system/bin/.ext /system/etc/.installed_su_daemon /system/etc/.has_su_daemon \
    /system/xbin/daemonsu /system/xbin/su /system/xbin/sugote /system/xbin/sugote-mksh /system/xbin/supolicy \
    /system/bin/app_process_init /system/bin/su /cache/su /system/lib/libsupol.so /system/lib64/libsupol.so \
    /system/su.d /system/etc/install-recovery.sh /system/etc/init.d/99SuperSUDaemon /cache/install-recovery.sh \
    /system/.supersu /cache/.supersu /data/.supersu \
    /system/app/Superuser.apk /system/app/SuperSU /cache/Superuser.apk  2>/dev/null
  fi
}

recovery_actions() {
  # TWRP bug fix
  mount -o bind /dev/urandom /dev/random
  # Clear out possible lib paths, let the binaries find them itself
  export LD_LIBRARY_PATH=
  # Temporarily block out all custom recovery binaries/libs
  mv /sbin /sbin_tmp
}

abort() {
  ui_print "$1"
  mv /sbin_tmp /sbin 2>/dev/null
  exit 1
}
