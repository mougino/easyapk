easyapk
=======

easyapk is a cross-platform command-line executable, written in FreeBasic, that allows to alter and re-compile an Android app (*.apk).
easyapk takes an XML as input that describes the source APK, the modifications to be done, the target, and it produces an APK as output.
easyapk source code is released under a GNU GPL v3 licence as per the attached file "gpl.txt". The licence can be found at https://www.gnu.org/licenses/gpl.txt

easyapk needs the following open source companion tools to be in the same folder where it is installed:

* The Android Asset Packaging Tool (aapt) part of The Android Software Development Kit, © Google Open Source software licensed here: http://developer.android.com/sdk/terms.html
* The Android Debug Bridge tool (ADB) part of The Android Software Development Kit, © Google Open Source software licenced here: http://developer.android.com/sdk/terms.html
* apktool an Open Source tool for reverse engineering Android apk files, under Apache License 2.0 website: https://code.google.com/p/android-apktool/
* keytool a key and certificate management utility part of Java SE, © Oracle license here: http://www.oracle.com/technetwork/java/javase/terms/license/
* openssl an SSL/TLS Open Source toolkit © The OpenSSL Project, under a BSD-style license available here: http://www.openssl.org/source/license.html
* signapk an Open Source application to sign Android Packages (.apk) under a GNU GPL v2 license website: https://code.google.com/p/signapk/
* zipalign an archive alignment tool that provides important optimization to Android application (.apk) files, part of The Android Software Development Kit, © Google Open Source software licensed here: http://developer.android.com/sdk/terms.html
* splitpem an utility to split the certificate and private key from a Privacy Enhanced Email file (PEM), © Nicolas Mougin under a CC BY-NC-ND 3.0 license http://creativecommons.org/licenses/by-nc-nd/3.0/


## Installing
Just copy "easyapk.exe" and all its needed tools in a same folder.

## Building
easyapk can been compiled with FreeBASIC Compiler Version 0.90.1 (07-17-2013) or any other newer version.
easyapk has three dependencies in the form of INC files: "str_utils.inc", "file_utils.inc" and "xml_utils.inc".
These files and the resource file "easyapk.rc" + icon all need to be placed in the same folder to be compiled.

## Usage
`easyapk [-v] app_desc_input.xml`

Where "app_desc_input.xml" xml architecture is as follows:

### List of xml tags:

- very first line:
```xml
	<?xml version="1.0" encoding="utf-8"?>
```

- tags that sit on 1 line only:
```xml
	<set_local_folder path="D:\RFO-BASIC! QuickAPK\" />
	<copy_file source="rfo-basic/source/Bwing.bas" target="assets/Bwing/source" />
	<set_app_icon source="Z:\RFO-BASIC!\!Bwing\graphics\char1.png" />
	<set_attribute_value tag='android:key="font_pref"' attribute="android:defaultValue" value="Medium" />
	<remove_tag tag="intent-filter" contains='android:pathPattern=".*\\.bas"' />
	<reset_permissions />
	<add_permission name="WRITE_EXTERNAL_STORAGE" />
	<change_package old="com.rfo.basic" new="rfo.mougino.bwing" />
	<sign_with certificate="rfobasic.jks" password="12345678" />
```

- opening and closing tags, with content between:
```xml
	<use_base_apk source="tools\Basic.apk" target="D:\A\B\C\Bwing.apk">   ...   </use_base_apk>
	<modify_xml_values type="string">   ...   </modify_xml_values>
	<modify_xml source="res/values/strings.xml">   ...   </modify_xml>
	<modify_manifest>   ...   </modify_manifest>
```

- dual:
```xml
	<set_xml_value name="color1" value="0xffffff" />
	<set_xml_value name="load_file_names"> ... </set_xml_value>
```
