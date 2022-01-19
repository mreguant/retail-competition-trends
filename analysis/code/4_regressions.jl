###################################

# RETAIL COMPETITION - Regressions

##################################

### Load Packages

using DataFrames
using Statistics
using CSV
using Plots
using Dates
using FixedEffectModels
using CategoricalArrays
using RegressionTables

cd(dirname(dirname(@__DIR__)))

###################################
# 0. Preparing data
###################################

# 0.1. Market shares data
###################################

df = CSV.read("build/output/first_stage_dataset.csv",DataFrame)

df.power = string.(df.power)
df.group_c = categorical(df.group)
df.year_c = categorical(df.year)
df.date_c = categorical(string.(df.date))

# we discard non-positive shares, because logarithm is not defined
filter!(row -> row.share > 0, df)

# other (non-traditional) retailers
df_o = filter(row -> row.group!="OTHERS" , df)
# commercial
df_com = filter(row -> row.regulated==0 , df)

# 0.2. Flow data
###################################

df_flow = CSV.read("analysis/input/flow_data.csv",DataFrame,missingstring="NA")
names(df_flow)

replace!(df_flow.group , "GAS NATURAL" => "NATURGY")
unique(df_flow.group)

# show(describe(df_flow),allrows=true)
sort!(df_flow, [:group,:year,:quarter])

df_flow.date = Date.(df_flow.year, df_flow.quarter .* 3, 28)
df_flow = dropmissing(df_flow,:consumers_reg)
df_flow.group_c = categorical(df_flow.group)
filter!(row -> row.consumers_reg > 0 , df_flow)

#stayers: consumers remaining in regulated incumbent
df_flow.stayers = df_flow.consumers_reg - df_flow.registrations_distr_reg - df_flow.switch_com_reg - df_flow.switch_others_reg
sort!(df_flow, [:group])
# lag of regulated consumers
df_temp=combine(groupby(df_flow, ["group"]), :consumers_reg => Base.Fix2(lag, 1) => :consumers_lag)
sort!(df_temp,[:group])
df_flow=[df_flow select(df_temp,:consumers_lag) ]
df_temp=0 #deleting temporal datasets
#change: similar to switching out
df_flow.switch_growth = (df_flow.stayers .- df_flow.consumers_lag) ./ df_flow.consumers_lag

# Alternative specification for inattention (exploiting consumers going from regulated to commercial)
df_flow.reg_others_share = df_flow.switch_reg_others ./ df_flow.consumers_lag

###################################
# 1.BRAND ADVANTAGE REGRESSIONS
###################################

# outside option: otros (and thus including energy_prices) - using df_o: filter out OTROS observations
#( although results do no change - we do not have energy_prices)

model_1o = reg(df_o,@formula(log(share/share_others) ~ incumbent + energy_price +regulated*ordered_quarter  + fe(group) + fe(market)*fe(date)+fe(tariff)))

model_2o = reg(df_o,@formula(log(share/share_others) ~ incumbent +  (energy_price ~ gas_price*group_c) +
regulated*ordered_quarter  + fe(group) + fe(market)*fe(date)+fe(tariff)))

#model_IV_first_stage = reg(df,@formula(energy_price ~ incumbent + gas_price  + fe(date)*fe(market) +fe(tariff)))

# model_3o = reg(df_o,@formula(log(share/share_others) ~ incumbent + energy_price_lag +regulated*ordered_quarter  + fe(group) + fe(market)*fe(date)+fe(tariff)))

# model_4o = reg(df_o,@formula(log(share/share_others) ~ incumbent*group_c + energy_price +regulated*ordered_quarter  +  fe(market)*fe(date)+fe(tariff)))

model_1onp = reg(df_o,@formula(log(share/share_others) ~ incumbent + regulated*ordered_quarter  + fe(group) + fe(market)*fe(date)+fe(tariff)))


###### GENERATE LATEX OUTPUT ##########################################################################################################################
regtable(model_1o,model_2o, model_1onp; renderSettings = asciiOutput())
regtable(model_1o,model_2o, model_1onp; renderSettings = latexOutput("analysis/output/table_1.tex"))
########################################################################################################################################################


# outside option: regulated (and thus otros as a category and without energy_prices) - using df_fr: filter out regulated observations
model_1r = reg(df_com,@formula(log(share/share_reg) ~ incumbent  + fe(group) + fe(market)*fe(date)+fe(tariff)))

