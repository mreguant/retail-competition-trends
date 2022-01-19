###################################
# RETAIL COMPETITION - Merging market shares with prices, costs, and smart meter data
###################################

###### Load packages

using CSV
using StatFiles
using DataFrames 
using Dates
using Statistics
using ShiftedArrays
using Plots

cd(dirname(dirname(@__DIR__)))

###############################################################################

# 0. Preparing Data

###############################################################################

df = CSV.read("build/output/market_shares.csv",DataFrame,missingstring="NA")
names(df)
# show(describe(df),allrows=true)

df[:,:year] = parse.(Int,SubString.(df.date,1,4))
df[:,:quarter] = parse.(Int,SubString.(df.date,7))
df.date = Date.(df.year, df.quarter .* 3, 28)

###############################################################################

# 1. Adding Prices

###############################################################################

## 1.1 Converting monthly prices to quarterly 

monthly_prices = CSV.read("build/input/monthly_prices.csv",DataFrame)
#show(describe(monthly_prices),allrows=true)

rename!(monthly_prices, :power => :contracted_power)

names(monthly_prices)

monthly_prices.quarter = ifelse.(
    monthly_prices.month.<4,1,ifelse.(
        monthly_prices.month.<7,2,ifelse.(
            monthly_prices.month.<10,3,4)))

prices = combine(groupby(
    monthly_prices,[:year, :quarter,:retailer, :tariff, :retailer_type, :contracted_power]), 
    ["energy_price", "total_bill", "energy_consumption", "power_bill", "energy_bill"]  .=> mean .=> 
    ["energy_price", "total_bill", "energy_consumption", "power_bill", "energy_bill"])

names(prices)
#show(describe(prices),allrows=true)

# Incorporate prices into primary dataset

prices[:,"regulated"] = ifelse.(prices.retailer_type .== "commercial",false, true)

# Merge 

df[df.tariff .== "2.0NA-DHA", :tariff] .= "2.0DHA"

unique(df.group)
unique(prices.retailer)

df = leftjoin(df,prices, on = [:year, :quarter, :regulated, :tariff, :group => :retailer])
# show(describe(df),allrows=true)


# Use cost shifters as instruments for prices: gas prices in Spain

gas_price = load("build/input/natural_gas_prices.dta") |> DataFrame
names(gas_price)

gas_price.quarter = ifelse.(
    gas_price.month.<4,1,ifelse.(
        gas_price.month.<7,2,ifelse.(
            gas_price.month.<10,3,4)))

quarter_gas = combine(groupby(gas_price,[:year, :quarter]), "ng_spot_p" => mean => :gas_price)
names(quarter_gas)
sum(ismissing.(quarter_gas.gas_price))

# add gas prices

df = leftjoin(df, quarter_gas, on = [:year, :quarter], makeunique=true)
#show(describe(df),allrows=true)

# add retailing costs (differentiated for regulated or not)

cost = CSV.read("build/output/retailing_costs.csv", DataFrame)
cost_com_reg = stack(cost, [:cost_reg, :cost_com])
rename!(cost_com_reg, :value => :retailing_cost )
cost_com_reg[:,:regulated] = ifelse.(cost_com_reg.variable .== "cost_reg",1,0)
df = leftjoin(df, cost_com_reg, on = [:year, :quarter,:regulated], makeunique=true)
#show(describe(df),allrows=true)

# Add Smart Meter data

meters = CSV.read("build/input/smart_meter.csv", DataFrame)
unique(meters.FECHA)
unique(meters.group)

meters[meters.group .== "GAS NATURAL",:group] .= "NATURGY"

df[:,"FECHA"] = string.(df.year,"_T",df.quarter)
df = leftjoin(df,meters, on = [:market => :group, :FECHA], makeunique = true)
#show(describe(df),allrows=true)
df = select(df,Not(:FECHA))



# Other controls and details

df.energy_price = df.energy_price .* 100 # turn prices into cents

ordered_quarter = sort!(unique(df[:,[:year, :quarter]]),[:year,:quarter])
ordered_quarter[:,:ordered_quarter] = 1:nrow(ordered_quarter)

df = leftjoin(df, ordered_quarter, on = [:year, :quarter], makeunique = true)
#show(describe(df),allrows=true)

sort!(df,[:market, :group, :tariff, :date])
df_lag = copy(df)
df_lag = combine(groupby(df_lag,[:market, :group, :tariff]), [:energy_price,:gas_price, :retailing_cost] .=> lag)
df[:,:energy_price_lag] = df_lag.energy_price_lag
df[:,:gas_price_lag] = df_lag.gas_price_lag
df[:,:retailing_cost_lag] = df_lag.retailing_cost_lag

##########
# Write full database with controls
##########

CSV.write("build/output/first_stage_dataset.csv", df)

println("\n
The file first_stage_dataset.csv has been successfully created in the build/output folder.")
