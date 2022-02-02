##################################################################################################################################################################################
#
# CLEANING AND COMBINING DATA SETS 
#
##################################################################################################################################################################################



# Load packages
using DataFrames
using CSV
using StringEncodings
using ShiftedArrays


# Setting working directory 
cd(dirname(dirname(@__DIR__)))




# 1. Preparing consumer_data.csv
#_________________________________________________________________________________________________________________________________________________________________________________

# Load data 
df = DataFrame(CSV.File(read("build/input/consumer_data.csv", enc"windows-1250")))
retailers = DataFrame(CSV.File(read("build/input/traditional_retailers_list.csv", enc"windows-1250")))

# Rename 
rename!(df, "FECHA"=>"date","COD_DIS"=>"market", "DES_TIPO_TAR_ACC"=>"tariff", "Suma de NUMERO_SUMINISTROS"=>"consumer")
df.date=replace.(df.date,"_T" => " Q")


# Subset domestic segment
unique(df.tariff) 
df=df[(df.tariff.=="2.0A").|(df.tariff.=="2.1A").|(df.tariff.=="2.0NA-DHA").|(df.tariff.=="2.1DHA"),:]

# Subset of integrated distributors
distr=["R1-001","R1-299","R1-002","R1-008","R1-005","R1-003"]
df=df[in(distr).(df.market), :]
df.market=string.(df.market)
replace!(df.market, "R1-001" => "IBERDROLA")
replace!(df.market, "R1-299" => "ENDESA")
replace!(df.market, "R1-002" => "NATURGY")
replace!(df.market, "R1-008" => "EDP")
replace!(df.market, "R1-005" => "REPSOL")
replace!(df.market, "R1-003" => "REPSOL")

# Obtain groups and retailers relations
df=leftjoin(df,retailers,on=[:COD_COM=>:cod])


# If the retailer is not present in retailers list it must be commercial
replace!(df.regulated,missing => false) 
replace!(df.group, missing => "OTHERS")

# Regulated only in market == group
df=df[((df.regulated.==true).&(df.market.==df.group)).|(df.regulated.==false),:]

# Create variables 
df.tou=ifelse.(contains.(df.tariff,"DHA"),1,0)
df[:,"incumbent"] = ifelse.(df.group .== df.market, 1, 0)
df.year=parse.(Int64,SubString.(df.date,1,4))
df.quarter=parse.(Int64,SubString.(df.date,7,7))


# Aggregate by date, market, group, regulated and tou
df=combine(groupby(df, [:date,:year,:quarter,:market,:group,:tariff,:tou,:regulated,:incumbent,]),:consumer.=> sum .=> :consumer)





# 2. Adding Prices and Smart Meter Data
#_________________________________________________________________________________________________________________________________________________________________________________

# 2.1 Smart meter 
meter = CSV.read("build/input/smart_meter.csv", DataFrame)
meter.date=replace.(meter.date,"_T" => " Q")
df = leftjoin(df,meter, on = [:market, :date])
dropmissing!(df,:smartmeter)


# Write the file
##################################################################################################################################################################################
try
    mkdir("analysis/input")
catch
    nothing
end
CSV.write("analysis/input/smart_meter_regression_dataset.csv", df)
##################################################################################################################################################################################




# 2.2 Prices 
# Convert monthly prices to quarterly 
monthly_prices = CSV.read("build/input/monthly_prices.csv",DataFrame)

mp_com = monthly_prices[monthly_prices.retailer_type .== "commercial",:]
mp_reg = monthly_prices[monthly_prices.retailer_type .== "regulated",:]

regulated = copy(mp_reg)

for i in unique(mp_com.retailer)
    r = copy(mp_reg);
    r.retailer .= i
    global regulated = [regulated;r] 
end 

filter!(row -> row.retailer!="COR", regulated)

monthly_prices = [regulated; mp_com]


monthly_prices.quarter = ifelse.(
    monthly_prices.month.<4,1,ifelse.(
        monthly_prices.month.<7,2,ifelse.(
            monthly_prices.month.<10,3,4)))


prices = combine(groupby(monthly_prices,[:year, :quarter,:retailer, :tariff, :retailer_type, :power]), :energy_price  => mean => :price)


# Incorporate prices into consumer_data.csv dataset
prices[:,"regulated"] = ifelse.(prices.retailer_type .== "regulated",1, 0)
replace!(df.tariff,"2.0NA-DHA" =>"2.0DHA")
df = leftjoin(df,prices, on = [:year, :quarter, :regulated, :tariff, :group => :retailer])
sort!(df,[:market,:group,:date,:regulated])
select!(df,Not([:retailer_type, :power]))













# 3. Aggregate at Group Level 
#_________________________________________________________________________________________________________________________________________________________________________________

df1 = deepcopy(df)

# Computing average price from those tariffs we observe them
df1.price_mis = copy(df1.price)
replace!(df1.price_mis, missing => 0)
df1.cons_price_mis = ifelse.(df1.price_mis.==0,0,df1.consumer)

