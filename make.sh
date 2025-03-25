#!/bin/bash

URL="${1}"
OS_version="${2}"
GITHUB_WORKSPACE="${3}"
GITHUB_ENV="${4}"
Bottom_URL="${5}"
img_type="${6}"
ext_rw="${7}"

host=$(uname -n)
ORIGN_ZIP_NAME=$(echo ${Bottom_URL} | cut -d"/" -f5 | sed 's/\.zip.*/.zip/')
ZIP_NAME_Transplantation=$(echo ${URL} | cut -d"/" -f5 | sed 's/\.zip.*/.zip/')

Start_Time() {
Start_ns=`date +'%s%N'`
}

End_Time() {
  # Giờ, phút, giây, mili giây, nano giây
  local h min s ms ns End_ns time
  End_ns=$(date +'%s%N')
  time=$(expr $End_ns - $Start_ns)
  [[ -z "$time" ]] && return 0
  ns=${time:0-9}
  s=${time%$ns}
  if [[ $s -ge 10800 ]]; then
    echo -e "\e[1;34m - Thời gian sử dụng lần này $1: ít hơn 100 mili giây \e[0m"
  elif [[ $s -ge 3600 ]]; then
    ms=$(expr $ns / 1000000)
    h=$(expr $s / 3600)
    h=$(expr $s % 3600)
    if [[ $s -ge 60 ]]; then
      min=$(expr $s / 60)
      s=$(expr $s % 60)
    fi
    echo -e "\e[1;34m - Thời gian sử dụng lần này $1: $h giờ $min phút $s giây $ms mili giây \e[0m"
  elif [[ $s -ge 60 ]]; then
    ms=$(expr $ns / 1000000)
    min=$(expr $s / 60)
    s=$(expr $s % 60)
    echo -e "\e[1;34m - Thời gian sử dụng lần này $1: $min phút $s giây $ms mili giây \e[0m"
  elif [[ -n $s ]]; then
    ms=$(expr $ns / 1000000)
    echo -e "\e[1;34m - Thời gian sử dụng lần này $1: $s giây $ms mili giây \e[0m"
  else
    ms=$(expr $ns / 1000000)
    echo -e "\e[1;34m - Thời gian sử dụng lần này $1: $ms mili giây \e[0m"
  fi
}

# Tải gói hệ thống
echo -e "\e[1;33m - Bắt đầu tải gói cần chuyển đổi \e[0m"
Start_Time
aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$GITHUB_WORKSPACE" ""${URL}""
End_Time "Tải gói cần chuyển đổi"
Start_Time
echo -e "\e[1;33m - Bắt đầu tải gói nền \e[0m"
aria2c -x16 -j$(nproc) -U "Mozilla/5.0" -d "$GITHUB_WORKSPACE" ""${Bottom_URL}""
End_Time "Tải gói nền"
# Kết thúc tải gói hệ thống

echo "Giải nén"
sudo chmod 777 "$GITHUB_WORKSPACE"/tools/payload-dumper-go
sudo chmod 777 "$GITHUB_WORKSPACE"/tools/brotli
sudo chmod 777 "$GITHUB_WORKSPACE"/tools/gettype
sudo chmod 777 "$GITHUB_WORKSPACE"/tools/extract.erofs
mkdir -p "$GITHUB_WORKSPACE"/Transplantation
mkdir -p "$GITHUB_WORKSPACE"/Temporary
mkdir -p "$GITHUB_WORKSPACE"/mod
mkdir -p "$GITHUB_WORKSPACE"/modn
mkdir -p "$GITHUB_WORKSPACE"/images
mkdir -p "$GITHUB_WORKSPACE"/images/config
mkdir -p "$GITHUB_WORKSPACE"/zip
Start_Time
7z x "$GITHUB_WORKSPACE"/${ZIP_NAME_Transplantation} -r -o"$GITHUB_WORKSPACE"/mod
7z x "$GITHUB_WORKSPACE"/${ORIGN_ZIP_NAME} -r -o"$GITHUB_WORKSPACE"/modn
rm -rf "$GITHUB_WORKSPACE"/${ZIP_NAME_Transplantation}
rm -rf "$GITHUB_WORKSPACE"/${ORIGN_ZIP_NAME}
End_Time "Giải mã ROM tải xuống"
mkdir -p "$GITHUB_WORKSPACE"/Extra_dir
for i in $("$GITHUB_WORKSPACE"/tools/payload-dumper-go -l "$GITHUB_WORKSPACE"/modn/payload.bin)
do
  echo $i >> "$GITHUB_WORKSPACE"/Local_Partition.txt
done
Start_Time
"$GITHUB_WORKSPACE"/tools/payload-dumper-go -o "$GITHUB_WORKSPACE"/Extra_dir/ "$GITHUB_WORKSPACE"/modn/payload.bin >/dev/null
End_Time "Phân giải bin"
echo " - Đang phân giải vendor"
Start_Time
info=$("$GITHUB_WORKSPACE"/tools/gettype -i "$GITHUB_WORKSPACE"/Extra_dir/vendor.img)
if [ "$info" == "ext" ]; then
  sudo python3 "$GITHUB_WORKSPACE"/tools/imgextractorLinux.py "$GITHUB_WORKSPACE"/Extra_dir/vendor.img "$GITHUB_WORKSPACE"/Temporary >/dev/null
elif [ "$info" == "erofs" ]; then
  sudo "$GITHUB_WORKSPACE"/tools/extract.erofs -i "$GITHUB_WORKSPACE"/Extra_dir/vendor.img -o "$GITHUB_WORKSPACE"/Temporary -x >/dev/null
