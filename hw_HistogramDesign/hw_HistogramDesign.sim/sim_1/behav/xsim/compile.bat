@echo off
REM ****************************************************************************
REM Vivado (TM) v2022.1 (64-bit)
REM
REM Filename    : compile.bat
REM Simulator   : Xilinx Vivado Simulator
REM Description : Script for compiling the simulation design source files
REM
REM Generated by Vivado on Thu Oct 31 16:46:47 +0200 2024
REM SW Build 3526262 on Mon Apr 18 15:48:16 MDT 2022
REM
REM IP Build 3524634 on Mon Apr 18 20:55:01 MDT 2022
REM
REM usage: compile.bat
REM
REM ****************************************************************************
REM compile VHDL design sources
echo "xvhdl --incr --relax -prj Tb_FineGrainedBRAMBucket_simple_vhdl.prj"
call xvhdl  --incr --relax -prj Tb_FineGrainedBRAMBucket_simple_vhdl.prj -log xvhdl.log
call type xvhdl.log > compile.log
if "%errorlevel%"=="1" goto END
if "%errorlevel%"=="0" goto SUCCESS
:END
exit 1
:SUCCESS
exit 0