### Incumbent effect over time
model_dyn_0 = reg(df_o,@formula(log(share/share_others) ~ incumbent*ordered_quarter + energy_price +regulated*ordered_quarter  + fe(group) + fe(market)*fe(date)+fe(tariff)))



###################################
# 3. DYNAMIC PARAMETERS
###################################

# 3.1. Retrieving first stage estimates
#######################################
model_inc_g = reg(df_o,@formula(log(share/share_others) ~ incumbent*group_c + energy_price +regulated*ordered_quarter  +  fe(market)*fe(date)+fe(tariff)))
model_inc_g_np = reg(df_o,@formula(log(share/share_others) ~ incumbent*group_c +regulated*ordered_quarter  +  fe(market)*fe(date)+fe(tariff)))

coef_names = [ "incumbent"; coefnames(model_inc_g_np)[startswith.(coefnames(model_inc_g_np),"incumbent &")]]

coef_reg = [coef(model_inc_g_np)[endswith.(coefnames(model_inc_g_np),"incumbent")] ; 
coef(model_inc_g_np)[startswith.(coefnames(model_inc_g_np),"incumbent &")] ]

coef_reg[startswith.(coef_names,"incumbent &")] = 
coef_reg[startswith.(coef_names,"incumbent &")].+ coef_reg[1]

df_coef = DataFrame(group = coef_names,  coef = coef_reg)

df_coef.group = ["EDP","ENDESA","IBERDROLA","NATURGY","REPSOL"]

#standard errors
((stderror(model_inc_g_np)[endswith.(coefnames(model_inc_g_np),"incumbent")]).^2 .+
(stderror(model_inc_g_np)[startswith.(coefnames(model_inc_g_np),"incumbent & group_c: ")]).^2 
.+2*(vcov(model_inc_g_np)[1,startswith.(coefnames(model_inc_g_np),"incumbent & group_c: ")])).^(1/2)


#computing the share in the market where they are not the incumbent (for the baseline share)
shares = zeros(length(unique(df_flow.group)))

df_temp = filter(row ->(row.incumbent==0 && row.group!="OTHERS"),df)
unique(df_temp.group)

for i in 1:length(unique(df_temp.group))
    filter(row -> row.group == unique(df_temp.group)[i]  , df_temp) |>
    (y -> shares[i] = mean(y.share))
end

df_coef=leftjoin(DataFrame(group=unique(df_temp.group),shares = shares),df_coef,on=:group)


#share staying due to incumbent advantage
df_coef.prob = df_coef.shares.*(df_coef.coef)
df_coef.leave =  df_coef.prob .- 1

df_flow = leftjoin(df_flow, df_coef, on = :group)

# inattention regulated
df_flow.inattention = df_flow.switch_growth ./ df_flow.leave

# inattention others
df_flow.inattention_o = df_flow.reg_others_share ./ (1 .- 2 .*df_flow.prob)

df_flow.quarter = categorical(df_flow.quarter)
df_flow.year_c = categorical(df_flow.year)

df_coef=0 #delete coefficient data
df_temp=0 #delete temporal data

# 3.2. Regressions
#######################################

#  Reduced form for inertia 
model_lag = reg(df_flow,@formula(consumers_reg ~ consumers_lag + fe(date)+fe(group)))

# Main regression
model_inertia_1 = reg(df_flow,@formula(inattention ~ group_c + date ))
model_inertia_2= reg(df_flow,@formula(inattention_o ~ group_c + date ))

#choose model to display coefficients
model_inertia = model_inertia_2
#Retrieving lambdas
coef_names = ["(Intercept)" ; coefnames(model_inertia)[startswith.(coefnames(model_inertia),"group_c")]]
coef_reg = [coef(model_inertia)[startswith.(coefnames(model_inertia),"(Intercept)")] ; 
coef(model_inertia)[startswith.(coefnames(model_inertia),"group_c")] ]

coef_reg[startswith.(coef_names,"group_c")] = 
coef_reg[startswith.(coef_names,"group_c")].+ coef_reg[1]

df_coef = DataFrame(group = coef_names,  coef = coef_reg)

#standard errors
((stderror(model_inertia)[endswith.(coefnames(model_inertia),"(Intercept)")]).^2 .+
(stderror(model_inertia)[startswith.(coefnames(model_inertia),"group_c: ")]).^2 
.+2*(vcov(model_inertia)[1,startswith.(coefnames(model_inertia),"group_c: ")])).^(1/2)