fi
rm -rf "$GITHUB_WORKSPACE"/Extra_dir/vendor.img
End_Time "Phân giải vendor"
# Lấy bảng phân vùng dưới super
echo " - Đang lấy bảng phân vùng dưới super"
fstab=$(sudo find "$GITHUB_WORKSPACE"/Temporary/vendor/ -name "fstab*")
for file in $fstab
do
  sed '/^#/d;/^\//d;/overlay/d' $file > "$GITHUB_WORKSPACE"/test.txt
  awk '{print $1}' "$GITHUB_WORKSPACE"/test.txt | sort | uniq > "$GITHUB_WORKSPACE"/super.txt
  sed -i '/^$/d' "$GITHUB_WORKSPACE"/super.txt
done
for i in $(cat "$GITHUB_WORKSPACE"/super.txt)
do
  if [ $i = vendor ] || [ $i = mi_ext ];then
    echo -e "\e[1;31m - Bỏ qua phân giải: $i \e[0m"
  else
    Start_Time
    echo " - Đang phân giải $i"
    info=$("$GITHUB_WORKSPACE"/tools/gettype -i "$GITHUB_WORKSPACE"/Extra_dir/$i.img)
    if [ "$info" == "ext" ]; then
      sudo python3 "$GITHUB_WORKSPACE"/tools/imgextractorLinux.py "$GITHUB_WORKSPACE"/Extra_dir/$i.img "$GITHUB_WORKSPACE"/Temporary >/dev/null
    elif [ "$info" == "erofs" ]; then
      sudo "$GITHUB_WORKSPACE"/tools/extract.erofs -i "$GITHUB_WORKSPACE"/Extra_dir/$i.img -o "$GITHUB_WORKSPACE"/Temporary -x >/dev/null
    fi
    rm -rf "$GITHUB_WORKSPACE"/Extra_dir/$i.img
    End_Time "Phân giải $i"
  fi
