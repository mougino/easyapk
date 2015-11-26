DECLARE FUNCTION XmlNextTag (BYREF buffer AS STRING) AS STRING
' Extract the first <tag attribute="inline_value"> from a buffer
DECLARE FUNCTION XmlContent (buffer AS STRING, tag AS STRING) AS STRING
' Retrieve 'content' from   <tag attribute="inline_value"> content </tag>
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'
DECLARE SUB ReplaceXmlContentWith (BYREF buffer AS STRING, tag AS STRING, newcontent AS STRING)
' Replace 'content' with 'newcontent' in   <tag attribute="inline_value"> content </tag>
' /or/ transform a   <tag attribute='inline_value' />   into a   <tag attribute='inline_value' > newcontent </tag>
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'
DECLARE FUNCTION InlineContent (buffer AS STRING, param AS STRING) AS STRING
' Retrieve 'inline_value' from   <tag attribute="inline_value"> content </tag>   or from   <tag attribute='inline_value' />
DECLARE SUB ReplaceInlineContentWith (BYREF buffer AS STRING, param AS STRING, newvalue AS STRING)
' Replace 'inline_value' with 'newvalue' in first occurence of   <tag attribute="inline_value"> content </tag>   or   <tag attribute="inline_value" />
DECLARE SUB ReplaceInlineContentAfterTagWith (BYREF buffer AS STRING, tag AS STRING, param AS STRING, newvalue AS STRING)
' Replace 'inline_value' with 'newvalue' in   <tag attribute="inline_value"> content </tag>   or in   <tag attribute="inline_value" />
DECLARE SUB ReplaceXmlTagWith (BYREF buffer AS STRING, tag AS STRING, newtag AS STRING)
' Replace <tag attribute='inline_value' />   with   <newtag attribute='inline_value' />
' Or replace <tag attribute="inline_value"> content </tag>   with   <newtag attribute="inline_value"> content </newtag>
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'
DECLARE FUNCTION RemoveFirstXmlTag (BYREF buffer AS STRING, tag AS STRING, contains AS STRING = "") AS INTEGER
' Remove first occurence of <tag attribute='inline_value' />   or of  <tag attribute="inline_value"> content </tag>
' that contains the string 'contains' (insensitive case research). Return 1 if successful, 0 if not.
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'


'------------------------------------------------------------------------------
FUNCTION XmlNextTag (BYREF buffer AS STRING) AS STRING
' Extract the first <tag attribute="inline_value"> from a buffer
    DIM AS INTEGER i, j
    i = INSTR(buffer, "<")
    IF i = 0 THEN
        buffer = ""
    ELSE
        j = INSTR(i, buffer, ">")
        IF j = 0 THEN
            buffer = ""
        ELSE
            FUNCTION = MID(buffer, i, j-i+1)
            buffer = MID(buffer, j+1)
        ENDIF    
    ENDIF
END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION XmlContent (buffer AS STRING, tag AS STRING) AS STRING
' Retrieve 'content' from   <tag attribute="inline_value"> content </tag>
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'
    DIM AS LONG i, j 
    DIM AS STRING ct 

    i = INSTR(LCASE(buffer), "<" + LCASE(tag))
    IF i = 0 THEN EXIT FUNCTION ' opening tag not found

    IF INSTR(tag, " ") = 0 THEN ct = "</" + tag  + ">" ELSE ct = "</" + LEFT(tag, INSTR(tag, " ") - 1) + ">" ' closing tag

    i += LEN(tag) + 1
    j = INSTR(i, buffer, "/>")
    i = INSTR(i, buffer, ">")
    IF i = j+1 THEN EXIT FUNCTION ' <tag attribute='inline_value' />   --> tag has no content

    i += 1
    j = INSTR(i, LCASE(buffer), LCASE(ct))
    IF j = 0 THEN EXIT FUNCTION ' closing tag not found

    FUNCTION = MID(buffer, i, j-i)

END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB ReplaceXmlContentWith (BYREF buffer AS STRING, tag AS STRING, newcontent AS STRING)
' Replace 'content' with 'newcontent' in   <tag attribute="inline_value"> content </tag>
' /or/ transform a   <tag attribute='inline_value' />   into a   <tag attribute='inline_value' > newcontent </tag>
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'
    DIM AS LONG i, j
    DIM ct AS STRING ' closing tag

    i = INSTR(LCASE(buffer), "<" + LCASE(tag))
    IF i = 0 THEN EXIT SUB ' opening tag not found

    IF INSTR(tag, " ") = 0 THEN ct = "</" + tag + ">" ELSE ct = "</" + LEFT(tag, INSTR(tag, " ") - 1) + ">" ' closing tag

    i += LEN(tag) + 1
    j = INSTR(i, buffer, "/>")
    i = INSTR(i, buffer, ">")

    IF i = j+1 THEN            ' <tag attribute='inline_value' />   --> tag found but has no content initialy  --> create it
        buffer = LEFT(buffer, j-1) + ">" + newcontent + ct + MID(buffer, j+2)
    ELSE
        i += 1
        j = INSTR(i, LCASE(buffer), LCASE(ct))
        IF j <> 0 THEN buffer = LEFT(buffer, i-1) + newcontent + MID(buffer, j) ' closing tag found --> replace content
    END IF

