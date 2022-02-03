@ECHO OFF
ECHO =====================================================================
ECHO = 									 	
ECHO =   This file will generate all the outputs included in the paper.  
ECHO = 									 
ECHO =====================================================================
PAUSE

ECHO The path of the "retail-competition-trends" repository is defined as current directory:
ECHO Current directory: %~dp0
CD %~dp0
PAUSE


ECHO =====================================================================
ECHO Type the path were the Julia program is located.
ECHO Example: C:\Users\Alejandro\AppData\Local\Programs\Julia-1.6.2\bin
ECHO Windows Users can find it in their shortcut to Julia .exe file on Properties/Target
SET /p JULIA_PATH= Path to Julia's program: 
SET PATH=%JULIA_PATH%


ECHO =====================================================================
ECHO Required packages are being installed.
ECHO JULIA 0_setup.jl
ECHO Required packages have been successfully installed
PAUSE

ECHO =====================================================================
ECHO Cleaning datasets . . .
JULIA build\code\1_create_data_sets.jl
PAUSE

ECHO =====================================================================
ECHO Running analysis to generate tables and figures . . .
JULIA analysis\code\2_analysis.jl
JULIA analysis\code\3_plots.jl
ECHO END.

ECHO =====================================================================
ECHO =					
ECHO =				BARCELONA ENERGY HUB         		
ECHO =					
ECHO =====================================================================
PAUSE