df1_agg = combine(groupby(df1, [:date,:year,:quarter,:market,:group,:regulated,:incumbent,:smartmeter]),
        [:cons_price_mis,:price_mis] => ((cm, p) ->
        (sum( p .* cm ) / sum(cm))) 
        => :price
)

df1_agg.price = ifelse.(isnan.(df1_agg.price), missing, df1_agg.price)

# Recover consumers (aggregated)
col_consumer = combine(groupby(df1, [:date,:year,:quarter,:market, :group,:regulated,:incumbent,:smartmeter]), :consumer => sum => :consumer)
df1_agg.consumer = col_consumer.consumer

# Compute totals 
transform!(groupby(df1_agg, [:date, :market]), :consumer => sum => :consumer_market)
transform!(groupby(df1_agg, [:date, :market,:regulated]), :consumer => sum => :consumer_commercial)

# Incumbent 
df_inc = filter(row -> (row.incumbent ==1),df1_agg)
df_inc_cons = unstack(df_inc, [:date,:year,:quarter,:market], :regulated, :consumer, renamecols = x -> Symbol("consumer_", x))
df_inc_price = unstack(df_inc, [:date,:year,:quarter,:market], :regulated, :price, renamecols = x -> Symbol("price_", x))
df_inc = leftjoin(df_inc_cons,df_inc_price,on=[:date,:year,:quarter,:market])

# Commercial (not incumbent )
df_com = filter(row ->row.regulated ==0, df1_agg)
df_com_cons = unstack(df_com, [:date,:year,:quarter,:market,:smartmeter,:consumer_commercial,:consumer_market], :group, :consumer, renamecols = x -> Symbol("consumer_", x))
df_com_price = unstack(df_com, [:date,:year,:quarter,:market], :group, :price, renamecols = x -> Symbol("price_", x))
df_com = leftjoin(df_com_cons,df_com_price,on=[:date,:year,:quarter,:market])

# Merge
df_wide = leftjoin(df_inc,df_com,on=[:date,:year,:quarter,:market])




# 4. Merge with Flow Data
#_________________________________________________________________________________________________________________________________________________________________________________

df2 = CSV.read("build/input/flow_data.csv",DataFrame, missingstring="NA")
rename!(df2,:group => :market,:consumer_reg => :consumer_reg_fdata)
select!(df2,:date,:market,:year,:quarter,:consumer_reg_fdata,:registration_distr_reg,:switch_reg_com => :switch_reg_inc,:switch_reg_others,:switch_com_reg=>:switch_inc_reg,:switch_others_reg)
df2 = filter(row -> row.consumer_reg_fdata > 0 , df2) 


# Merge 
dfinal = innerjoin(df_wide,df2,on=[:date,:year,:quarter,:market])
rename!(dfinal,:consumer_false => :consumer_inc,:consumer_true => :consumer_reg,:price_false => :price_inc,:price_true => :price_reg)


# Correct registration's size
cols_flow = select(dfinal,:registration_distr_reg,:switch_reg_inc,:switch_reg_others,:switch_inc_reg,:switch_others_reg) ./ dfinal.consumer_reg_fdata .*dfinal.consumer_reg
select!(dfinal,Not([:price_OTHERS,:registration_distr_reg,:switch_reg_inc,:switch_reg_others,:switch_inc_reg,:switch_others_reg]))
dfinal = [dfinal cols_flow] 


# Lags
sort!(dfinal,[:market,:date])
transform!(groupby(dfinal,:market), [:consumer_reg,:consumer_inc,:consumer_commercial,:consumer_market,
            :consumer_ENDESA,:consumer_IBERDROLA,:consumer_NATURGY,:consumer_OTHERS,:consumer_REPSOL,:consumer_EDP] .=> lag)

# Switching
dfinal.reg_switch_out = dfinal.switch_reg_inc + dfinal.switch_reg_others
dfinal.reg_switch_in = dfinal.switch_inc_reg + dfinal.switch_others_reg

# Identities
dfinal.lambdas = (dfinal.consumer_commercial_lag .* dfinal.reg_switch_out + dfinal.reg_switch_in .*dfinal.consumer_reg_lag) ./ (dfinal.consumer_commercial_lag .* dfinal.consumer_reg_lag);
dfinal.P = ( dfinal.reg_switch_in .*dfinal.consumer_reg_lag) ./ (dfinal.consumer_commercial_lag .* dfinal.reg_switch_out + dfinal.reg_switch_in .*dfinal.consumer_reg_lag)
dfinal.Pi =  dfinal.switch_reg_inc ./ (dfinal.consumer_reg_lag .* dfinal.lambdas)
dfinal.Po =  dfinal.switch_reg_others ./ (dfinal.consumer_reg_lag .* dfinal.lambdas)






# Write the file
##################################################################################################################################################################################
CSV.write("analysis/input/choice_search_dataset.csv", dfinal)
##################################################################################################################################################################################
