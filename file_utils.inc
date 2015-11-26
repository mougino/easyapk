#INCLUDE ONCE "file.bi"
#INCLUDE ONCE "dir.bi"

DECLARE FUNCTION FILENAME (file AS STRING) AS STRING
' Return 'myfile.ext' from "C:\Folder\Other folder\myfile.ext"
DECLARE FUNCTION FILEPATH (file AS STRING) AS STRING
' Return 'C:\Folder\Other folder' (without ending slash) from "C:\Folder\Other folder\myfile.ext"
DECLARE FUNCTION FOLDEREXIST (folder AS STRING) AS INTEGER
' Return 1 if folder exists, 0 otherwise. For files, use FILEEXISTS
DECLARE SUB MakeSureDirectoryPathExists (path AS STRING)
' Create all the folder hierarchy up to 'path'
DECLARE FUNCTION LoadFile (BYREF file AS STRING) AS STRING
' Load file 'file' and return its content as a string buffer
DECLARE SUB SaveFile (BYREF file AS STRING, BYREF buf AS STRING)
' Save string buffer 'buf' as file 'file'
DECLARE SUB RDIR (filelist() AS STRING, folder AS STRING, mask AS STRING = "*", file_or_folder AS UINTEGER = fbNormal OR fbDirectory)
' Do a recursive listing of files in 'folder' and store the result in filelist()
' An optional mask can be specified as a 3rd parameter for both files and folders (default: * or *.*)
' Set the optional 4th parameter to 'fbDirectory' to list only subfolders ; set it to 'fbNormal' to list only files
' Omit it or set it to 'fbNormal + fbDirectory' to list both files and subfolders (the latter finishing with a trailing SLASH)
DECLARE SUB KILLDIR (rootfolder AS STRING)
' Delete all files and folders from rootfolder, rootfolder included

#IFDEF __FB_UNIX__
    CONST SLASH     = "/"
    CONST ANTISLASH = "\"
    CONST PATH_SEP  = ":"
#ELSE
    CONST SLASH     = "\"
    CONST ANTISLASH = "/"
    CONST PATH_SEP  = ";"
#ENDIF 

'------------------------------------------------------------------------------
FUNCTION FILENAME (file AS STRING) AS STRING
' Return 'myfile.ext' from "C:\Folder\Other folder\myfile.ext"
    IF INSTR(file, SLASH) = 0 THEN RETURN file
    DIM i AS INTEGER
    i = INSTRREV(file, SLASH) ' backwards INSTR()
    IF i > 0 THEN FUNCTION = MID(file, i+1)
END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION FILEPATH (file AS STRING) AS STRING
' Return 'C:\Folder\Other folder' (without ending slash) from "C:\Folder\Other folder\myfile.ext"
    IF INSTR(file, SLASH) = 0 THEN RETURN EXEPATH
    DIM i AS INTEGER
    i = INSTRREV(file, SLASH) ' backwards INSTR()
    IF i > 0 THEN FUNCTION = LEFT(file, i-1)
END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION FOLDEREXIST (folder AS STRING) AS INTEGER
' Return 1 if folder exists, 0 otherwise. For files, use FILEEXIST
    DIM e AS STRING
    e = DIR (RTRIM(folder, SLASH) + SLASH + ".", fbNormal OR fbDirectory)
    FUNCTION = (LEN(e) > 0)
END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION FILEEXIST (file AS STRING) AS INTEGER
' Return 1 if file exists, 0 otherwise. For folders, use FOLDEREXIST
#IFDEF __FB_WIN32__ ' Windows
    DIM AS STRING tlog, cmd
    tlog = RTRIM(ENVIRON("TEMP"), SLASH) + SLASH + "fileexist"
    IF INSTR(tlog, " ") > 0 THEN tlog = CHR(34) + tlog + CHR(34)
    cmd = file : IF INSTR(cmd, " ") > 0 THEN cmd = CHR(34) + cmd + CHR(34)
    cmd = "DIR " + cmd + " /B > " + tlog + " 2>&1"
    SHELL cmd
    RETURN ( INSTR(LoadFile(TRIM(tlog, CHR(34))), FILENAME(file)) > 0 )
#ELSE ' Linux
    RETURN FILEEXISTS(file)