done
sudo mkdir -p "$GITHUB_WORKSPACE"/images/firmware-update/
sudo mv "$GITHUB_WORKSPACE"/Extra_dir/* "$GITHUB_WORKSPACE"/images/firmware-update/
for i in system product system_ext mi_ext; do
  Start_Time
  echo "Đang phân giải $i"
  "$GITHUB_WORKSPACE"/tools/payload-dumper-go -o "$GITHUB_WORKSPACE"/images/ -p $i "$GITHUB_WORKSPACE"/mod/payload.bin >/dev/null
  info=$("$GITHUB_WORKSPACE"/tools/gettype -i "$GITHUB_WORKSPACE"/images/$i.img)
  if [ "$info" == "ext" ]; then
    sudo python3 "$GITHUB_WORKSPACE"/tools/imgextractorLinux.py "$GITHUB_WORKSPACE"/images/$i.img "$GITHUB_WORKSPACE"/images >/dev/null
  elif [ "$info" == "erofs" ]; then
    sudo "$GITHUB_WORKSPACE"/tools/extract.erofs -i "$GITHUB_WORKSPACE"/images/$i.img -o "$GITHUB_WORKSPACE"/images -x >/dev/null
  fi
  rm -rf "$GITHUB_WORKSPACE"/images/$i.img
  End_Time "Phân giải"
done
rm -rf "$GITHUB_WORKSPACE"/modn/payload.bin
rm -rf "$GITHUB_WORKSPACE"/mod/payload.bin

# Lấy thông tin gói
for Mod_build_per in $(find "$GITHUB_WORKSPACE"/mod/ -type f -name 'metadata' 2>/dev/null | sed 's/^\.\///' | sort)
do
  buildincremental=$(cat $Mod_build_per 2>/dev/null | dos2unix | sed -n "s/.*build-incremental=//p" | head -n 1)
  patchlevel=$(cat $Mod_build_per 2>/dev/null | dos2unix | sed -n "s/.*security-patch-level=//p" | head -n 1)
  predevice=$(cat $Mod_build_per 2>/dev/null | dos2unix | sed -n "s/^pre-device=//p" | head -n 1)
done
for Mod_build_per_kk in $(find "$GITHUB_WORKSPACE"/modn/ -type f -name 'metadata' 2>/dev/null | sed 's/^\.\///' | sort)
do
  buildincremental_n=$(cat $Mod_build_per_kk 2>/dev/null | dos2unix | sed -n "s/.*build-incremental=//p" | head -n 1)
  patchlevel_n=$(cat $Mod_build_per_kk 2>/dev/null | dos2unix | sed -n "s/.*security-patch-level=//p" | head -n 1)
  predevice_n=$(cat $Mod_build_per_kk 2>/dev/null | dos2unix | sed -n "s/^pre-device=//p" | head -n 1)
done

echo "Thay thế các tệp liên quan"
Start_Time
if [[ "${ext_rw}" == "true" && "${img_type}" == "ext" ]]; then
  echo " - Hiện tại đang đóng gói ext4, phân vùng đọc-ghi, kích hoạt tối ưu hóa đọc-ghi"
  Readaw=true
else
  Readaw=false
fi
# Xóa bỏ avb2.0
forbid_avb() {
fstab=$(sudo find $1 -name "fstab*")
if [[ $fstab == "" ]];then
  echo -e "\e[31m     >>>>>>>>Không tìm thấy tệp liên quan, có thể không có kiểm tra avb2.0>>>>>>>>>  \e[0m"
  echo ""
  sleep 5
else
  echo -e "\e[31m     >>>>>>  Đang xóa bỏ, vui lòng chờ....  >>>>>>> \e[0m"
  for file in $fstab; do
    sudo sed -i 's/,avb.*system//g' $file
    sudo sed -i 's/,avb,/,/g' $file
    sudo sed -i 's/,avb=.*a,/,/g' $file
    sudo sed -i 's/,avb_keys.*key//g' $file
    if [[ "${Readaw}" == "true" ]];then
      sudo sed -i "/erofs/d" $file
      sudo sed -i "/mi_ext/d" $file
      sudo sed -i "/overlay/d" $file
    elif [[ "${img_type}" == "ext" ]];then
      sudo sed -i "/erofs/d" $file
    fi
  done
fi
}
forbid_avb "$GITHUB_WORKSPACE"/Temporary/vendor/
# Sửa bảng phân vùng boot
echo "Vá boot"
sudo chmod -R 777 "$GITHUB_WORKSPACE"/tools/magiskboot
magiskboot="$GITHUB_WORKSPACE"/tools/magiskboot
ukiicc="boot"
if grep -q "init_boot" "$GITHUB_WORKSPACE"/Local_Partition.txt; then
  ukiicc+=" init_boot"
fi
if grep -q "vendor_boot" "$GITHUB_WORKSPACE"/Local_Partition.txt; then
  ukiicc+=" vendor_boot"
fi
for kiko in $ukiicc
do
mkdir -p "$GITHUB_WORKSPACE"/boot/out
mv -f "$GITHUB_WORKSPACE"/images/firmware-update/${kiko}.img "$GITHUB_WORKSPACE"/boot/boot.img
cd "$GITHUB_WORKSPACE"/boot
$magiskboot unpack -h "$GITHUB_WORKSPACE"/boot/boot.img 2>&1
if [ -f ramdisk.cpio ]; then
  comp=$($magiskboot decompress ramdisk.cpio 2>&1 | grep -v 'raw' | sed -n 's;.*\[\(.*\)\];\1;p')
  if [ "$comp" ]; then
    mv -f ramdisk.cpio ramdisk.cpio.$comp
    $magiskboot decompress ramdisk.cpio.$comp ramdisk.cpio 2>&1
    if [ $? != 0 ] && $comp --help 2>/dev/null; then
      $comp -dc ramdisk.cpio.$comp > ramdisk.cpio
    fi
  fi
  mkdir -p ramdisk
  chmod 755 ramdisk
  cd ramdisk
  EXTRACT_UNSAFE_SYMLINKS=1 cpio -d -F ../ramdisk.cpio -i 2>&1
  # Tùy chỉnh fstab.qcom trong kernel
  forbid_avb "$GITHUB_WORKSPACE"/boot/
  cd ""$GITHUB_WORKSPACE"/boot/ramdisk"
  find | sed 1d | cpio -H newc -R 0:0 -o -F ../ramdisk-new.cpio
  cd ..
  if [ "$comp" ]; then
    $magiskboot compress=$comp ramdisk-new.cpio 2>&1
    if [ $? != 0 ] && $comp --help 2>/dev/null; then
      $comp -9c ramdisk-new.cpio > ramdisk.cpio.$comp
    fi
  fi
  ramdisk=$(ls ramdisk-new.cpio* 2>/dev/null | tail -n1)
  if [ "$ramdisk" ];then
    cp -f $ramdisk ramdisk.cpio
    case $comp in
      cpio) nocompflag="-n";;
    esac
  fi
else
  echo "Không tìm thấy ramdisk để giải nén..."
fi
$magiskboot repack $nocompflag "$GITHUB_WORKSPACE"/boot/boot.img "$GITHUB_WORKSPACE"/boot/out/boot.img 2>&1
sudo cp -rf "$GITHUB_WORKSPACE"/boot/out/boot.img "$GITHUB_WORKSPACE"/images/firmware-update/${kiko}.img
rm -rf "$GITHUB_WORKSPACE"/boot
cd ..
done
# Thêm tệp mô hình thiết bị
sudo rm -rf "$GITHUB_WORKSPACE"/images/product/etc/device_features/*
sudo cp -f "$GITHUB_WORKSPACE"/Temporary/product/etc/device_features/* "$GITHUB_WORKSPACE"/images/product/etc/device_features/
# Sửa build.prop (ngày xây dựng, số phiên bản, bản vá bảo mật và các sửa đổi khác)
build_time=$(date) && build_utc=$(date -d "$build_time" +%s)
sudo sed -i 's/ro.build.user=[^*]*/ro.build.user=Gặp nhau là duyên/' "$GITHUB_WORKSPACE"/images/system/system/build.prop
datekk=$(echo ${OS_version} | sed 's/OS1/V816/g')
for date_build in $(sudo find "$GITHUB_WORKSPACE"/images/ -type f -name 'build.prop'); do
  sudo sed -i 's/build.date=[^*]*/build.date='"$build_time"'/' "$date_build"
  sudo sed -i 's/build.date.utc=[^*]*/build.date.utc='"$build_utc"'/' "$date_build"
  sudo sed -i 's/build.version.incremental=[^*]*/build.version.incremental='"${datekk}"'/g' "$date_build"
done
if [[ "${img_type}" == "erofs" ]];then
  for erofs_build in $(sudo find "$GITHUB_WORKSPACE"/images/ -type f -name 'build.prop' 2>/dev/null | xargs grep -rl 'ext4' | sed 's/^\.\///' | sort)
  do
    sudo sed -i 's/ext4//g' "$erofs_build"
  done
fi
origin_date=$(sudo cat "$GITHUB_WORKSPACE"/Temporary/vendor/build.prop | grep 'ro.vendor.build.version.incremental=' | cut -d '=' -f 2)
for vendor_build in $(sudo find "$GITHUB_WORKSPACE"/Temporary/ -type f -name "*build.prop")
do
  sudo sed -i 's/'"${origin_date}"'/'"${datekk}"'/' "$vendor_build"
  sudo sed -i 's/build.date=[^*]*/build.date='"$build_time"'/' "$vendor_build"
  sudo sed -i 's/build.date.utc=[^*]*/build.date.utc='"$build_utc"'/' "$vendor_build"
