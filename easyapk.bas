CONST EXE = "Easy APK"
CONST VER = "v0.7"

#INCLUDE ONCE "str_utils.inc"
#INCLUDE ONCE "file_utils.inc"
#INCLUDE ONCE "xml_utils.inc"

SUB ThrowError (errcod AS INTEGER, errstr AS STRING)
    errstr = RTRIM(errstr, LF) + LF
    COLOR 12, 0
    WHILE INSTR(errstr, LF)
        PRINT LEFT(errstr, INSTR(errstr, LF) - 1)
        COLOR 7, 0
        errstr = MID(errstr, INSTR(errstr, LF) + 1) 
    WEND
    END(errcod) ' leave TempPath intact for user to be able to investigate
END SUB

PRINT STRING(79, "-")
PRINT EXE + " " + VER
VAR ti = TIMER

DIM AS STRING path, TempPath, file()
path = ENVIRON("PATH")
SETENVIRON("PATH=" + EXEPATH + PATH_SEP + path) ' Set easyapk.exe's path in SETENV to be able to use all the companion tools
TempPath = RTRIM(ENVIRON("TEMP"), SLASH) + SLASH

' Check existence of XML file passed in the command line
DIM xml AS STRING
DIM AS INTEGER verbose, warning
xml = TRIM(COMMAND(-1), ANY " " + DQ)
IF LEFT(LCASE(xml), 3) = "-v " THEN verbose = 1 : xml = MID(xml, 4)
IF TRIM(xml) = "" THEN
    PRINT "Error: no argument passed to program - Usage: easyapk [-v] build_script.xml"
    END(1)
ELSEIF NOT FILEEXIST(xml) THEN
    PRINT "Error: file passed as argument does not exist"
    END(1)
ENDIF
path = FILEPATH(xml) + SLASH   

' Check existence of companion tools
DIM i AS LONG
DIM tool(1 TO 16) AS STRING
#IFDEF __FB_WIN32__ ' Windows tools:
    i += 1 : tool(i) = "aapt.exe"        ' 1 <----Google SDK recompiler
    i += 1 : tool(i) = "apktool.jar"     ' 2 <-|APK decompiler/
    i += 1 : tool(i) = "apktool.bat"     ' 3   |recompiler + script
    i += 1 : tool(i) = "convert.exe"     ' 4 <----mougino's converter
    i += 1 : tool(i) = "keytool.exe"     ' 5 <-|Java KeyStore dumper
    i += 1 : tool(i) = "jli.dll"         ' 6   |+ its necessary dll
    i += 1 : tool(i) = "openssl.exe"     ' 7 <----|Crypto utility
    i += 1 : tool(i) = "ssleay32.dll"    ' 8      |tool + its two
    i += 1 : tool(i) = "libeay32.dll"    ' 9      |needed dlls
    i += 1 : tool(i) = "signapk.jar"     ' 10 <-|Signer tool
    i += 1 : tool(i) = "signapk.bat"     ' 11   |+ its script
    i += 1 : tool(i) = "cert.x509.pem"   ' 12 <----|Default certificate
    i += 1 : tool(i) = "key.pk8"         ' 13      |+ its public key
    i += 1 : tool(i) = "zipalign.exe"    ' 14 <-Alignment tool
    i += 1 : tool(i) = "pbe_md5_des.jar" ' 15 <-|Encryption tool
    i += 1 : tool(i) = "pbe_md5_des.bat" ' 15   |+ its script
#ELSE ' Linux tools:
    i += 1 : tool(i) = "aapt"            ' 1
    i += 1 : tool(i) = "apktool.jar"     ' 2
    i += 1 : tool(i) = "apktool.sh"      ' 3
    i += 1 : tool(i) = "jli.dll"         ' 4
    i += 1 : tool(i) = "keytool"         ' 5
    i += 1 : tool(i) = "libeay32.dll"    ' 6
    i += 1 : tool(i) = "openssl"         ' 7
    i += 1 : tool(i) = "signapk.jar"     ' 8
    i += 1 : tool(i) = "signapk.sh"      ' 9 
    i += 1 : tool(i) = "ssleay32.dll"    ' 10
    i += 1 : tool(i) = "zipalign"        ' 11
    i += 1 : tool(i) = "cert.x509.pem"   ' 12
    i += 1 : tool(i) = "key.pk8"         ' 13
    i += 1 : tool(i) = "convert"         ' 14
    i += 1 : tool(i) = "pbe_md5_des.jar" ' 15
    i += 1 : tool(i) = "pbe_md5_des.sh"  ' 16
#ENDIF 
FOR i = LBOUND(tool) TO UBOUND(tool)
    IF NOT FILEEXIST(EXEPATH + SLASH + tool(i)) THEN ThrowError 2, "Fatal error: tool " + DQ + tool(i) + DQ + _
        " is missing" + LF + "Please do a full reinstallation from http://mougino.free.fr/software"