END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION InlineContent (buffer AS STRING, param AS STRING) AS STRING
' Retrieve 'inline_value' from   <tag attribute="inline_value"> content </tag>   or from   <tag attribute='inline_value' />
    DIM AS LONG i, j
    DIM t AS STRING

    t = "=" + DQ
    i = INSTR(LCASE(buffer), LCASE(param) + t)              ' double quote, no space around equal sign
    IF i = 0 THEN
        t = "='"
        i = INSTR(LCASE(buffer), LCASE(param) + t)          ' simple quote, no space around equal sign
        IF i = 0 THEN
            t = " = " + DQ
            i = INSTR(LCASE(buffer), LCASE(param) + t)      ' double quote, spaces around equal sign
            IF i = 0 THEN
                t = " = '"
                i = INSTR(LCASE(buffer), LCASE(param) + t)  ' simple quote, spaces around equal sign
            END IF
        END IF
    END IF
    IF i = 0 THEN EXIT FUNCTION ' attribute not found

    i += LEN(param + t)
    j = INSTR(i, LCASE(buffer), RIGHT(t, 1))
    IF j = 0 THEN EXIT FUNCTION ' closing quote not found

    FUNCTION = MID(buffer, i, j-i)

END FUNCTION
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB ReplaceInlineContentWith (BYREF buffer AS STRING, param AS STRING, newvalue AS STRING)
' Replace 'inline_value' with 'newvalue' in first occurence of   <tag attribute="inline_value"> content </tag>   or   <tag attribute="inline_value" />
    DIM AS LONG i, j 
    DIM t AS STRING

    t = "=" + DQ
    i = INSTR(LCASE(buffer), LCASE(param) + t)              ' double quote, no space around equal sign
    IF i = 0 THEN
        t = "='"
        i = INSTR(LCASE(buffer), LCASE(param) + t)          ' simple quote, no space around equal sign
        IF i = 0 THEN
            t = " = " + DQ
            i = INSTR(LCASE(buffer), LCASE(param) + t)      ' double quote, spaces around equal sign
            IF i = 0 THEN
                t = " = '"
                i = INSTR(LCASE(buffer), LCASE(param) + t)  ' simple quote, spaces around equal sign
            END IF
        END IF
    END IF
    IF i = 0 THEN EXIT SUB ' attribute not found

    i += LEN(param + t)
    j = INSTR(i, LCASE(buffer), RIGHT(t, 1))
    IF j = 0 THEN EXIT SUB ' closing quote not found

    buffer = LEFT(buffer, i-1) + newvalue + MID(buffer, j)

END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB ReplaceInlineContentAfterTagWith (BYREF buffer AS STRING, tag AS STRING, param AS STRING, newvalue AS STRING)
' Replace 'inline_value' with 'newvalue' in   <tag attribute="inline_value"> content </tag>   or in   <tag attribute="inline_value" />
    DIM AS LONG i, j, k
    DIM t AS STRING

    k = INSTR(LCASE(buffer), LCASE(tag))
    IF k = 0 AND INSTR(tag, "'") > 0 AND INSTR(tag, DQ) = 0 THEN
        k = INSTR(LCASE(buffer), LCASE(STRREPLACE(tag, "'", DQ)))
    ELSEIF k = 0 AND INSTR(tag, "'") = 0 AND INSTR(tag, DQ) > 0 THEN
        k = INSTR(LCASE(buffer), LCASE(STRREPLACE(tag, DQ, "'")))
    ENDIF
    IF k = 0 THEN EXIT SUB ' tag not found

    t = "=" + DQ
    i = INSTR(k, LCASE(buffer), LCASE(param) + t)              ' double quote, no space around equal sign
    IF i = 0 THEN
        t = "='"
        i = INSTR(k, LCASE(buffer), LCASE(param) + t)          ' simple quote, no space around equal sign
        IF i = 0 THEN
            t = " = " + DQ
            i = INSTR(k, LCASE(buffer), LCASE(param) + t)      ' double quote, spaces around equal sign
            IF i = 0 THEN
                t = " = '"
                i = INSTR(k, LCASE(buffer), LCASE(param) + t)  ' simple quote, spaces around equal sign
            END IF
        END IF
    END IF
    IF i = 0 THEN EXIT SUB ' attribute not found

    j = INSTR(k, buffer, ">")
    IF j < i THEN EXIT SUB ' attribute outside of scope of tag (e.g. <tag ... /> <other_incorrect_tag  attribute_we_are_looking_for...>

    i += LEN(param + t)
    j = INSTR(i, LCASE(buffer), RIGHT(t, 1))
    IF j = 0 THEN EXIT SUB ' closing quote not found

    buffer = LEFT(buffer, i-1) + newvalue + MID(buffer, j)

