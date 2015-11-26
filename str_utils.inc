DECLARE FUNCTION STRREPLACE (buf AS STRING, src AS STRING, tgt AS STRING) AS STRING
' Return a string with all occurences of 'src' in initial string 'buf' replaced with 'tgt'
DECLARE FUNCTION REMOVE (BYREF buf AS STRING, BYREF chunk AS STRING) AS STRING
' Return a string with every occurence of 'chunk' removed from 'buf'
DECLARE FUNCTION TALLY (BYREF buf AS STRING, BYREF chunk AS STRING) AS INTEGER
' Return the number of occurences of 'chunk' inside 'buf'
DECLARE FUNCTION INSERTBEFORE (BYREF buf AS STRING, BYREF where AS STRING, BYREF ins AS STRING) AS STRING
' Return the initial string 'buf' with string 'ins' inserted just before the first occurence of 'where' (case insensitive research)
DECLARE FUNCTION INSERTAFTER (BYREF buf AS STRING, BYREF where AS STRING, BYREF ins AS STRING) AS STRING
' Return the initial string 'buf' with string 'ins' inserted just after the first occurence of 'where' (case insensitive research)
DECLARE FUNCTION ISOLATE (BYREF buf AS STRING, BYREF chunk AS STRING) AS STRING
' Isolate the first line (between any CR or LF) from 'buf' that contains 'chunk'
DECLARE FUNCTION TimeStamp () AS STRING
' Return a timestamp in the form of YYYYMMDDhhmmss

CONST DQ = CHR(34)
CONST LF = CHR(10), CR = CHR(13), CRLF = CR + LF
CONST WHITESPACE = CHR(32) + CHR(9) + CR + LF ' space, tab, cr, lf

'--------------------------------------------------------------------------------
FUNCTION STRREPLACE (buf AS STRING, src AS STRING, tgt AS STRING) AS STRING
' Return a string with all occurences of 'src' in initial string 'buf' replaced with 'tgt'
    DIM AS ZSTRING PTR iStr, iFind, iRep
    DIM AS INTEGER icor = 0
    DIM AS INTEGER i, code

    IF buf="" OR src="" THEN RETURN buf
    IF tgt="" THEN
        tgt="¿"
        icor=1
    ENDIF
    iStr  = STRPTR(buf)
    iFind = STRPTR(src)
    iRep  = STRPTR(tgt)

    DIM AS INTEGER iSize    = LEN(buf) - LEN(src)
    DIM AS ZSTRING PTR dStr = CALLOCATE(LEN(buf) * 20)
    DIM AS STRING s

     ASM
        mov esi,[iStr]
        ADD [iSize],esi
        mov ebx,[iFind]
        inc dword PTR[iSize]
        mov edi,[dStr]
     END ASM
     ASM SUB esi,1
     ASM
        jmp Start1
Start2: ADD esi,ecx
Start1: ADD esi,1
        cmp [iSize],esi
        jle Done
        movzx eax,BYTE PTR[esi]
        cmp al,[ebx]
        je Match
        mov [edi],al
        ADD edi,1
        jmp Start1
Match:  mov ecx,-1
        mov edx,ebx
B1:     ADD ecx,1
        movzx eax,BYTE PTR[edx]
        TEST eax,eax
        jz Change
        ADD edx,1
        cmp [esi+ecx],al
        je B1
        movzx eax,BYTE PTR[esi]
        mov [edi],al
        ADD edi,1
        jmp Start1
Change: mov edx,[iRep]
     END ASM
saute:  ASM SUB ecx,1
     ASM
B2:     movzx eax,BYTE PTR[edx]
        TEST eax,eax
        jz Start2
        ADD edx,1
        mov [edi],al
        ADD edi,1
        jmp B2
Done:   mov ecx,-1
B3:     ADD ecx,1
        movzx eax,BYTE PTR[esi+ecx]
        mov [edi+ecx],al
        TEST eax,eax
        jnz B3
       ' mov eax,[dStr]
       ' mov [toto],eax
    END ASM

    s = *dStr
    IF icor=0 THEN
        FUNCTION = s
        DEALLOCATE dStr
        EXIT FUNCTION
    ENDIF

    code = ASC("¿") ' change it here if you want
    ASM
        mov esi, [dStr]
        mov edx, -1       ' "get" pointer
        XOR ecx, ecx      ' "put" pointer
        TEST esi, esi     ' in case passed null string
        jz  1f
      0:
        inc edx
        movzx eax, BYTE PTR [esi+edx]
        TEST eax, eax
        jz  1f
        cmp eax,[code]  '
        je  0b
        mov [esi+ecx], al
        inc ecx
        jmp 0b
      1:
        mov [i], ecx
    END ASM

    s = LEFT(*dStr, i)
    FUNCTION = s
    DEALLOCATE dStr

