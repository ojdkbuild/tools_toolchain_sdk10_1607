@REM
@REM Copyright (c) Microsoft Corporation.  All rights reserved.
@REM
@REM
@REM Use of this source code is subject to the terms of the Microsoft
@REM premium shared source license agreement under which you licensed
@REM this source code. If you did not accept the terms of the license
@REM agreement, you are not authorized to use this source code.
@REM For the terms of the license, please see the license agreement
@REM signed by you and Microsoft.
@REM THE SOURCE CODE IS PROVIDED "AS IS", WITH NO WARRANTIES OR INDEMNITIES.
@REM
@REM ============================================================
@REM  Script to generate merged winmd file during installation
@REM  or uninstallation of ExtensionSDKs
@REM ============================================================

@echo off
SETLOCAL

REM Copyright display
ECHO Microsoft (R) Generate UnionWinMD Tool version 10.0.2
ECHO Copyright (c) Microsoft Corporation
ECHO All rights reserved.

REM Show usage text
set SHOW_HELP=
if /i "%~1" == "/?" set SHOW_HELP=1
if /i "%~1" == "-?" set SHOW_HELP=1
if /i "%~1" == "/help" set SHOW_HELP=1
if /i "%~1" == "-help" set SHOW_HELP=1
if /i "%SHOW_HELP%" == "1" (
    ECHO.
    ECHO GenerateUnionWinMD.cmd unifies all existing contract winmd files
    ECHO under the "<SDKRoot>\<Version>\References\" into a single union winmd. 
    ECHO This union winmd will be named Windows.winmd and generated under
    ECHO "<SDKRoot>\<Version>\UnionMetadata\Windows.winmd". This command line
    ECHO utility does not take any arguments as input
    ECHO.
    ECHO Must be run from an elevated command prompt.
    EXIT /B 0
)

REM Check for elevation
fltmc >nul 2>&1
if ERRORLEVEL 1 (
    ECHO Error: You must run this script from an elevated command prompt.
    EXIT /B 5
) else (
    ECHO Confirmed running as administrator.
)

ECHO.
ECHO Generating a Union WinMD file of all winmd files in the SDK. 

REM Get SDK install folder from the registry
set SDKInstallFolder = ""
for /F "tokens=2* delims=	 " %%A IN ('REG QUERY "HKLM\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0" /v InstallationFolder') DO SET SDKInstallFolder=%%B

if NOT EXIST "%SDKInstallFolder%" (
    for /F "tokens=2* delims=	 " %%A IN ('REG QUERY "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0" /v InstallationFolder') DO SET SDKInstallFolder=%%B
)

REM Exit if you can't find the SDK install folder
if NOT EXIST "%SDKInstallFolder%" (
    ECHO Error: Can't find the SDK install folder: "%SDKInstallFolder%". Please install the Windows SDK before running this tool.
    EXIT /B 3
)

echo An SDK was found at the following location: %SDKInstallFolder%

set MDFolder=%temp%\UnionWinmdWorkingFolder
set RandomName=%RANDOM%
set MDFullPath=%MDFolder%\%RandomName%
set MDFileName=%RandomName%

ECHO Deleting all temp folders
if EXIST "%MDFullPath%" (
    rmdir /S /Q "%MDFullPath%"
)
echo Deleted all the temp folders

echo Re-creating temp folders

md "%MDFullPath%\WinMDs"
md "%MDFolder%\Logs"

echo Re-created temp folders

echo Created Logs folder and WinMDs folder in filepath: %MDFolder%\Logs

REM Locate latest version of a contract winmd
REM Contract winmds are versioned using x.x.x.x folder names, where x is a decimal number
ECHO Locating WinMDs in SDK References folder
setlocal enableextensions enabledelayedexpansion
for /f "tokens=*" %%G in ('dir /b /ON /AD "%SDKInstallFolder%References"') do (
    set /A LoopCount = 0
    REM List all folders in reverse sorted order (so that latest version is listed first)
    for /f "tokens=*" %%J in ('dir /b /s /AD /O-N "%SDKInstallFolder%References\%%G"') do (
        REM Use only the first item from the list (i.e. the latest version)
        if !LoopCount! == 0 (
            REM Copy WinMD files to a temp folder as mdmerge takes a folder as input
            copy "%%J\*.winmd" "%MDFullPath%\WinMDs\" >> "%MDFolder%\Logs\%MDFileName%-MDMerge.log" 2>>"%MDFolder%\Logs\%MDFileName%-MDMerge.err
        )
        set /A LoopCount += 1
    )
)
endlocal

REM Delete Windows.winmd as we don't want to include that in our union winmd
if EXIST "%MDFullPath%\WinMDs\Windows.winmd" (
    del "%MDFullPath%\WinMDs\Windows.winmd"
)
ECHO Removed Windows.winmd as we dont want to include that in our union winmd

ECHO Creating UnionWinMD using mdmerge tool
if NOT EXIST "%SDKInstallFolder%UnionMetadata\" (
    md "%SDKInstallFolder%UnionMetadata\"
    ECHO Created folder "%SDKInstallFolder%UnionMetadata\"
)

REM Run MDMerge tool passing in the temp folder containing winmd files
REM Assumes run out of X86 folder
"%SDKInstallFolder%bin\x86\MDMerge.exe" -n:1 -v -i "%MDFullPath%\WinMDs" -o "%SDKInstallFolder%UnionMetadata" >> "%MDFolder%\Logs\%MDFileName%-MDMerge.log" 2>>"%MDFolder%\Logs\%MDFileName%-MDMerge.err"

if ERRORLEVEL 1 (
    ECHO MDMerge failed. Please check See MDMerge tool logs at %MDFolder%\Logs\%MDFileName%-MDMerge.log and %MDFolder%\Logs\%MDFileName%-MDMerge.err
    EXIT /B %ERRORLEVEL%
) else (
    ECHO MDMerge Succeded and Windows.winmd placed in "%SDKInstallFolder%UnionMetadata" folder
)

if NOT EXIST "%SDKInstallFolder%UnionMetadata\Windows.winmd" (
    ECHO Error: Failed to build Union WinMD. See MDMerge tool logs at %MDFolder%\Logs\%MDFileName%-MDMerge.log and %MDFolder%\Logs\%MDFileName%-MDMerge.err
    EXIT /B 2
)

ECHO Clean up temp files
if EXIST "%MDFullPath%\WinMDs" (
    rmdir /S /Q "%MDFullPath%\WinMDs"
)

EXIT /B 0

ENDLOCAL