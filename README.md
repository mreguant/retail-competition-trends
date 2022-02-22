# Code and data repository for "Smart Meters and Retail Competition: Trends and Challenges"
Authors: Mar Reguant, Jacint Enrich, Ruoyi Li, and Alejandro Mizrahi

Description
--------
This repository replicates the results for the paper "Smart Meters and Retail Competition: Trends and Challenges". The code is written in Julia. The file "main_windows" or "main_macOS" runs all of the code to generate the 2 figures and 2 tables in the paper. Because price data are confidential, this repository replicates the results without them. 

Data Availability and Provenance Statements
----------------------------

### Statement about Rights

- [x] I certify that the author(s) of the manuscript have legitimate access to and permission to use the data used in this manuscript. 

### Summary of Availability

- [ ] All data **are** publicly available.
- [x] Some data **cannot be made** publicly available.
- [ ] **No data can be made** publicly available.

### Details on each Data Source

#### Market share data
> Data on market shares were downloaded from CNMC's 2019 Electricity Retail Market Monitoring Report (https://www.cnmc.es/expedientes/isde02720). Data are available from Q1 2011 to Q4 2019. 

Datafiles: `consumer_data.csv`, `traditional_retailers_list.csv`.

#### Flow data 
> Data on consumers' flows were digitalised from CNMC’s Quarterly Monitoring Reports on Changes of Retailer (https://www.cnmc.es/expedientes?t=IS+SOBRE+CAMBIOS+DE+COMERCIALIZADOR&idambito=All&edit-submit-buscador-expedientes=Buscar&idtipoexp=All&hidprocedim=All). Data are available from Q1 2016 to Q3 2020. 

Datafile: `flow_data.csv`.


#### Smart meter data
> Data on smart meter's adoption were digitalised from CNMC's Equipment Integrated in the Remote Management System Reports (https://www.cnmc.es/expedientes?t=TELEGESTION&idambito=All&edit-submit-buscador-expedientes=Buscar&idtipoexp=All&hidprocedim=All). Data are available from July 2015 to December 2019.  

Datafile: `smart_meter.csv`.


#### Price data 
> Historical data on retail electricity prices were provided by the CNMC and are confidential. 


Dataset list
------------

| Data file                                    | Source          | Notes                                                                  |Provided |
|----------------------------------------------|-----------------|------------------------------------------------------------------------|---------|
| `build/input/consumer_data.csv`              | CNMC            | Quarterly market share data at the market level                        | Yes     |
| `build/input/traditional_retailers_list.csv` | Own elaboration | It is used to relate each retailer to its corresponding group          | Yes     |
| `build/input/flow_data.csv`                  | CNMC            | Consumers' quarterly registrations, dropouts and switchings            | Yes     |
| `build/input/smart_meter.csv`                | CNMC            | Quarterly share of supply points with smart meters at the market level | Yes     |


Computational requirements
---------------------------

### Software Requirements

- Julia (code was last run with version 1.6.2)
  - `CategoricalArrays` v0.9.7
  - `CSV` v0.10.2
  - `DataFrames` v0.22.7
  - `DataStructures` v0.18.11
  - `Dates`
  - `FixedEffectModels` v1.6.3
  - `Ipopt` v0.7.0
  - `JuMP` v0.21.10
  - `RegressionTables` v0.5.3
  - `ShiftedArrays` v1.0.0
  - `Statistics`
  - `StringEncodings` v0.3.5
  - `Plots` v1.23.6
  - `Printf`
- The code "`0_setup.jl`" will install all dependencies. It should be run once.


### Memory and Runtime Requirements

#### Summary

Approximate time needed to reproduce the analyses on a standard 2022 desktop machine:

- [ ] <10 minutes
- [x] 10-60 minutes
- [ ] 1-8 hours
- [ ] 8-24 hours
- [ ] 1-3 days
- [ ] 3-14 days
- [ ] > 14 days
- [ ] Not feasible to run on a desktop machine, as described below.

#### Details

The code was last run on a **11th Gen Intel(R) Core(TM) i5-1135G with Windows 10 Pro**. 


Description of programs/code
----------------------------

- The code `0_setup.jl` installs all required dependencies in Julia.
- The code `build/code/1_create_data_sets.jl` generates the data sets for the choice search model and the regressions.
- The code `analysis/code/2_analysis.jl` computes the calibration in table 1 and the regressions in table 2b. 
- The code `analysis/code/3_plots.jl` generates the figures 1a and 2a.

Instructions to Replicators
---------------------------

- Run `main_windows.bat` (for Windows users) or `main_macOS.sh` (for MAC OS users) to generate all the outputs sequencially. To run Julia from the command line, add Julia to the PATH environment variable. See https://julialang.org/downloads/platform. 

List of tables and programs
---------------------------

The provided code reproduces:

- [ ] All numbers provided in text in the paper
- [ ] All tables and figures in the paper
- [x] Selected tables and figures in the paper, as explained and justified below.


| Figure/Table #    | Program                         | Line Number | Output file                      |
|-------------------|---------------------------------|-------------|----------------------------------|
| Table 1           | analysis/code/2_analysis.jl     | 310         | table_1.tex                      |
| Table 2b          | analysis/code/2_analysis.jl     | 367         | figure_2b.tex                    |
| Figure 1a         | analysis/code/3_plots.jl        | 108         | figure_1a.png                    |  
| Figure 2a         | analysis/code/3_plots.jl        | 173         | figure_2a.png                    | 
