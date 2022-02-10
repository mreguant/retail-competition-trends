#!/bin/bash

echo "====================================================================="
echo								 	
echo "   This file will generate all the outputs included in the paper.    "
echo									 
echo "====================================================================="
read -p "Press [Enter] key to continue..."

echo "The path of the 'retail-competition-trends' repository is defined as current directory:"
pwd

read -p "Press [Enter] key to continue..."

echo
echo "====================================================================="
echo "Before proceeding, make sure your terminal recognizes julia as a command."
echo "You can make sure julia is recognized by typying sth similar to:"
echo "sudo ln -s /Applications/Julia-1.7.app/Contents/Resources/julia/bin/julia /usr/local/bin/julia"

read -p "Press [Enter] key to continue..."

echo
echo "====================================================================="
echo "Required packages are being installed."
julia 0_setup.jl
echo "Required packages have been successfully installed"

echo 
echo "====================================================================="
echo "Cleaning datasets . . ."
julia build/code/1_create_data_sets.jl

echo 
echo "====================================================================="
echo "Running analysis to generate tables and figures . . ."
julia analysis/code/2_analysis.jl
julia analysis/code/3_plots.jl
echo "END."

echo
echo "===================================================================="
echo					
echo "				BARCELONA ENERGY HUB         		"
echo					
echo "===================================================================="