#ENDIF   
END FUNCTION
'------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
SUB MakeSureDirectoryPathExists (path AS STRING)
' Create all the folder hierarchy up to 'path'
    DIM i AS INTEGER
    DIM e AS STRING
    i = INSTR(path, SLASH)
    WHILE i
        MKDIR LEFT(path, i)
        i = INSTR(i+1, path, SLASH)
    WEND
    MKDIR path
END SUB
'--------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION LoadFile (BYREF file AS STRING) AS STRING
' Load file 'file' and return its content as a string buffer
    DIM h AS INTEGER
    DIM txt AS STRING
    h = FREEFILE
    IF OPEN( file FOR BINARY ACCESS READ AS #h ) <> 0 THEN RETURN ""
    IF LOF(h) > 0 THEN
        txt = STRING(LOF(h), 0)
        IF GET( #h, ,txt ) <> 0 THEN txt = ""
    END IF
    CLOSE #h
    RETURN txt
END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB SaveFile (BYREF file AS STRING, BYREF buf AS STRING)
' Save string buffer 'buf' as file 'file'
    KILL file
    MakeSureDirectoryPathExists FILEPATH(file)
    DIM h AS INTEGER
    h = FREEFILE
    OPEN file FOR BINARY ACCESS WRITE AS #h
    PUT #h, 1, buf
    CLOSE #h
END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB RDIR (filelist() AS STRING, folder AS STRING, mask AS STRING = "*", file_or_folder AS UINTEGER = fbNormal OR fbDirectory)
' Do a recursive listing of files in 'folder' and store the result in filelist()
' An optional mask can be specified as a 3rd parameter for both files and folders (default: * or *.*)
' Set the optional 4th parameter to 'fbDirectory' to list only subfolders ; set it to 'fbNormal' to list only files
' Omit it or set it to 'fbNormal + fbDirectory' to list both files and subfolders (the latter finishing with a trailing SLASH)
    DIM AS UINTEGER out_attr, dircnt ' unsigned integer to hold retrieved attributes
    DIM AS STRING fname, dirlist()

    fname = DIR (RTRIM(folder, SLASH) + SLASH + mask, fbNormal OR fbDirectory, out_attr)

    DO UNTIL LEN(fname) = 0 ' loop until Dir returns empty string
        IF (fname <> ".") AND (fname <> "..") THEN ' ignore current and parent directory entries
            IF out_attr AND fbDirectory THEN ' this is a subfolder
                dircnt += 1
                REDIM PRESERVE dirlist(1 TO dircnt)
                dirlist(dircnt) = RTRIM(folder, SLASH) + SLASH + fname
            ELSE       ' this is a file
                IF file_or_folder <> fbDirectory THEN ' user wants to list files
                    IF UBOUND(filelist) = -1 THEN REDIM filelist(1 TO 1) ELSE REDIM PRESERVE filelist(1 TO UBOUND(filelist) + 1)
                    filelist(UBOUND(filelist)) = RTRIM(folder, SLASH) + SLASH + fname
                ENDIF
            ENDIF
        ENDIF
        fname = DIR(out_attr)
    LOOP

    FOR i AS INTEGER = 1 TO UBOUND(dirlist)
        IF file_or_folder AND fbDirectory THEN ' user wants to list subfolders as well
            IF UBOUND(filelist) = -1 THEN REDIM filelist(1 TO 1) ELSE REDIM PRESERVE filelist(1 TO UBOUND(filelist) + 1)
            filelist(UBOUND(filelist)) = dirlist(i) + SLASH ' subfolders finish with an ending SLASH to differentiate them from files
        ENDIF
        RDIR filelist(), dirlist(i), mask, file_or_folder
    NEXT

END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB KILLDIR (rootfolder AS STRING)
' Delete all files and folders from rootfolder, rootfolder included
    DIM fl() AS STRING
    RDIR fl(), rootfolder ' recursively list all files and subfolders
    FOR i AS INTEGER = UBOUND(fl) TO LBOUND(fl) STEP -1
        IF RIGHT(fl(i), 1) = SLASH THEN RMDIR fl(i) ELSE KILL fl(i)
    NEXT
    RMDIR rootfolder
END SUB
'------------------------------------------------------------------------------