END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
''Old function, very slow:
'FUNCTION STRREPLACE (BYREF buf AS STRING, BYREF src AS STRING, BYREF tgt AS STRING, BYVAL a AS INTEGER = 1) AS STRING
' Return a string with all occurences of 'src' starting at position #a in initial string 'buf' replaced with 'tgt'
'    VAR nbuf = buf, p = INSTR(a, buf, src), ls = LEN(src), lt = LEN(tgt)
'    IF ls = lt THEN ls = 0
'    WHILE p
'        IF ls THEN nbuf = LEFT(nbuf, p-1) + tgt + MID(nbuf, p+ls) ELSE MID(nbuf, p) = tgt
'        p = INSTR(p+lt, nbuf, src)
'    WEND
'    RETURN nbuf
'END FUNCTION    
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION REMOVE (BYREF buf AS STRING, BYREF chunk AS STRING) AS STRING
' Return a string with every occurence of 'chunk' removed from 'buf'
    RETURN STRREPLACE (buf, chunk, "")
''Old function, very slow:
'    VAR e = buf, i = INSTR(buf, chunk), lc = LEN(chunk)
'    WHILE i
'        e = LEFT(e, i-1) + MID(e, i+lc)
'        i = INSTR(e, chunk)
'    WEND
'    RETURN e
END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION TALLY (BYREF buf AS STRING, BYREF chunk AS STRING) AS INTEGER
' Return the number of occurences of 'chunk' inside 'buf'
    VAR n = 0, i = INSTR(buf, chunk), lc = LEN(chunk)
    WHILE i
        n += 1
        i = INSTR(i + lc, buf, chunk)
    WEND
    RETURN n
END FUNCTION
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION INSERTBEFORE (BYREF buf AS STRING, BYREF where AS STRING, BYREF ins AS STRING) AS STRING
' Return the initial string 'buf' with string 'ins' inserted just before the first occurence of 'where' (case insensitive research)
    VAR nbuf = buf, p = INSTR(LCASE(buf), LCASE(where))
    IF p THEN nbuf = LEFT(nbuf, p-1) + ins + MID(nbuf, p)
    RETURN nbuf
END FUNCTION    
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION INSERTAFTER (BYREF buf AS STRING, BYREF where AS STRING, BYREF ins AS STRING) AS STRING
' Return the initial string 'buf' with string 'ins' inserted just after the first occurence of 'where' (case insensitive research)
    VAR nbuf = buf, p = INSTR(LCASE(buf), LCASE(where))
    IF p THEN
        p += LEN(where)
        nbuf = LEFT(nbuf, p) + ins + MID(nbuf, p+1)
    ENDIF
    RETURN nbuf
END FUNCTION    
'--------------------------------------------------------------------------------

'--------------------------------------------------------------------------------
FUNCTION ISOLATE (BYREF buf AS STRING, BYREF chunk AS STRING) AS STRING
' Isolate the first line (between any CR or LF) from 'buf' that contains 'chunk'
    VAR p = INSTR(LCASE(buf), LCASE(chunk))
    IF p THEN
        VAR i = INSTRREV(buf, ANY CRLF, p)
        IF i > 0 THEN
            VAR j = INSTR(p, buf, ANY CRLF)
            IF j > 0 THEN RETURN MID(buf, i+1, j-i-1)
        ENDIF
    ENDIF
END FUNCTION    
'--------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION TimeStamp () AS STRING
' Return a timestamp in the form of YYYYMMDDhhmmss
    DIM e AS STRING
    e = DATE
    e = RIGHT(e, 4) + LEFT(e, 2) + MID(e, 4, 2)
    e += STRREPLACE(TIME, ":", "")
    FUNCTION = e 
END FUNCTION    
'--------------------------------------------------------------------------------