done
rom_security=$(sudo cat "$GITHUB_WORKSPACE"/images/system/system/build.prop | grep 'ro.build.version.security_patch=' | cut -d '=' -f 2)
sudo sed -i 's/ro.vendor.build.security_patch=[^*]*/ro.vendor.build.security_patch='"$rom_security"'/' "$GITHUB_WORKSPACE"/Temporary/vendor/build.prop
rom_name=$(sudo cat "$GITHUB_WORKSPACE"/images/product/etc/build.prop | grep 'ro.product.product.name=' | cut -d '=' -f 2)
sudo sed -i 's/'"$rom_name"'/'"${predevice_n}"'/' "$GITHUB_WORKSPACE"/images/product/etc/build.prop
# Tinh giản một phần
for files in MIGalleryLockscreen MIUIDriveMode MIUIDuokanReader MIUIGameCenter MIUINewHome MIUIYoupin Xinre SmartHome MiShop MiRadio MediaEditor BaiduIME iflytek.inputmethod MIService MIUIEmail
do
  appsui=$(sudo find "$GITHUB_WORKSPACE"/images/product/data-app/ -type d -iname "*${files}*")
  if [ ! -z $appsui ];then
    echo "Tìm thấy thư mục cần tinh giản: $appsui"
    sudo rm -rf $appsui
  fi
done
# Một số dịch vụ liên quan đến thanh toán vân tay trên một số model nằm trong product, cần xóa bỏ
for files in IFAAService MipayService SoterService TimeService EidService
do
  appsui=$(sudo find "$GITHUB_WORKSPACE"/Temporary/product/ -type d -iname "*${files}*")
  if [ -z $appsui ];then
    appsuiif=$(sudo find "$GITHUB_WORKSPACE"/images/product/ -type d -iname "*${files}*")
    if [ ! -z $appsuiif ];then
      echo "Tìm thấy thư mục dịch vụ: $appsuiif"
      sudo rm -rf $appsuiif
    fi
  fi
done
# Khôi phục apex và sửa lỗi có thể gây ra cửa sổ bật lên lỗi nội bộ
for lpo in $(find "$GITHUB_WORKSPACE"/Temporary/system_ext/apex/ -type f -iname "*vndk*")
do
  lpoii=$(echo $lpo | sed "s/Temporary/images/g")
  sudo cp -rf $lpo $lpoii