END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
SUB ReplaceXmlTagWith (BYREF buffer AS STRING, tag AS STRING, newtag AS STRING)
' Replace <tag attribute='inline_value' />   with   <newtag attribute='inline_value' />
' Or replace <tag attribute="inline_value"> content </tag>   with   <newtag attribute="inline_value"> content </newtag>
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'
    DIM AS LONG i, j, k, m
    DIM AS STRING ct, cnt ' closing tags

    i = INSTR(LCASE(buffer), "<" + LCASE(tag))
    IF i = 0 THEN EXIT SUB ' opening tag not found

    IF INSTR(   tag, " ") = 0 THEN  ct = "</" +    tag + ">" ELSE  ct = "</" + LEFT(   tag, INSTR(   tag, " ") - 1) + ">" ' closing tag
    IF INSTR(newtag, " ") = 0 THEN cnt = "</" + newtag + ">" ELSE cnt = "</" + LEFT(newtag, INSTR(newtag, " ") - 1) + ">" ' closing newtag

    m = i + LEN(tag) + 1
    j = INSTR(m, buffer, "/>")
    k = INSTR(m, buffer, ">")

    IF k = j+1 THEN  ' <tag attribute='inline_value' />   --> tag without content --> do a single replace 
        buffer = LEFT(buffer, i) + newtag + MID(buffer, m)
    ELSE
        buffer = LEFT(buffer, i) + newtag + MID(buffer, m)
        j = INSTR(m, LCASE(buffer), LCASE(ct))
        IF j <> 0 THEN buffer = LEFT(buffer, j-1) + cnt + MID(buffer, j + LEN(ct)) ' tag with content --> do a double replace (opening and closing tags)
    END IF

END SUB
'------------------------------------------------------------------------------

'------------------------------------------------------------------------------
FUNCTION RemoveFirstXmlTag (BYREF buffer AS STRING, tag AS STRING, contains AS STRING = "") AS INTEGER
' Remove first occurence of <tag attribute='inline_value' />   or of  <tag attribute="inline_value"> content </tag>
' that contains the string 'contains' (insensitive case research). Return 1 if successful, 0 if not.
' Hint: you can specify a 'tag' to be searched for, or a 'tag attribute'
    DIM AS LONG i, j, k, m
    DIM AS STRING ct ' closing tag

    RemoveFirstXmlTag_FindOccurenceOfTag:
    i = INSTR(i + 1, LCASE(buffer), "<" + LCASE(tag))
    IF i = 0 THEN RETURN 0 ' opening tag not found

    IF INSTR(tag, " ") = 0 THEN ct = "</" + tag + ">" ELSE ct = "</" + LEFT(tag, INSTR(tag, " ") - 1) + ">" ' closing tag

    m = i + LEN(tag) + 1
    j = INSTR(m, buffer, "/>")
    k = INSTR(m, buffer, ">")

    IF k = j + 1 THEN  ' <tag attribute='inline_value' />   --> tag without content
        IF LEN(contains) > 0 THEN
            IF INSTR(LCASE(MID(buffer, i, k-i+1)), LCASE(contains)) = 0 THEN GOTO RemoveFirstXmlTag_FindOccurenceOfTag ' tag doesn't contain string 'contains'
        ENDIF
        IF MID(buffer, k + 1, 1) = LF THEN k += 1
        IF MID(buffer, k + 1, 2) = CRLF THEN k += 2
        buffer = LEFT(buffer, i - 1) + MID(buffer, k + 1)
        RETURN 1
    ELSE
        j = INSTR(m, LCASE(buffer), LCASE(ct))
        IF j <> 0 THEN
            IF LEN(contains) > 0 THEN
                IF INSTR(LCASE(MID(buffer, i, j-i+1)), LCASE(contains)) = 0 THEN GOTO RemoveFirstXmlTag_FindOccurenceOfTag ' tag doesn't contain string 'contains'
            ENDIF
            IF MID(buffer, j + LEN(ct), 1) = LF THEN j += 1
            IF MID(buffer, j + LEN(ct), 2) = CRLF THEN j += 2
            buffer = LEFT(buffer, i - 1) + MID(buffer, j + LEN(ct)) ' tag with content
            RETURN 1
        ENDIF
    END IF

    RETURN 0

END FUNCTION
'------------------------------------------------------------------------------

