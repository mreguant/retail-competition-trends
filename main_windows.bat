@ECHO OFF
ECHO =====================================================================
ECHO = 									 	
ECHO =   This file will generate all the outputs included in the paper.  
ECHO = 									 
ECHO =====================================================================

ECHO The path of the "retail-competition-trends" repository is defined as current directory:
ECHO Current directory: %~dp0
CD %~dp0

ECHO =
ECHO =====================================================================
ECHO Add Julia to the PATH to run Julia from the command line. See: https://julialang.org/downloads/platform/ 
SET PATH = %PATH%
ECHO Alternatively, type the path were the Julia program is located.
ECHO Example: C:\Users\Alejandro\AppData\Local\Programs\Julia-1.6.2\bin
SET /p JULIA_PATH= Path to Julia's program (ommit this step by pressing Enter): 
SET PATH=%PATH%;%JULIA_PATH%

ECHO =
ECHO =====================================================================
ECHO Required packages are being installed.
JULIA 0_setup.jl

ECHO =
ECHO =====================================================================
ECHO Cleaning datasets . . .
JULIA build\code\1_create_data_sets.jl

ECHO =
ECHO =====================================================================
ECHO Running analysis to generate tables and figures . . .
JULIA analysis\code\2_analysis.jl
JULIA analysis\code\3_plots.jl
ECHO END.

ECHO =
ECHO =====================================================================
ECHO =					
ECHO =				BARCELONA ENERGY HUB         		
ECHO =					
ECHO =====================================================================
PAUSE