done
sudo cp -rf "$GITHUB_WORKSPACE"/Temporary/system_ext/etc/vintf/manifest.xml "$GITHUB_WORKSPACE"/images/system_ext/etc/vintf/manifest.xml
# Khôi phục camera
for cameramirm in $(find "$GITHUB_WORKSPACE"/images/product/app/ "$GITHUB_WORKSPACE"/images/product/priv-app/ -type f -iname "*miuicamera*.apk")
do
  RmMod=${cameramirm%/*.apk}
  sudo rm -rf $RmMod
done
for camerami in $(find "$GITHUB_WORKSPACE"/Temporary/product/app/ "$GITHUB_WORKSPACE"/Temporary/product/priv-app/ -type f -iname "*miuicamera*.apk")
do
  kiko=$(echo $camerami | sed "s/Temporary/images/g")
  sudo cp -rf $camerami $kiko
done
# Thêm Overlay mô hình thiết bị
overlay=(DeviceConfig.apk
SettingsRroDeviceSystemUiOverlay.apk
AospFrameworkResOverlay.apk
AospWifiResOverlay.apk
DevicesAndroidOverlay.apk
DevicesOverlay.apk
MiuiFrameworkResOverlay.apk)
for ikk in "${overlay[@]}"; do
  jkk=$(sudo find "$GITHUB_WORKSPACE"/Temporary/product/overlay/ -name "$ikk")
  if [ ! -z $jkk ];then
    echo "Tìm thấy tệp: $jkk"
    jkk_mod=$(echo $jkk | sed "s/Temporary/images/g")
    sudo cp -rf "$jkk" $jkk_mod
  fi
done
# Xác định số phiên bản OS
for OS_build in $(sudo find "$GITHUB_WORKSPACE"/images/ -type f -name 'build.prop' 2>/dev/null | xargs grep -rl 'ro.mi.os.version.incremental' | sed 's/^\.\///' | sort)
do
  echo "Định vị đến tệp: $OS_build"
  sudo sed -i 's/ro.mi.os.version.incremental=[^*]*/ro.mi.os.version.incremental='"$OS_version"'/' "$OS_build"
done
# Khôi phục một số tham số
Find_character() {
iiik=$1
for origin_build in $(find "$GITHUB_WORKSPACE"/Temporary/ -type f -name 'build.prop' 2>/dev/null | xargs grep -rl "${iiik}" | sed 's/^\.\///' | sort)
do
  for Mod_build in $(find "$GITHUB_WORKSPACE"/images/ -type f -name 'build.prop' 2>/dev/null | xargs grep -rl "${iiik}" | sed 's/^\.\///' | sort)
  do
    if [ -z $origin_build ];then
      echo "Định vị đến tệp: $Mod_build"
      sed -i "/$iiik/d" "$Mod_build"
    else
      okrji=$(cat $origin_build 2>/dev/null | dos2unix | sed -n "s/^${iiik}=//p" | head -n 1)
      echo "Định vị đến tệp: $Mod_build"
      sudo sed -i "s/${iiik}=[^*]*/${iiik}=$okrji/" "$Mod_build"
    fi
  done
done
}
Find_character persist.miui.density_v2
Find_character ro.sf.lcd_density
Find_character ro.millet.netlink
Find_character ro.miui.cust_erofs
Find_character ro.miui.preinstall_to_data
Find_character ro.miui.cust_img_path
Find_character ro.miui.product_to_cust
# Sửa đổi thông thường
sudo rm -rf "$GITHUB_WORKSPACE"/Temporary/vendor/recovery-from-boot.p
sudo rm -rf "$GITHUB_WORKSPACE"/Temporary/vendor/bin/install-recovery.sh
sudo unzip -o "$GITHUB_WORKSPACE"/tools/flashtools.zip -d "$GITHUB_WORKSPACE"/images >/dev/null
sudo sed -i "s/mod_device/${predevice_n}/g" "$GITHUB_WORKSPACE"/images/FlashWindows.bat
if [[ "${Readaw}" == "true" ]];then
  iuhy="$GITHUB_WORKSPACE"/images/product/pangu/system
  sudo find "$iuhy" -type d | sed "s|$iuhy|/system/system|g" | sed 's/$/ u:object_r:system_file:s0/' >> "$GITHUB_WORKSPACE"/images/config/system_file_contexts
  sudo find "$iuhy" -type f | sed 's/\./\\./g' | sed "s|$iuhy|/system/system|g" | sed 's/$/ u:object_r:system_file:s0/' >> "$GITHUB_WORKSPACE"/images/config/system_file_contexts
  sudo cp -rf "$GITHUB_WORKSPACE"/images/product/pangu/system/* "$GITHUB_WORKSPACE"/images/system/system/
  sudo rm -rf "$GITHUB_WORKSPACE"/images/product/pangu/system/*
  for mi_ext_build in $(sudo find "$GITHUB_WORKSPACE"/images/mi_ext -type f -name 'build.prop')
  do
    uu_ext=$(cat $mi_ext_build)
    echo "$uu_ext" >> "$GITHUB_WORKSPACE"/images/product/etc/build.prop
  done
  sudo cp -rf "$GITHUB_WORKSPACE"/images/mi_ext/product/* "$GITHUB_WORKSPACE"/images/product/
  sudo cp -rf "$GITHUB_WORKSPACE"/images/mi_ext/system/* "$GITHUB_WORKSPACE"/images/system/system/
  sudo cp -rf "$GITHUB_WORKSPACE"/images/mi_ext/system_ext/* "$GITHUB_WORKSPACE"/images/system_ext/
fi
# Sửa lỗi nhận diện khuôn mặt
for MiuiBiometric in $(sudo find "$GITHUB_WORKSPACE"/Temporary/product/ -type d -iname "*MiuiBiometric*")
do
  sudo cp -rf $MiuiBiometric "$GITHUB_WORKSPACE"/images/product/app/
done
# Sửa độ sáng tự động
sudo rm -rf "$GITHUB_WORKSPACE"/images/product/etc/displayconfig/*
sudo cp -rf "$GITHUB_WORKSPACE"/Temporary/product/etc/displayconfig/* "$GITHUB_WORKSPACE"/images/product/etc/displayconfig/
# Xóa kiểm tra chữ ký a13
APKEditor="java -jar "$GITHUB_WORKSPACE"/tools/APKEditor.jar"
mkdir -p "$GITHUB_WORKSPACE"/sign
echo "Bắt đầu xóa kiểm tra chữ ký a13"
cp -rf "$GITHUB_WORKSPACE"/images/system/system/framework/services.jar "$GITHUB_WORKSPACE"/sign/services.jar
echo "Bắt đầu giải mã ngược"
$APKEditor d -f -i "$GITHUB_WORKSPACE"/sign/services.jar -o "$GITHUB_WORKSPACE"/sign/services 2>&1 1>&/dev/null
fbynr='getMinimumSignatureSchemeVersionForTargetSdk'
find "$GITHUB_WORKSPACE"/sign/services/smali/*/com/android/server/pm/ "$GITHUB_WORKSPACE"/sign/services/smali/*/com/android/server/pm/pkg/parsing/ -maxdepth 1 -type f -name "*.smali" -exec grep -H "$fbynr" {} \; | cut -d ':' -f 1 | while read i ;do
hs=$(grep -n "$fbynr" "$i" | cut -d ':' -f 1)
sz=$(tail -n +"$hs" "$i" | grep -m 1 "move-result" | tr -dc '0-9')
hs1=$(awk -v HS=$hs 'NR>=HS && /move-result /{print NR; exit}' "$i")
hss=$hs
sedsc="const/4 v${sz}, 0x0"
{ sed -i "${hs},${hs1}d" "$i" && sed -i "${hss}i\\${sedsc}" "$i"; } && echo "${i}  Sửa đổi thành công"
done
# Xóa giới hạn a14 về việc cài đặt ứng dụng API dưới 23
mod=$(find "$GITHUB_WORKSPACE"/sign/services/smali/ -type f -iname 'InstallPackageHelper.smali' 2>/dev/null | xargs grep -rl 'App package must target at least SDK version 23, but found ' | sed 's/^\.\///' | sort)
sed -i "s/,\ 0x17/,\ 0x0/g" $mod
echo "Giải mã ngược thành công, bắt đầu biên dịch lại"
$APKEditor b -f -i "$GITHUB_WORKSPACE"/sign/services -o "$GITHUB_WORKSPACE"/sign/services_out.jar 2>&1 1>&/dev/null
cp -rf "$GITHUB_WORKSPACE"/sign/services_out.jar "$GITHUB_WORKSPACE"/images/system/system/framework/services.jar
rm -rf "$GITHUB_WORKSPACE"/sign
if [[ "${Readaw}" == "true" ]];then
  echo " - Hệ thống tùy chỉnh đọc-ghi đã hoàn tất"
fi
sudo rm -rf "$GITHUB_WORKSPACE"/Temporary/product
sudo rm -rf "$GITHUB_WORKSPACE"/Temporary/system
sudo rm -rf "$GITHUB_WORKSPACE"/Temporary/system_ext
sudo cp -rf "$GITHUB_WORKSPACE"/Temporary/* "$GITHUB_WORKSPACE"/images
sudo rm -rf "$GITHUB_WORKSPACE"/Temporary
# Chuẩn hóa dấu vân tay hệ thống
for fingerprint_build in $(sudo find "$GITHUB_WORKSPACE"/images/ -type f -name 'build.prop')
do
uuic=$(echo "$fingerprint_build" | awk -F '/' '{ print $(NF-1) }')
if [ $uuic = etc ]; then
  uuic=$(echo "$fingerprint_build" | awk -F '/' '{ print $(NF-2) }')
fi
rom_brand=$(cat $fingerprint_build | grep 'ro.product.'"$uuic"'.brand=' | cut -d '=' -f 2)
rom_name=$(cat $fingerprint_build | grep 'ro.product.'"$uuic"'.name=' | cut -d '=' -f 2)
rom_device=$(cat $fingerprint_build | grep 'ro.product.'"$uuic"'.device=' | cut -d '=' -f 2)
rom_build_version_release=$(cat $fingerprint_build | grep 'ro.'"$uuic"'.build.version.release=' | cut -d '=' -f 2)
rom_build_id=$(cat $fingerprint_build | grep 'ro.'"$uuic"'.build.id=' | cut -d '=' -f 2)
rom_build_version_incremental=$(cat $fingerprint_build | grep 'ro.'"$uuic"'.build.version.incremental=' | cut -d '=' -f 2)
rom_build_type=$(cat $fingerprint_build | grep 'ro.'"$uuic"'.build.type=' | cut -d '=' -f 2)
rom_build_tags=$(cat $fingerprint_build | grep 'ro.'"$uuic"'.build.tags=' | cut -d '=' -f 2)
if [ ! -z $rom_device ];then
  fingerprint=$(echo "$rom_brand/$rom_name/$rom_device:$rom_build_version_release/$rom_build_id/$rom_build_version_incremental:$rom_build_type/$rom_build_tags")
  sudo sed -i 's|ro.'"$uuic"'.build.fingerprint=[^*]*|ro.'"$uuic"'.build.fingerprint='"$fingerprint"'|g' "$fingerprint_build"
  echo "Dấu vân tay của model trong thư mục hiện tại $uuic là $fingerprint"
fi
done
End_Time "Đặc trưng hóa ROM"

echo "Đóng gói img"
sudo chmod 777 "$GITHUB_WORKSPACE"/tools/lpmake
if [[ "${img_type}" == "erofs" ]];then
sudo chmod 777 "$GITHUB_WORKSPACE"/tools/mkfs.erofs
for i in $(cat "$GITHUB_WORKSPACE"/super.txt);do
  sudo rm -rf "$GITHUB_WORKSPACE"/images/$i/lost+found
  echo "Đang tổng hợp $i"
  sudo python3 "$GITHUB_WORKSPACE"/tools/fspatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config >/dev/null
  sudo python3 "$GITHUB_WORKSPACE"/tools/contextpatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts
  Start_Time
  sudo "$GITHUB_WORKSPACE"/tools/mkfs.erofs -zlz4hc,9 -T 1230768000 --mount-point /$i --fs-config-file "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config --file-contexts "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts "$GITHUB_WORKSPACE"/images/$i.img "$GITHUB_WORKSPACE"/images/$i 3>&2 2>/dev/null >/dev/null
  End_Time "Đóng gói"
done
elif [[ "${img_type}" == "ext" ]];then
  sudo chmod 777 "$GITHUB_WORKSPACE"/tools/mke2fs
  sudo chmod 777 "$GITHUB_WORKSPACE"/tools/e2fsdroid
  img_free() {
    size_free="$(tune2fs -l "$GITHUB_WORKSPACE"/images/${i}.img | awk '/Free blocks:/ { print $3 }')"
    size_free="$(echo "$size_free / 4096 * 1024 * 1024" | bc)"
    if [[ $size_free -ge 1073741824 ]]; then
      File_Type=$(awk "BEGIN{print $size_free/1073741824}")G
    elif [[ $size_free -ge 1048576 ]]; then
      File_Type=$(awk "BEGIN{print $size_free/1048576}")MB
    elif [[ $size_free -ge 1024 ]]; then
      File_Type=$(awk "BEGIN{print $size_free/1024}")kb
    elif [[ $size_free -le 1024 ]]; then
      File_Type=${size_free}b
    fi
    echo -e "\e[1;33m - Dung lượng còn lại của ${i}.img: $File_Type \e[0m"
  }
  for i in $(cat "$GITHUB_WORKSPACE"/super.txt); do
    eval "$i"_size_orig=$(sudo du -sb "$GITHUB_WORKSPACE"/images/$i | awk {'print $1'})
    if [[ "$(eval echo "$"$i"_size_orig")" -lt "1048576" ]]; then
      size=1048576
    elif [[ "$(eval echo "$"$i"_size_orig")" -lt "104857600" ]]; then
      size=$(echo "$(eval echo "$"$i"_size_orig") * 15 / 10 / 4096 * 4096" | bc)
    elif [[ "$(eval echo "$"$i"_size_orig")" -lt "1073741824" ]]; then
      size=$(echo "$(eval echo "$"$i"_size_orig") * 108 / 100 / 4096 * 4096" | bc)
    else
      size=$(echo "$(eval echo "$"$i"_size_orig") * 103 / 100 / 4096 * 4096" | bc)
    fi
    eval "$i"_size=$size
  done
  system_size=$(echo "$system_size * 4096 / 4096 / 4096" | bc)
  vendor_size=$(echo "$vendor_size * 4096 / 4096 / 4096" | bc)
  product_size=$(echo "$product_size * 4096 / 4096 / 4096" | bc)
  odm_size=$(echo "$odm_size * 4096 / 4096 / 4096" | bc)
  system_ext_size=$(echo "$system_ext_size * 4096 / 4096 / 4096" | bc)
  mi_ext_size=$(echo "$mi_ext_size * 4096 / 4096 / 4096" | bc)
  for i in $(cat "$GITHUB_WORKSPACE"/super.txt); do
    mkdir -p "$GITHUB_WORKSPACE"/images/$i/lost+found
    sudo touch -t 200901010000.00 "$GITHUB_WORKSPACE"/images/$i/lost+found
  done
  for i in $(cat "$GITHUB_WORKSPACE"/super.txt); do
    echo -e "\e[1;31m - Đang tạo: $i \e[0m"
    sudo python3 "$GITHUB_WORKSPACE"/tools/fspatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config
    sudo python3 "$GITHUB_WORKSPACE"/tools/contextpatch.py "$GITHUB_WORKSPACE"/images/$i "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts
    eval "$i"_inode=$(sudo cat "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config | wc -l)
    eval "$i"_inode=$(echo "$(eval echo "$"$i"_inode") + 8" | bc)
    "$GITHUB_WORKSPACE"/tools/mke2fs -O ^has_journal -L $i -I 256 -N $(eval echo "$"$i"_inode") -M /$i -m 0 -t ext4 -b 4096 "$GITHUB_WORKSPACE"/images/$i.img $(eval echo "$"$i"_size") || false
    Start_Time
    if [[ "${ext_rw}" == "true" ]]; then
      sudo "$GITHUB_WORKSPACE"/tools/e2fsdroid -e -T 1230768000 -C "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config -S "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts -f "$GITHUB_WORKSPACE"/images/$i -a /$i "$GITHUB_WORKSPACE"/images/$i.img || false
    else
      sudo "$GITHUB_WORKSPACE"/tools/e2fsdroid -e -T 1230768000 -C "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config -S "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts -f "$GITHUB_WORKSPACE"/images/$i -a /$i -s "$GITHUB_WORKSPACE"/images/$i.img || false
    fi
    End_Time "Đóng gói ext4"
    if [[ "${ext_rw}" != "true" ]];then
      resize2fs -f -M "$GITHUB_WORKSPACE"/images/$i.img
    fi
    img_free
    if [[ $i == mi_ext ]]; then
      sudo rm -rf "$GITHUB_WORKSPACE"/images/$i
      continue
    fi
    size_free=$(tune2fs -l "$GITHUB_WORKSPACE"/images/$i.img | awk '/Free blocks:/ { print $3}')
    # Đóng gói lần thứ hai (không để lại dung lượng trống)
    if [[ "$size_free" != 0 && "${Readaw}" != "true" ]]; then
      size_free=$(echo "$size_free * 4096" | bc)
      eval "$i"_size=$(du -sb "$GITHUB_WORKSPACE"/images/$i.img | awk {'print $1'})
      eval "$i"_size=$(echo "$(eval echo "$"$i"_size") - $size_free" | bc)
      eval "$i"_size=$(echo "$(eval echo "$"$i"_size") * 4096 / 4096 / 4096" | bc)
      sudo rm -rf "$GITHUB_WORKSPACE"/images/$i.img
      echo -e "\e[1;31m - Tạo lần thứ hai: $i \e[0m"
      "$GITHUB_WORKSPACE"/tools/mke2fs -O ^has_journal -L $i -I 256 -N $(eval echo "$"$i"_inode") -M /$i -m 0 -t ext4 -b 4096 "$GITHUB_WORKSPACE"/images/$i.img $(eval echo "$"$i"_size") || false
      Start_Time
      if [[ "${ext_rw}" == "true" ]]; then
        sudo "$GITHUB_WORKSPACE"/tools/e2fsdroid -e -T 1230768000 -C "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config -S "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts -f "$GITHUB_WORKSPACE"/images/$i -a /$i "$GITHUB_WORKSPACE"/images/$i.img || false
      else
        sudo "$GITHUB_WORKSPACE"/tools/e2fsdroid -e -T 1230768000 -C "$GITHUB_WORKSPACE"/images/config/"$i"_fs_config -S "$GITHUB_WORKSPACE"/images/config/"$i"_file_contexts -f "$GITHUB_WORKSPACE"/images/$i -a /$i -s "$GITHUB_WORKSPACE"/images/$i.img || false
      fi
      End_Time "Đóng gói lần thứ hai $i.img"
      resize2fs -f -M "$GITHUB_WORKSPACE"/images/$i.img
    fi
    sudo rm -rf "$GITHUB_WORKSPACE"/images/$i
  done
fi
sudo rm -rf "$GITHUB_WORKSPACE"/images/config
Start_Time

uki_size=0
argvs="--metadata-size 65536 --super-name super --block-size 4096 "
for i in $(cat "$GITHUB_WORKSPACE"/super.txt)
do
  if [[ "${Readaw}" == "true" ]] && [[ $i = mi_ext ]];then
    echo -e "\e[1;31m - Hiện tại đang đóng gói đọc-ghi, bỏ qua đóng gói: $i \e[0m"
  else
    img_size=$(du -sb "$GITHUB_WORKSPACE"/images/$i.img | awk {'print $1'})
    argvs+="--partition "$i"_a:readonly:$img_size:qti_dynamic_partitions_a --image "$i"_a="$GITHUB_WORKSPACE"/images/${i}.img --partition "$i"_b:readonly:0:qti_dynamic_partitions_b "
    uki_size=$(echo "$uki_size + $img_size" | bc)
  fi
done
uki_size=$(echo "$uki_size + 104857600" | bc)
argvs+="--device super:$uki_size "
argvs+="--metadata-slots 3 "
argvs+="--group qti_dynamic_partitions_a:$uki_size "
argvs+="--group qti_dynamic_partitions_b:$uki_size "
argvs+="--virtual-ab "
argvs+="-F --output "$GITHUB_WORKSPACE"/images/super.img"
"$GITHUB_WORKSPACE"/tools/lpmake $argvs

End_Time "Đóng gói super"
for i in $(cat "$GITHUB_WORKSPACE"/super.txt);do
  rm -rf "$GITHUB_WORKSPACE"/images/$i.img
  rm -rf "$GITHUB_WORKSPACE"/images/$i
done

echo -e "\e[1;31m - Bắt đầu nén super \e[0m"
Start_Time
zstd -9 -f -q "$GITHUB_WORKSPACE"/images/super.img -o "$GITHUB_WORKSPACE"/images/super.zst --rm >/dev/null
End_Time "Nén super"

comm -32 <(sort "$GITHUB_WORKSPACE"/Local_Partition.txt) <(sort "$GITHUB_WORKSPACE"/super.txt) > "$GITHUB_WORKSPACE"/ol.txt
for ki in $(tac "$GITHUB_WORKSPACE"/ol.txt)
do
  sed -i "/ui_print \"- 开始刷入系统底层\"/a package_extract_file \"firmware-update\/${ki}.img\" \"\/dev\/block\/bootdevice\/by-name\/${ki}\"" "$GITHUB_WORKSPACE"/images/META-INF/com/google/android/update-binary
  sed -i "/echo\.正在刷入系统底层/a bin\\\Windows\\\fastboot flash ${ki}_ab firmware-update\/${ki}.img" "$GITHUB_WORKSPACE"/images/FlashWindows.bat
done
sudo find "$GITHUB_WORKSPACE"/images/ -exec touch -t 200901010000.00 {} \;

Start_Time
sudo 7z a "$GITHUB_WORKSPACE"/zip/miui_LMI_${datekk}.zip "$GITHUB_WORKSPACE"/images/*
End_Time "Tổng hợp gói flash"
sudo rm -rf "$GITHUB_WORKSPACE"/images
md5=$(md5sum "$GITHUB_WORKSPACE"/zip/miui_LMI_${datekk}.zip)
zipmd5=${md5:0:10}
mod_rom_device=$(echo ${predevice_n} | tr [:lower:] [:upper:])
# Tùy chỉnh tên gói ROM
rom_name="miui_"
if echo "${OS_version}" | grep -q "OS"; then
  rom_name+="${mod_rom_device}_"
else
  rom_name+="${mod_rom_device}PRE_"
fi
rom_name+="${OS_version}_${zipmd5}_14.0_2in1"
if [[ "${img_type}" == "erofs" ]];then
  rom_name+="_EROFS"
fi
rom_name+=".zip"
sudo mv "$GITHUB_WORKSPACE"/zip/miui_LMI_${datekk}.zip "$GITHUB_WORKSPACE"/zip/"${rom_name}"
echo -n "Tên gói mới là: ${rom_name}"
echo "NEW_PACKAGE_NAME=$rom_name" >> $GITHUB_ENV
echo "MD5=${md5:0:32}" >> $GITHUB_ENV
echo "Cấp độ bản vá bảo mật: $patchlevel" >> "$GITHUB_WORKSPACE"/file.log
echo "Dựa trên ${predevice}_${buildincremental} để xây dựng chuyển đổi" >> "$GITHUB_WORKSPACE"/file.log
echo "Sử dụng gói nền ${predevice_n}_${buildincremental_n}" >> "$GITHUB_WORKSPACE"/file.log
echo "Tên gói là $rom_name" >> "$GITHUB_WORKSPACE"/file.log

sudo mv "$GITHUB_WORKSPACE"/zip/miui_LMI_${datekk}.zip "$GITHUB_WORKSPACE"/zip/"${rom_name}"
echo -n "Tên gói mới là: ${rom_name}"
echo "NEW_PACKAGE_NAME=$rom_name" >> $GITHUB_ENV
echo "MD5=${md5:0:32}" >> $GITHUB_ENV
echo "Cấp độ bản vá bảo mật: $patchlevel" >> "$GITHUB_WORKSPACE"/file.log
echo "Dựa trên ${predevice}_${buildincremental} để xây dựng chuyển đổi" >> "$GITHUB_WORKSPACE"/file.log
echo "Sử dụng gói nền ${predevice_n}_${buildincremental_n}" >> "$GITHUB_WORKSPACE"/file.log
echo "Tên gói là $rom_name" >> "$GITHUB_WORKSPACE"/file.log

# Đường dẫn đến tệp ROM đã tạo
ROM_FILE="$GITHUB_WORKSPACE/zip/${rom_name}"

# URL API của Gofile.io
GOFILE_API_URL="https://store1.gofile.io/uploadFile"

# Hàm để tải tệp lên Gofile
upload_to_gofile() {
  echo -e "\e[1;33m - Bắt đầu tải ${rom_name} lên Gofile.io \e[0m"
  Start_Time

  # Sử dụng curl để tải tệp lên Gofile.io
  response=$(curl -s -F "file=@${ROM_FILE}" "${GOFILE_API_URL}")

  # Kiểm tra phản hồi từ Gofile
  if echo "$response" | grep -q '"status":"ok"'; then
    # Trích xuất URL tải xuống từ phản hồi JSON
    download_url=$(echo "$response" | grep -o '"downloadPage":"[^"]*' | cut -d'"' -f4)
    echo -e "\e[1;32m - Tải lên thành công! URL tải xuống: $download_url \e[0m"
    
    # Ghi URL vào file log và GITHUB_ENV để sử dụng sau
    echo "URL tải xuống: $download_url" >> "$GITHUB_WORKSPACE/file.log"
    echo "DOWNLOAD_URL=$download_url" >> "$GITHUB_ENV"
  else
    echo -e "\e[1;31m - Lỗi khi tải lên Gofile.io: $response \e[0m"
    exit 1
  fi

  End_Time "Tải lên Gofile.io"
}

# Gọi hàm tải lên
upload_to_gofile

# Hiển thị thông tin cuối cùng
echo -e "\e[1;34m - Quá trình hoàn tất! Tệp ${rom_name} đã được tải lên Gofile.io. \e[0m"