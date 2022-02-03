@ECHO OFF

ECHO This file will generate all the outputs included in the paper. 
PAUSE

ECHO The path of the "retail-competition-trends" repository is defined as current directory:
ECHO Current directory: %~dp0
CD %~dp0
PAUSE

ECHO Type the path were the Julia program is located.
ECHO Example: C:\Users\Alejandro\AppData\Local\Programs\Julia-1.6.2\bin
ECHO Windows Users can find it in their shortcut to Julia .exe file on Properties/Target
SET /p JULIA_PATH= Path to Julia's program: 
ECHO %JULIA_PATH%
PAUSE
ECHO %PATH%
SET PATH=%JULIA_PATH%
PAUSE

ECHO Required packages are being installed.
ECHO JULIA 0_setup.jl
ECHO Required packages have been successfully installed
PAUSE

ECHO Clean and merge datasets
JULIA build\code\1_create_data_sets.jl
ECHO The following datasets have been created:
ECHO 1,2,3,4
PAUSE

ECHO Run analysis and generate tables and figures
JULIA analysis\code\2_regressions.jl
JULIA analysis\code\3_plots.jl
ECHO Outputs have been successfully generated. End.
PAUSE