NEXT

' Open and bufferize XML input file
DIM AS STRING xmlBuf, apk, buffer, tag, src, tgt, cmd, typ, nam, vlu, attr, old, dst, jks, pwd
xmlBuf = TRIM(LoadFile(xml), ANY WHITESPACE)
xmlBuf = STRREPLACE(xmlBuf, CRLF, LF)
VAR nbl = TALLY(xmlBuf, LF) + 1
IF verbose THEN PRINT "Input file is " + DQ + xml + DQ + " (" + STR(nbl+1) + " lines)"
tag = XmlNextTag(xmlBuf)
IF INSTR(LCASE(tag), "<?xml ") <> 1 THEN ThrowError 3, "Error: malformed input XML - does not start with tag <?xml ...>"
TempPath += TimeStamp() + SLASH
MKDIR TempPath
FILECOPY xml, TempPath + FILENAME(xml)

' Parse XML input file !
DO WHILE LEN(xmlBuf)
    tag = XmlNextTag(xmlBuf)
    tag = STRREPLACE(tag, CHR(9), " ") ' Replace all tabs with spaces in current tag

    ' Tag is of the type <set_local_folder path="D:\RFO-BASIC! QuickAPK\" />
    '----------------------------------------------------------------------------------------------------------------
    IF INSTR(LCASE(tag), "<set_local_folder ") = 1 THEN
        path = InlineContent(tag, "path")
        IF LEN(path) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_local_folder>: attribute 'path' does not exist or is empty"
        path = STRREPLACE(path, ANTISLASH, SLASH) ' make destination path relevant to current system (Unix/Windows)
        path = RTRIM(path, SLASH) + SLASH
        IF NOT FOLDEREXIST(path) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_local_folder>: path " + DQ + path + DQ + " does not exist"
        IF verbose THEN PRINT "Setting local folder to " + DQ + path + DQ

    ' Tag is of the type <use_base_apk source="tools\Basic.apk" target="D:\A\B\C\D\Bwing.apk">
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<use_base_apk ") = 1 THEN
        ' Identify and do the controls on the base APK
        src = InlineContent(tag, "source")
        IF LEN(src) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <use_base_apk>: attribute 'source' does not exist or is empty"
        IF RIGHT(LCASE(src), 4) <> ".apk" THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <use_base_apk>: base APK must have the extension .apk"
        CHDIR path ' change back to path defined in <set_local_folder>
        IF NOT FILEEXIST(src) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <use_base_apk>: base APK " + DQ + src + DQ + " does not exist"

        ' Identify target APK, make sure path of target APK exists and is writable
        apk = InlineContent(tag, "target")
        IF LEN(apk) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <use_base_apk>: attribute 'target' does not exist or is empty"
        IF RIGHT(LCASE(apk), 4) <> ".apk" THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <use_base_apk>: target APK must have the extension .apk"
        CHDIR path
        SaveFile apk + ".test", "nothing" ' Test if we can write in the target folder
        IF NOT FILEEXIST(apk + ".test") THEN ThrowError 3, "Error: unable to create APK in target folder " + DQ + FILEPATH(apk) + DQ + ". Running program as admin may solve this"
        KILL apk + ".test" ' We were able to write a test file -> remove it
        IF verbose THEN PRINT "Target APK is " + DQ + apk + DQ

        ' Base APK is ok --> set Temp folder for this session and decompile the base APK in it
        IF verbose THEN PRINT "Using temporary folder " + DQ + TempPath + DQ
        FILECOPY src, TempPath + FILENAME(src)
        CHDIR TempPath
        IF verbose THEN PRINT "Decompiling APK with "; : COLOR 10, 0 : PRINT "apktool"; : COLOR 7, 0 : PRINT "..."
        cmd = "apktool d " + FILENAME(src)
        IF verbose = 0 THEN cmd += " > apktool.log 2>&1"
        VAR t0 = TIMER
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        VAR t1 = TIMER - t0
        IF NOT FOLDEREXIST(TempPath + LEFT(FILENAME(src), LEN(FILENAME(src)) - 4)) THEN
            cmd = "Failure when trying to decompile"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + ISOLATE(LoadFile("apktool.log"), "error")
            ThrowError 4, cmd
        ELSEIF verbose THEN
            PRINT "APK has been decompiled to folder " + DQ + TempPath + DQ + " (took " + STR(INT(t1)) + "s)"
        ELSE
            KILL "apktool.log"
        ENDIF
        KILL FILENAME(src) ' delete temporary base APK
        TempPath += LEFT(FILENAME(src), LEN(FILENAME(src)) - 4) + SLASH

    ' Tag is of the type <copy_file source="rfo-basic/source/Bwing.bas" target="assets/Bwing/source" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<copy_file ") = 1 THEN
        CHDIR path ' change to path defined in <set_local_folder>
        src = InlineContent(tag, "source")
        IF LEN(src) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <copy_file>: attribute 'source' does not exist or is empty"
        src = STRREPLACE(src, ANTISLASH, SLASH) ' make destination path relevant to current system (Unix/Windows)
        IF NOT FILEEXIST(src) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <copy_file>: source file " + DQ + src + DQ + " does not exist"
        tgt = InlineContent(tag, "target")
        IF LEN(tgt) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <copy_file>: attribute 'target' does not exist or is empty"
        tgt = TempPath + STRREPLACE(tgt, ANTISLASH, SLASH) ' User should always use a relative path e.g. "assets/Bwing/source"
        IF INSTR(RIGHT(tgt, 5), ".") = 0 THEN tgt = RTRIM(tgt, SLASH) + SLASH + FILENAME(src) ' User gave only a folder --> append the filename to it
        IF NOT FOLDEREXIST(FILEPATH(tgt)) THEN
            IF verbose THEN
                COLOR 14, 0
                PRINT "Warning line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <copy_file>: destination folder " + _
                    DQ + REMOVE(FILEPATH(tgt), TempPath) + DQ + " does not exist -> it will be created"
                COLOR 7, 0
            ENDIF
            MakeSureDirectoryPathExists FILEPATH(tgt)
        ENDIF
        IF verbose THEN PRINT "Copying " + DQ + src + DQ + " to " + DQ + tgt + DQ
        FILECOPY src, tgt
        tgt = "" ' To handle next closing tags </modify_xml> and </modify_xml_values>

    ' Tag is of the type <encrypt_file source="assets/Bwing/source" password="123456" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<encrypt_file ") = 1 THEN
        CHDIR TempPath ' change to temporary folder
        src = InlineContent(tag, "source")
        IF LEN(src) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <encrypt_file>: attribute 'source' does not exist or is empty"
        src = TempPath + STRREPLACE(src, ANTISLASH, SLASH) ' User should always use a relative path e.g. "assets/Bwing/source"
        IF NOT FILEEXIST(src) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <encrypt_file>: source file " + DQ + src + DQ + " does not exist"
        pwd = InlineContent(tag, "password") ' user password
        IF LEN(pwd) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <encrypt_file>: attribute 'password' does not exist or is empty"
        IF verbose THEN PRINT "Encrypting " + DQ + src + DQ + " with "; : COLOR 10, 0 : PRINT "pbe_md5_des"; : COLOR 7, 0 : PRINT "..."
        cmd = "pbe_md5_des encrypt " + DQ + pwd + DQ + " " + DQ + src + DQ + " " + DQ + TempPath + "temp.enc" + DQ
        IF verbose = 0 THEN cmd += " > keytool.log 2>&1"
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        IF NOT FILEEXIST(TempPath + "temp.enc") THEN
            cmd = "Failure when trying to encrypt the file " + DQ + src + DQ
            ThrowError 4, cmd
        ENDIF
        KILL src
        NAME TempPath + "temp.enc", src

    ' Tag is of the type <delete_file source="rfo-basic/source/Bwing.bas" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<delete_file ") = 1 THEN
        CHDIR path ' change to path defined in <set_local_folder>
        src = InlineContent(tag, "source")
        IF LEN(src) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <delete_file>: attribute 'source' does not exist or is empty"
        src = TempPath + STRREPLACE(src, ANTISLASH, SLASH) ' User should always use a relative path e.g. "assets/Bwing/source/Bwing.bas"
        IF NOT FILEEXIST(src) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <delete_file>: source file " + DQ + src + DQ + " does not exist"
        IF verbose THEN PRINT "Deleting " + DQ + src + DQ
        KILL src

    ' Tag is of the type <set_app_icon source="Z:\RFO-BASIC!\!Bwing\graphics\char1.png" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<set_app_icon ") = 1 THEN
        src = InlineContent(tag, "source")
        IF LEN(src) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_app_icon>: attribute 'source' does not exist or is empty"
        src = STRREPLACE(src, ANTISLASH, SLASH) ' make destination path relevant to current system (Unix/Windows)
        IF NOT FILEEXIST(src) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_app_icon>: source image " + DQ + src + DQ + " does not exist"
        CHDIR path ' change to path defined in <set_local_folder>
        REDIM icodir(1 TO 6) AS STRING   : icodir(1)="xxxh" : icodir(2)="xxh" : icodir(3)="xh" : icodir(4)="h" : icodir(5)="m" : icodir(6)="l"
        REDIM icosiz(1 TO 6) AS UINTEGER : icosiz(1)=192    : icosiz(2)=144   : icosiz(3)=96   : icosiz(4)=72  : icosiz(5)=48  : icosiz(6)=36
        FOR i = 1 TO 6
            dst = TempPath + "res" + SLASH + "drawable-" + icodir(i) + "dpi"
            MakeSureDirectoryPathExists dst
            KILL dst + SLASH + "icon.png"
            IF verbose THEN PRINT "Creating drawable-" + icodir(i) + "dpi/icon.png with "; : COLOR 10, 0 : PRINT "mougino 'convert'"; : COLOR 7, 0 : PRINT "..."
            cmd = "convert " + DQ + src + DQ + " -resize " + STR(icosiz(i)) + "x" + STR(icosiz(i)) + " " + DQ + dst + SLASH + "icon.png" + DQ
            IF verbose = 0 THEN cmd += " > convert.log 2>&1"
            COLOR 10, 0 : SHELL cmd : COLOR 7, 0
            IF NOT FILEEXIST(dst + SLASH + "icon.png") THEN
                cmd = "Failure when trying to create " + dst + SLASH + "icon.png"
                IF verbose = 0 THEN cmd += " - Detail:" + LF + LoadFile("convert.log")
                ThrowError 4, cmd
            ELSEIF verbose = 0 THEN
                KILL "convert.log"
            ENDIF
        NEXT

    ' Tag is of the type <modify_xml_values type="string">
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<modify_xml_values ") = 1 THEN
        typ = InlineContent(tag, "type")
        IF LEN(typ) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <modify_xml_values>: attribute 'type' does not exist or is empty"
        tgt = TempPath + "res" + SLASH + "values" + SLASH + typ + "s.xml"
        IF NOT FILEEXIST(tgt) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <modify_xml_values>: unknown value " + _
            DQ + typ + DQ + " for attribute 'type'" + LF + "Correct values are: string, integer, bool, array, color, id..."
        IF verbose THEN COLOR 11, 0 : PRINT "Opening XML file " + DQ + tgt + DQ + " for modification" : COLOR 7, 0
        buffer = TRIM(LoadFile(tgt), ANY WHITESPACE)

    ' Tag is of the type </modify_xml_values>
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "</modify_xml_values>") = 1 THEN
        IF LEN(tgt) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected closing tag </modify_xml_values>"
        IF verbose THEN COLOR 11, 0 : PRINT "Saving changes to XML file " + DQ + tgt + DQ : COLOR 7, 0
        SaveFile tgt, buffer
        tgt = "" ' To handle next closing tags </modify_xml>, </modify_xml_values> and </modify_manifest>
        typ = "" ' To handle next closing tag </modify_xml_values>

    ' Tag is of the type <set_xml_value name="version" value="0.1" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<set_xml_value ") = 1 THEN
        IF LEN(tgt) = 0 OR LEN(typ) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected tag <set_xml_value>: must be inside a <modify_xml_values>"
        nam = InlineContent(tag, "name")
        IF LEN(nam) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_xml_value>: attribute 'name' does not exist or is empty"
        IF INSTR(tag, "/>") = 0 THEN ' <set_xml_value name="load_file_names">    ...normally followed by:  <item>Bwing.lvl</item></set_xml_value>
            vlu = XmlContent(tag + xmlBuf, TRIM(tag, ANY "<>"))
            IF LEN(vlu) = 0 THEN ThrowError 3, "Error after line " + STR(nbl-TALLY(xmlBuf, LF)) + " closing tag </set_xml_value> does not exist or content of tag is empty"
            DO UNTIL LCASE(tag) = "</set_xml_value>"
                tag = XmlNextTag(xmlBuf)
            LOOP
        ELSE                         ' <set_xml_value name="color1" value="0xffffff" />
            vlu = InlineContent(tag, "value") ' can be an empty string or even omitted attribute
        ENDIF
        tag = "<" + typ + " name=" + DQ + nam + DQ ' e.g. <integer name="version"
        IF LCASE(typ) = "array" THEN
            attr = "<string-" + typ + " name=" + DQ + nam + DQ ' e.g. <string-array name="loading_msg"
            IF INSTR(LCASE(buffer), LCASE(tag)) > 0 THEN ReplaceXmlTagWith buffer, MID(tag, 2), MID(attr, 2) ' replace <array ..> with <string-array ..>
            SWAP tag, attr
        ENDIF
        IF INSTR(LCASE(buffer), LCASE(tag)) = 0 THEN
            warning = 1
            COLOR 14, 0
            IF verbose THEN PRINT "Warning line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_xml_value>: " + _
                "cannot find tag + attribute " + tag + "> in XML file " + DQ + tgt + DQ
            COLOR 7, 0
        ELSE
            tag = MID(tag, 2) ' remove starting "<"
            IF verbose THEN PRINT "Setting tag <" + tag + "> content to " + DQ + TRIM(vlu, ANY WHITESPACE) + DQ
            ReplaceXmlContentWith buffer, tag, vlu
        ENDIF

    ' Tag is of the type <modify_xml source="res/xml/settings.xml">
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<modify_xml ") = 1 THEN
        src = InlineContent(tag, "source")
        IF LEN(src) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <modify_xml>: attribute 'source' does not exist or is empty"
        tgt = TempPath + STRREPLACE(src, ANTISLASH, SLASH) ' User should always use a relative path e.g. "res/xml/settings.xml"
        IF NOT FILEEXIST(tgt) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <modify_xml>: source file " + DQ + src + DQ + " does not exist"
        IF verbose THEN COLOR 11, 0 : PRINT "Opening XML file " + DQ + tgt + DQ + " for modification" : COLOR 7, 0
        buffer = TRIM(LoadFile(tgt), ANY WHITESPACE)

    ' Tag is of the type </modify_xml>
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "</modify_xml>") = 1 THEN
        IF LEN(tgt) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected closing tag </modify_xml>"
        IF verbose THEN COLOR 11, 0 : PRINT "Saving changes to XML file " + DQ + tgt + DQ : COLOR 7, 0
        SaveFile tgt, buffer
        tgt = "" ' To handle next closing tags </modify_xml>, </modify_xml_values> and </modify_manifest>

    ' Tag is of the type <modify_manifest>
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<modify_manifest>") = 1 THEN
        tgt = TempPath + "AndroidManifest.xml"
        IF NOT FILEEXIST(tgt) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <modify_manifest>: " + DQ + tgt + DQ + " does not exist"
        IF verbose THEN COLOR 11, 0 : PRINT "Opening XML file " + DQ + tgt + DQ + " for modification" : COLOR 7, 0
        buffer = TRIM(LoadFile(tgt), ANY WHITESPACE)

    ' Tag is of the type </modify_manifest>
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "</modify_manifest>") = 1 THEN
        IF LEN(tgt) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected closing tag </modify_manifest>"
        IF verbose THEN COLOR 11, 0 : PRINT "Saving changes to XML file " + DQ + tgt + DQ : COLOR 7, 0
        SaveFile tgt, buffer
        tgt = "" ' To handle next closing tags </modify_xml>, </modify_xml_values> and </modify_manifest>

    ' Tag is of the type <set_attribute_value tag='android:key="font_pref"' attribute="android:defaultValue" value="Medium" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<set_attribute_value ") = 1 THEN
        IF LEN(tgt) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected tag <set_attribute_value>: must be inside a <modify_xml>, <modify_xml_values> or <modify_manifest>"
        attr = InlineContent(tag, "attribute")
        IF LEN(attr) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_attribute_value>: attribute 'attribute' does not exist or is empty"
        vlu = InlineContent(tag, "value") ' can be an empty string or even omitted attribute
        tag = InlineContent(tag, "tag")
        IF LEN(tag) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_attribute_value>: attribute 'tag' does not exist or is empty"
        IF INSTR(LCASE(buffer), LCASE(tag)) = 0 THEN
            warning = 1
            COLOR 14, 0
            IF verbose THEN PRINT "Warning line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_attribute_value>: " + _
                "cannot find tag " + tag + " in XML file " + DQ + tgt + DQ
            COLOR 7, 0
        ELSEIF INSTR(LCASE(buffer), LCASE(attr)) = 0 THEN
            warning = 1
            COLOR 14, 0
            IF verbose THEN PRINT "Warning line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <set_attribute_value>: " + _
                "cannot find attribute " + attr + " in XML file " + DQ + tgt + DQ
            COLOR 7, 0
        ELSE
            IF verbose THEN PRINT "Setting attribute " + attr + " after tag <" + tag + "> value to " + DQ + TRIM(vlu, ANY WHITESPACE) + DQ
            ReplaceInlineContentAfterTagWith buffer, tag, attr, vlu
        ENDIF

    ' Tag is of the type <remove_tag tag="intent-filter" contains='android:pathPattern=".*\\.bas"' />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<remove_tag ") = 1 THEN
        IF LEN(tgt) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected tag <remove_tag>: must be inside a <modify_xml>, <modify_xml_values> or <modify_manifest>"
        vlu = InlineContent(tag, "contains")
        IF LEN(vlu) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <remove_tag>: attribute 'contains' does not exist or is empty"
        tag = InlineContent(tag, "tag")
        IF LEN(tag) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <remove_tag>: attribute 'tag' does not exist or is empty"
        i = RemoveFirstXmlTag (buffer, tag, vlu)
        IF i = 0 THEN warning = 1
        IF verbose THEN
            IF i = 0 THEN
                COLOR 14, 0
                PRINT "Warning line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <remove_tag>: did not find any tag <" + _
                    tag + "> containing " + DQ + vlu + DQ + " in XML file " + DQ + tgt + DQ
                COLOR 7, 0
            ELSE
                PRINT "Removing tag <" + tag + "> containing " + DQ + vlu + DQ
            ENDIF
        ENDIF

    ' Tag is of the type <reset_permissions />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<reset_permissions") = 1 THEN
        IF tgt <> TempPath + "AndroidManifest.xml" THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected tag <reset_permissions>: must be inside a <modify_manifest>"
        i = 0
        WHILE RemoveFirstXmlTag (buffer, "uses-permission") = 1
            i += 1
        WEND
        IF verbose THEN PRINT "Resetting " + STR(i) + " permissions in AndroidManifest.xml"

    ' Tag is of the type <add_permission name="WRITE_EXTERNAL_STORAGE" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<add_permission ") = 1 THEN
        IF tgt <> TempPath + "AndroidManifest.xml" THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " unexpected tag <add_permission>: must be inside a <modify_manifest>"
        nam = InlineContent(tag, "name")
        IF LEN(nam) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <add_permission>: attribute 'name' does not exist or is empty"
        IF INSTR(LCASE(buffer), "<uses-permission ") > 0 THEN
            vlu = "<uses-permission android:name=" + DQ + "android.permission." + UCASE(nam) + DQ + " />" + LF
            buffer = INSERTBEFORE (buffer, "<uses-permission ", vlu)
        ELSE
            i = INSTR(LCASE(buffer), "<manifest ")
            IF i = 0 THEN ThrowError 3, "Fatal error: malformed AndroidManifest.xml - does not contain a tag <manifest ..>"
            i = INSTR(i, buffer, ">")
            IF i = 0 THEN ThrowError 3, "Fatal error: malformed AndroidManifest.xml - tag <manifest ..> is never closed"
            tag = LEFT(buffer, i)
            vlu = LF + "<uses-permission android:name=" + DQ + "android.permission." + UCASE(nam) + DQ + " />"
            buffer = INSERTAFTER (buffer, tag, vlu)
        ENDIF
        IF verbose THEN PRINT "Adding permission " + UCASE(nam) + " to AndroidManifest.xml"

    ' Tag is of the type <change_package old="com.rfo.basic" new="rfo.mougino.bwing" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<change_package ") = 1 THEN
        IF LEN(tgt) > 0 THEN
            warning = 1
            COLOR 14, 0
            IF verbose THEN PRINT "Warning line " + STR(nbl-TALLY(xmlBuf, LF)) + ": tag <change_package> found " + _
                "while operating on XML file " + DQ + tgt + DQ + ". Changes will be saved and file will be closed."
            COLOR 7, 0
            IF verbose THEN COLOR 11, 0 : PRINT "Saving changes to XML file " + DQ + tgt + DQ : COLOR 7, 0
            SaveFile tgt, buffer
            tgt = "" ' To handle next closing tags </modify_xml>, </modify_xml_values> and </modify_manifest>
        ENDIF
        nam = InlineContent(tag, "old") ' current package name
        IF LEN(nam) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <change_package>: attribute 'old' does not exist or is empty"
        tgt = InlineContent(tag, "new") ' target package name
        IF LEN(tgt) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <change_package>: attribute 'new' does not exist or is empty"
        IF verbose THEN PRINT "Changing package name from " + DQ + nam + DQ + " to " + DQ + tgt + DQ;
        old = TempPath + "smali" + SLASH + STRREPLACE(nam, ".", SLASH)
        dst = TempPath + "smali" + SLASH + STRREPLACE(tgt, ".", SLASH)
        MakeSureDirectoryPathExists RTRIM(dst, SLASH)
        ERASE file
        RDIR file(), TempPath,, fbNormal ' recursively list files (only, not subfolders) in project folder
        VAR t0 = TIMER
        FOR i = LBOUND(file) TO UBOUND(file)
            buffer = LoadFile(file(i))
            IF INSTR(buffer, nam) > 0 OR INSTR(buffer, STRREPLACE(nam, ".", "/")) > 0 THEN
                buffer = STRREPLACE (buffer, STRREPLACE(nam, ".", "/"), STRREPLACE(tgt, ".", "/"))
                buffer = STRREPLACE (buffer, nam, tgt)
                KILL file(i)
                file(i) = STRREPLACE (file(i), old, dst) ' new package folder
                SaveFile file(i), buffer
            ENDIF
        NEXT
        VAR t1 = TIMER - t0
        IF verbose THEN PRINT " (took " + STR(INT(t1)) + "s)"
        old = SLASH + STRREPLACE(nam, ".", SLASH)
        WHILE INSTR(old, SLASH) > 0
            RMDIR TempPath + "smali" + old
            old = LEFT(old, INSTRREV(old, SLASH) - 1)
        WEND
        tgt = "" ' To handle next closing tags </modify_xml>, </modify_xml_values> and </modify_manifest>

    ' Tag is of the type <sign_with certificate="rfobasic.jks" password="12345678" />
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "<sign_with ") = 1 THEN
        CHDIR path ' change to path defined in <set_local_folder>
        jks = InlineContent(tag, "certificate") ' user certificate
        IF LEN(jks) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <sign_with>: attribute 'certificate' does not exist or is empty"
        jks = STRREPLACE(jks, ANTISLASH, SLASH) ' make path relevant to current system (Unix/Windows)
        IF NOT FILEEXIST(jks) THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <sign_with>: certificate " + DQ + jks + DQ + " does not exist"
        dst = FILEPATH(RTRIM(TempPath, SLASH)) + SLASH
        FILECOPY jks, dst + FILENAME(jks)
        CHDIR dst
        pwd = InlineContent(tag, "password")    ' user password
        IF LEN(pwd) = 0 THEN ThrowError 3, "Error line " + STR(nbl-TALLY(xmlBuf, LF)) + " in tag <sign_with>: attribute 'password' does not exist or is empty"

        ' (1/4) Dump Java KeyStore from JKS into PKCS12
        IF verbose THEN PRINT "Dumping Java KeyStore from JKS into PKCS12 with "; : COLOR 10, 0 : PRINT "keytool"; : COLOR 7, 0 : PRINT "..."
        cmd = "keytool -importkeystore -srckeystore " + DQ + jks + DQ + " -srcstorepass " + pwd + _
              " -deststorepass " + pwd + " -destkeystore intermediate.p12 -srcstoretype JKS" + _
              " -deststoretype PKCS12"
        IF verbose = 0 THEN cmd += " > keytool.log 2>&1"
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        IF NOT FILEEXIST("intermediate.p12") THEN
            cmd = "Failure when trying to dump the Java KeyStore to PKCS12"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + LoadFile("keytool.log")
            ThrowError 4, cmd
        ELSEIF verbose = 0 THEN
            KILL "keytool.log"
        ENDIF

        ' (2/4) Dump new PKCS12 file into PEM
        IF verbose THEN PRINT "Dumping the new PKCS12 file into PEM with "; : COLOR 10, 0 : PRINT "openssl"; : COLOR 7, 0 : PRINT "..."
        cmd = "openssl pkcs12 -in intermediate.p12 -passin pass:" + pwd _
            + " -nodes -out intermediate.rsa.pem"
        IF verbose = 0 THEN cmd += " > openssl.log 2>&1"
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        IF NOT FILEEXIST("intermediate.rsa.pem") THEN
            cmd = "Failure when trying to dump the PKCS12 file to PEM"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + LoadFile("openssl.log")
            ThrowError 4, cmd
        ELSEIF verbose = 0 THEN
            KILL "openssl.log"
        ENDIF
        KILL "intermediate.p12"

        ' (3/4) Split cert and private key from PEM
        IF verbose THEN PRINT "Splitting the cert and private key from PEM with "; : COLOR 10, 0 : PRINT "splitpem"; : COLOR 7, 0 : PRINT "..."
        cmd = "splitpem intermediate.rsa.pem"
        IF verbose = 0 THEN cmd += " > splitpem.log 2>&1"
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        IF NOT FILEEXIST("private.rsa.pem") OR NOT FILEEXIST("cert.x509.pem") THEN
            cmd = "Failure when trying to split the cert and private key from PEM"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + LoadFile("splitpem.log")
            ThrowError 4, cmd
        ELSEIF verbose = 0 THEN
            KILL "splitpem.log"
        ENDIF
        KILL "intermediate.rsa.pem"

        ' (4/4) Convert private key into PK8 format as expected by signapk
        IF verbose THEN PRINT "Converting the private key into PK8 format with "; : COLOR 10, 0 : PRINT "openssl"; : COLOR 7, 0 : PRINT "..."
        cmd = "openssl pkcs8 -topk8 -outform DER -in private.rsa.pem -inform PEM -out key.pk8 -nocrypt"
        IF verbose = 0 THEN cmd += " > openssl.log 2>&1"
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        IF NOT FILEEXIST("key.pk8") THEN
            cmd = "Failure when trying to convert the private key to PK8 format"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + LoadFile("openssl.log")
            ThrowError 4, cmd
        ELSEIF verbose = 0 THEN
            KILL "openssl.log"
        ENDIF
        KILL "private.rsa.pem"

    ' Tag is of the type </use_base_apk>
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF INSTR(LCASE(tag), "</use_base_apk>") = 1 THEN
        IF LEN(tgt) > 0 THEN
            warning = 1
            COLOR 14, 0
            IF verbose THEN PRINT "Warning line " + STR(nbl-TALLY(xmlBuf, LF)) + ": tag </use_base_apk> found " + _
                "while operating on XML file " + DQ + tgt + DQ + ". Changes will be saved and file will be closed."
            COLOR 7, 0
            IF verbose THEN COLOR 11, 0 : PRINT "Saving changes to XML file " + DQ + tgt + DQ : COLOR 7, 0
            SaveFile tgt, buffer
            tgt = "" ' To handle next closing tags </modify_xml>, </modify_xml_values> and </modify_manifest>
        ENDIF
        src = FILENAME(RTRIM(TempPath, SLASH))
        TempPath = FILEPATH(RTRIM(TempPath, SLASH)) + SLASH
        CHDIR TempPath

        ' Recompile with apktool
        IF verbose THEN PRINT "Recompiling modified APK with "; : COLOR 10, 0 : PRINT "apktool"; : COLOR 7, 0 : PRINT "..."
        cmd = "apktool b " + src + " unsigned.apk"
        IF verbose = 0 THEN cmd += " > apktool.log 2>&1"
        VAR t0 = TIMER
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        VAR t1 = TIMER - t0
        IF NOT FILEEXIST(TempPath + "unsigned.apk") THEN
            cmd = "Failure when trying to recompile"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + ISOLATE(LoadFile("apktool.log"), "error")
            ThrowError 4, cmd
        ELSEIF verbose THEN
            PRINT "APK has been recompiled to 'unsigned.apk' (took " + STR(INT(t1)) + "s)"
        ELSE
            KILL "apktool.log"
        ENDIF

        ' Sign with x509 certificate
        IF NOT FILEEXIST(TempPath + "cert.x509.pem") THEN ' no previous <sign_with> tag --> use default certificate
            IF verbose THEN PRINT "Copying default certificate to " + TempPath
            FILECOPY EXEPATH + SLASH + "cert.x509.pem", TempPath + "cert.x509.pem"
            FILECOPY EXEPATH + SLASH + "key.pk8", TempPath + "key.pk8"
        ENDIF
        IF verbose THEN PRINT "Signing 'unsigned.apk' with "; : COLOR 10, 0 : PRINT "signapk"; : COLOR 7, 0 : PRINT "..."
        cmd = "signapk " + DQ + "." + SLASH + "cert.x509.pem" + DQ + " " + DQ + "." + SLASH + "key.pk8" + _
            DQ + " " + DQ + "unsigned.apk" + DQ + " " + DQ + "unaligned.apk" + DQ
        IF verbose = 0 THEN cmd += " > signapk.log 2>&1"
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        IF NOT FILEEXIST(TempPath + "unaligned.apk") THEN
            cmd = "Failure when trying to sign the recompiled APK"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + LoadFile("signapk.log")
            ThrowError 4, cmd
        ELSEIF verbose = 0 THEN
            KILL "signapk.log"
        ENDIF

        ' Align final package
        IF verbose THEN PRINT "Aligning 'unaligned.apk' with "; : COLOR 10, 0 : PRINT "zipalign"; : COLOR 7, 0 : PRINT "..."
        cmd = "zipalign -f 4 " + DQ + "unaligned.apk" + DQ + " " + DQ + FILENAME(apk) + DQ
        IF verbose = 0 THEN cmd += " > zipalign.log 2>&1"
        COLOR 10, 0 : SHELL cmd : COLOR 7, 0
        IF NOT FILEEXIST(TempPath + FILENAME(apk)) THEN
            cmd = "Failure when trying to align the recompiled + signed APK"
            IF verbose = 0 THEN cmd += " - Detail:" + LF + LoadFile("zipalign.log")
            ThrowError 4, cmd
        ELSEIF verbose = 0 THEN
            KILL "zipalign.log"
        ENDIF

        ' Finally move to target APK
        IF verbose THEN PRINT "Moving " + DQ + TempPath + FILENAME(apk) + DQ + " to " + DQ + apk + DQ
        CHDIR path ' change to path defined in <set_local_folder>
        FILECOPY TempPath + FILENAME(apk), apk
        VAR tf = TIMER - ti
        IF tf <= 60 THEN
            cmd = STR(INT(tf)) + "s"
        ELSE
            tf = INT(tf)
            ti = INT(tf / 60)
            tf = tf - (60 * ti)
            cmd = STR(ti) + "mn " + STR(tf) + "s"
        ENDIF
        IF verbose THEN
            IF warning THEN
                COLOR 14, 0
                PRINT "There were some warnings --> leaving temporary folder " + DQ + TempPath + DQ + " intact for investigation"
                COLOR 7, 0
            ELSE
                PRINT "No errors nor important warnings were thrown --> removing temporary folder " + DQ + TempPath + DQ
            ENDIF
        ENDIF
        PRINT FILENAME(apk) + " correctly produced ! (took " + cmd + ")"
        IF warning = 0 THEN KILLDIR TempPath ' clean everything behind us, except if there was a warning, user might want to investigate
        END(0)

    ' Tag is of any other type
    '----------------------------------------------------------------------------------------------------------------
    ELSEIF verbose THEN
        COLOR 8, 0
        PRINT STR(nbl-TALLY(xmlBuf, LF)) + ". " + tag
        COLOR 7, 0       
    ENDIF

LOOP 

ThrowError 3, "Error: malformed input XML - does not end with a </use_base_apk> --> aborting APK production"