df_coef.group = ["EDP","ENDESA","IBERDROLA","NATURGY","REPSOL"]

df_coef=0 #delete coefficient data


###################################
# 4. Linking to smartmeters
###################################
#Extracting smartmeters from raw data
df_sm_inc = filter(row ->(row.incumbent==1 && row.regulated==1  && row.tariff =="2.0A"),df) #for incumbent coef
df_sm_inat = filter(row ->(row.year>2015 ),df_sm_inc) # for inattention coef (df_flow data)
df_sm_inat = leftjoin(filter(row -> (row.year < 2020  > 0),df_flow),df_sm_inat[:,[:date,:group,:smartmeter]],on=[:date,:group])

# 4.1. New Entrants and Smartmeters
#######################################


df_temp = combine(groupby(df, [:date, :market, :group,:smartmeter, :year, :regulated,:ordered_quarter]), :consumers => sum => :consumers)
transform!(groupby(df_temp, [:date, :market]), :consumers => function share(x) x / sum(x) end => :share_group)
#filter!(row -> row.regulated == 0, df_fringe) # we already control for it in the regressions
df_fringe = filter(row -> (row.group == "OTHERS") , df_temp)

#p1 = plot((df_fringe.smartmeter),(df_fringe.share_group),group = df_fringe.market, legendtitle = "market", st = :scatterpath,
#    legend = :outerright, xlabel = "smart meter penetration", ylabel = "fringe retailers' market share")

model_41 = reg(df_fringe, @formula(log(share_group)   ~ smartmeter  + fe(market) + fe(date)))

df_temp=0 #delete temporal data

# 4.2. Brand Advantage and Smartmeters
#######################################

model_inc_d = reg(df_o,@formula(log(share/share_others) ~ incumbent*group_c*date +regulated*ordered_quarter  +
 fe(market)*fe(date)
+fe(tariff) # take out when aggregating at firm level
))


coef_edp = [coef(model_inc_d)[endswith.(coefnames(model_inc_d),"incumbent")] ; 
coef(model_inc_d)[startswith.(coefnames(model_inc_d),"incumbent & date")] ]
coef_edp[2:length(coef_edp)] = coef_edp[2:length(coef_edp)].+ coef_edp[1]
df_incumbent = DataFrame(group = "EDP", date=unique(df_o.date), coef = coef_edp)


groups = ["ENDESA","IBERDROLA","NATURGY","REPSOL"]

for i in 1:length(groups)
coef1 = coef(model_inc_d)[startswith.(coefnames(model_inc_d),string("incumbent & group_c: ",groups[i]))]
coef1[2:length(coef1)] = coef1[2:length(coef1)].+ coef1[1]
df1 = DataFrame(group = groups[i], date=unique(df_o.date), coef = coef1,edp=coef_edp)
df1.coef = df1.coef+df1.edp
df1=df1[:,1:3]
df_incumbent = [df_incumbent;df1]
end

df_1=0 #delete temporal data
coef1 = 0 #delete coefficient data
 
#adding smartmeter variable
df_incumbent=leftjoin(df_incumbent,df_sm_inc,on=[:date,:group])
rename!(df_incumbent,:coef=>:adv)

model_42= reg(df_incumbent,@formula(adv ~ smartmeter + fe(date)+ fe(market)))

df_incumbent = 0 #delete temporal data


# 4.3. Inattention and Brand Advantage
#########################################

# we do not need to retrieve lambdas, the inattention variable is already our lambda at market*date level (identity)
#adding smartmeter variable

rename!(df_sm_inat,:group => :market)
model_43_1 = reg(df_sm_inat,@formula(inattention ~ smartmeter + fe(date) +fe(market)))
model_43_2 = reg(df_sm_inat,@formula(inattention_o ~ smartmeter + fe(date) +fe(market)))

###### GENERATE LATEX OUTPUT ##########################################################################################################################
regtable(model_41,model_42,model_43_2; renderSettings = asciiOutput())
regtable(model_41,model_42,model_43_2; renderSettings = latexOutput("analysis/output/figure_2b.tex"))
########################################################################################################################################################

println("\n
The file table_1.tex has been successfully created in the analysis/output folder.\n
The file figure_2b.tex has been successfully created in the analysis/output folder.")
