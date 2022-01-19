# Compute quarterly retailing costs as an instrument for prices
### Final price (which accounts for retailing costs for cur/ncur)
# weighted by hourly demand (in mwh)

###### Load packages

using CSV
using Dates
using DataFrames
using Statistics
using TimeZones
using StatFiles

cd(dirname(dirname(@__DIR__)))


### Hourly demand
#############################################################################################

hourly_demand = CSV.read("build/input/hourly_consumption.csv",DataFrame)
names(hourly_demand)
rename!(hourly_demand, :value => :demand)
# show(describe(hourly_demand), allrows=true)

unique(hourly_demand.name)
replace!(hourly_demand.name, 
    "Demanda medida discriminación horaria E1 TARIFA DE UN PERIODO" => "flat", 
    "Demanda medida discriminación horaria E2 TARIFA DE DOS PERIODOS" => "tou")

# Date
hourly_demand.datetime=string.(hourly_demand.datetime)
format="yyyy-mm-ddTHH:MM:SSzzzz"
hourly_demand.datetime=ZonedDateTime.(hourly_demand.datetime,format)
hourly_demand.datetime=DateTime.(hourly_demand.datetime)
hourly_demand.date=Date.(hourly_demand.datetime)
hourly_demand.time=Time.(hourly_demand.datetime)

# Select
hourly_demand=select(hourly_demand,:datetime,:date,:time,:name,:demand)

# Add year, month, quarter and hour
hourly_demand.year=parse.(Int,string.(year.(hourly_demand.datetime)))
hourly_demand.month=parse.(Int,string.(month.(hourly_demand.datetime)))
hourly_demand.day=parse.(Int,string.(day.(hourly_demand.datetime)))
hourly_demand.quarter=quarterofyear.(hourly_demand.datetime)
hourly_demand.hour=parse.(Int,string.(hour.(hourly_demand.time)))


### Hourly retailing costs
#############################################################################################

cost = load("build/input/hourly_retailing_costs.dta") |> DataFrame
names(cost)
#show(describe(cost), allrows=true)

# JOIN 

cost.year = round.(Int,cost.year)
cost.month = round.(Int,cost.month)

df_cost = leftjoin(hourly_demand, cost, on = [:year, :month, :day, :hour])
#show(describe(df_cost), allrows=true)

### Weighted prices

dropmissing!(df_cost,[:demand, :prmecur, :prmncur ])

df_cost_quarter = combine(groupby(df_cost, [:quarter, :year]), 
    [:demand, :prmecur, :prmncur ] => ((d, cc, cnc) -> 
    (cost_reg = (sum(cc .* d)) / sum(d),
    cost_com = (sum(cnc .* d)) / sum(d))) => [:cost_reg, :cost_com])

# write
CSV.write("build/output/retailing_costs.csv",df_cost_quarter)

println("\n
The file retailing_costs.csv has been successfully created in the output folder.")
