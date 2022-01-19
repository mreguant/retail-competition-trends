# Compute market shares

###### Load packages

using DataFrames
using CSV
using StringEncodings

cd(dirname(dirname(@__DIR__)))

###############################################################################

# Preparing consumer_data.csv

df = DataFrame(CSV.File(read("build/input/consumer_data.csv", enc"windows-1250")))

retailers = DataFrame(CSV.File(read("build/input/traditional_retailers_list.csv", enc"windows-1250")))

# Rename 
rename!(df, "FECHA"=>"date","COD_DIS"=>"market", "DES_TIPO_TAR_ACC"=>"tariff", "Suma de NUMERO_SUMINISTROS"=>"consumers", 
    "Suma de ENERGIA_kWh" => "yearly_consumption")
rename!(retailers, :ref => :regulated)

# Subset domestic segment
unique(df.tariff) 
df=df[(df.tariff.=="2.0A").|(df.tariff.=="2.1A").|(df.tariff.=="2.0NA-DHA").|(df.tariff.=="2.1DHA"),:]

# Distributor names 
distr=["R1-001","R1-299","R1-002","R1-008","R1-005","R1-003"]

# Subset of integrated distributors
df=df[in(distr).(df.market), :]
df.market=string.(df.market)
replace!(df.market, "R1-001" => "IBERDROLA")
replace!(df.market, "R1-299" => "ENDESA")
replace!(df.market, "R1-002" => "NATURGY")
replace!(df.market, "R1-008" => "EDP")
replace!(df.market, "R1-005" => "REPSOL")
replace!(df.market, "R1-003" => "REPSOL")

# Get group pertinance 
df=leftjoin(df,retailers,on=[:COD_COM=>:cod])

# IF the retailer is not present in "retailers" it must be commercial
replace!(df.regulated,missing => false) 
replace!(df.group, missing => "OTHERS")

# Aggregate by date, market, group, regulated and tariff
df=combine(groupby(df, [:date,:market,:group,:tariff,:regulated]),[:consumers, :yearly_consumption] .=> sum .=> [:consumers, :yearly_consumption])

# Regulated only in market == group
df=df[((df.regulated.==true).&(df.market.==df.group)).|(df.regulated.==false),:]

# Create categorical power and time of use
df.power= SubString.(df.tariff,1,3)
df.tou=ifelse.(contains.(df.tariff,"DHA"),1,0)

# Create variable for incumbent
df[:,"incumbent"] = ifelse.(df.group .== df.market, 1, 0)
 
# Create market shares
transform!(groupby(df, [:date, :market]), :consumers => function share(x)  x / sum(x) end => :share)

# Create outside option 
others=df[df.group.=="OTHERS",:]
select!(others,:date,:market,:tariff,:share=>:share_others)
regulated=df[df.regulated.==true,:]
select!(regulated,:date,:market,:tariff,:share=>:share_reg)

# Merge together
df=leftjoin(df,regulated,on=[:date,:market,:tariff])
df=leftjoin(df,others,on=[:date,:market,:tariff])

# Arrange
sort!(df,[:market,:group,:date,:regulated,:tariff])

# Write the output file
CSV.write("build/output/market_shares.csv", df)

println("\n
The file market_shares.csv has been successfully created in the output folder.")

