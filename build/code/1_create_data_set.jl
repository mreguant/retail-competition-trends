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
rename!(retailers, :ref => :regulated)

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

# 2.1 Prices 
# Convert monthly prices to quarterly 
monthly_prices = CSV.read("build/input/monthly_prices.csv",DataFrame)

mp_com = monthly_prices[monthly_prices.retailer_type .== "commercial",:]
mp_cor = monthly_prices[monthly_prices.retailer_type .== "regulated",:]

mp_cor_EDP = copy(mp_cor)
mp_cor_EDP.retailer .= "EDP"

mp_cor_ENDESA = copy(mp_cor)
mp_cor_ENDESA.retailer .= "ENDESA"

mp_cor_IBERDROLA = copy(mp_cor)
mp_cor_IBERDROLA.retailer .= "IBERDROLA"

mp_cor_NATURGY = copy(mp_cor)
mp_cor_NATURGY.retailer .= "NATURGY"

mp_cor_REPSOL = copy(mp_cor)
mp_cor_REPSOL.retailer .= "REPSOL"

mp_cor = [mp_cor_EDP; mp_cor_ENDESA; mp_cor_IBERDROLA; mp_cor_NATURGY; mp_cor_REPSOL]

monthly_prices = [mp_cor; mp_com]


monthly_prices.quarter = ifelse.(
    monthly_prices.month.<4,1,ifelse.(
        monthly_prices.month.<7,2,ifelse.(
            monthly_prices.month.<10,3,4)))


prices = combine(groupby(monthly_prices,[:year, :quarter,:retailer, :tariff, :retailer_type, :power]), :energy_price  => mean => :energy_price)
rename!(prices,"energy_price"=>"price")

# Incorporate prices into consumer_data.csv dataset
prices[:,"regulated"] = ifelse.(prices.retailer_type .== "regulated",1, 0)
replace!(df.tariff,"2.0NA-DHA" =>"2.0DHA")
df = leftjoin(df,prices, on = [:year, :quarter, :regulated, :tariff, :group => :retailer])
sort!(df,[:market,:group,:date,:regulated])


# 2.2 Smart meter 
meter = CSV.read("build/input/smart_meter.csv", DataFrame)
meter.date=replace.(meter.date,"_T" => " Q")
df = leftjoin(df,meter, on = [:market, :date])






# Write the output file
##################################################################################################################################################################################
try
    mkdir("analysis/input")
catch
    nothing
end
CSV.write("analysis/input/smart_meter_regression_dataset.csv", df)
##################################################################################################################################################################################







# 3. Aggregate at Group Level 
#_________________________________________________________________________________________________________________________________________________________________________________

df1 = deepcopy(df)

# Computing average price from those tariffs we observe them
df1.price_nan = copy(df1.price)
replace!(df1.price_nan, missing => 0)
df1.cons_price_nan = ifelse.(df1.price_nan.==0,0,df1.consumer)

df1 = combine(groupby(df1, [:date,:market,:group,:year,:incumbent,:regulated,:smartmeter]),
        [:cons_price_nan,:price_nan,:consumer] => ((cn, p, c) ->
        (sum( p .* cn ) / sum(cn))) 
        => :price
)
df1.price = ifelse.(isnan.(df1.price), missing, df1.price)

col_consumer = combine(groupby(df, [:date, :market, :group, :year,:incumbent,:regulated,:smartmeter]), :consumer => sum => :consumer)
df1.consumer = col_consumer.consumer

# Compute totals 
transform!(groupby(df1, [:date, :market]), :consumer => sum => :consumer_market)
transform!(groupby(df1, [:date, :market,:regulated]), :consumer => sum => :consumer_comercial)

# Incumbent 
df_inc = filter(row -> (row.incumbent ==1),df1)
df_inc_cons = unstack(df_inc, [:date,:market], :regulated, :consumer, renamecols = x -> Symbol("consumer_", x))
df_inc_price = unstack(df_inc, [:date,:market], :regulated, :price, renamecols = x -> Symbol("price_", x))
df_inc = leftjoin(df_inc_cons,df_inc_price,on=[:date,:market])

# Commercial (not incumbent )
df_com = filter(row ->row.regulated ==0, df1)
df_com_cons = unstack(df_com, [:date,:market,:smartmeter,:consumer_comercial,:consumer_market], :group, :consumer, renamecols = x -> Symbol("consumer_", x))
df_com_price = unstack(df_com, [:date,:market], :group, :price, renamecols = x -> Symbol("price_", x))





# 4. Merge with Flow Data
#_________________________________________________________________________________________________________________________________________________________________________________

df2 = CSV.read("build/input/flow_data.csv",DataFrame, missingstring="NA")
rename!(df2,:group => :market,:consumer_reg => :consumer_reg_fdata)
select!(df2,:date,:market,:year,:quarter,:consumer_reg_fdata,:registration_distr_reg,:switch_reg_com,:switch_reg_others,:switch_com_reg,:switch_others_reg)
df2 = dropmissing(df2,:consumer_reg_fdata)
df2 = filter(row -> row.consumer_reg_fdata > 0 , df2) 


# Merge 
df = leftjoin(df_inc,df_com_cons,on=[:date,:market]) |>
(y -> leftjoin(y,df_com_price,on=[:date,:market])) |>
(w -> leftjoin(w,df2,on=[:date,:market]))

rename!(df,:consumer_false => :consumer_inc,:consumer_true => :consumer_reg,:price_false => :price_inc,:price_true => :price_reg)


# Correct registration's size
col_registration = select(df,:registration_distr_reg,Between(:switch_com_reg,:switch_reg_others)) ./ df.consumer_reg_fdata .*df.consumer_reg
select!(df,Not([:price_OTHERS,:registration_distr_reg]))
df = [df col_registration] 

# Common periods
df.year = parse.(Int64,SubString.(df.date,1,4))
filter!(row -> row.year >2015, df)
filter!(row -> row.year <2020, df)

# Lags
sort!(df,[:market,:date])
transform!(groupby(df,:market), [:consumer_reg,:consumer_inc,:consumer_comercial,:consumer_market,
            :consumer_ENDESA,:consumer_IBERDROLA,:consumer_NATURGY,:consumer_OTHERS,:consumer_REPSOL,:consumer_EDP] .=> lag)

# Switching
df.reg_switch_out = df.switch_reg_com + df.switch_reg_others
df.reg_switch_in = df.switch_com_reg + df.switch_others_reg

# Identities
df.lambdas = (df.consumer_comercial_lag .* df.reg_switch_out + df.reg_switch_in .*df.consumer_reg_lag) ./ (df.consumer_comercial_lag .* df.consumer_reg_lag);
df.P = ( df.reg_switch_in .*df.consumer_reg_lag) ./ (df.consumer_comercial_lag .* df.reg_switch_out + df.reg_switch_in .*df.consumer_reg_lag)
df.Pi =  df.switch_reg_com ./ (df.consumer_reg_lag .* df.lambdas)
df.Po =  df.switch_reg_others ./ (df.consumer_reg_lag .* df.lambdas)




