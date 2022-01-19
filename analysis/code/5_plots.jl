# PLOTS 

### Load packages

using CSV
using DataFrames
using Dates
using Plots
using StringEncodings

cd(dirname(dirname(@__DIR__)))


#--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# FIGURE 1a: Smartmeter penetration over time
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Load csv
df =CSV.read("build/input/smart_meter.csv",DataFrame)

# Date
df=rename(df,"FECHA"=>"date")
df.date=replace.(df.date, "T1" => "03")
df.date=replace.(df.date, "T2" => "06")
df.date=replace.(df.date, "T3" => "09")
df.date=replace.(df.date, "T4" => "12")
df.date=replace.(df.date, "_" => "-")
df.date = Date.(df.date, "yyyy-mm")


# GAS NATURAL TO NATURGY
df.group=replace!(df.group, "GAS NATURAL" => "NATURGY")
unique(df.group)

# grey
p1=plot(
    df.date, df.smartmeter,group=df.group,markershape = :auto, legend=:bottomright, linecolor = :black,markercolor=:black,
    size=(600,400),
    grid = true, gridalpha = .2,
    legendfontsize = 9, ytickfontsize = 9,xtickfontsize = 9,
    xticks = ([Date(2016,1,1),Date(2017,01,01),Date(2018,01,01),Date(2019,01,01),Date(2020,01,01)],["2016","2017","2018","2019","2020"])
)
savefig(p1,"analysis/output/figure_1a.png")

println("\n
The plot figure_1a.png has been successfully created in the analysis/output folder.")



#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Figure 1b: HHI for each market over time
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Preparing data
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Load data
df=DataFrame(CSV.File(read("build/input/consumer_data.csv", enc"windows-1250")))
retailers=DataFrame(CSV.File(read("build/input/traditional_retailers_list.csv", enc"windows-1250")))

# Rename 
rename!(df, "FECHA"=>"date","COD_DIS"=>"market", "DES_COM"=>"firm","DES_TIPO_TAR_ACC"=>"tariff", "Suma de NUMERO_SUMINISTROS"=>"consumers")
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

# CHC has two firm with the codes R2-540 and R2-291. Firm with code R2-540 is regulated but small
df.group[df.COD_COM.=="R2-540"] .= "CHC"
df.group[df.COD_COM.=="R2-291"] .= "CHC"
df.regulated[df.COD_COM.=="R2-540"] .= true

# If the retailer is not present in "retailers" it must be commercial
replace!(df.regulated,missing => false) 

# If not pertaining to 5 groups, then they are new entrants
df.group = coalesce.(df.group, df.firm)

# Delete empty observations 
df=df[df.group.!="(en blanco)",:]

# Regulated only in market == group
df=df[((df.regulated.==true).&(df.market.==df.group)).|(df.regulated.==false),:]

# Variable of interest
select!(df,:date,:market,:firm,:group,:tariff,:consumers,:regulated)

# Market weights 
weights=combine(groupby(df, [:date, :market]), :consumers => sum => :consumers)




# A. TRADITIONAL REGULATED AND TRADITIONAL COMMERCIAL CONSIDERED AS SAME FIRM 
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df1=copy(df)

# ENDESA's market 
endesa = df1[df1.market.=="ENDESA",:]
endesa = combine(groupby(endesa, [:date, :group]), :consumers => sum => :consumers)
endesa = transform!(groupby(endesa, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
endesa.share2=endesa.share.*endesa.share
endesa = combine(groupby(endesa, [:date]), :share2 => sum => :share2)
endesa[:,"market"].= "ENDESA"

# IBERDROLA's market 
iberdrola = df1[df1.market.=="IBERDROLA",:]
iberdrola = combine(groupby(iberdrola, [:date, :group]), :consumers => sum => :consumers)
iberdrola = transform!(groupby(iberdrola, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
iberdrola.share2=iberdrola.share.*iberdrola.share
iberdrola = combine(groupby(iberdrola, [:date]), :share2 => sum => :share2)
iberdrola[:,"market"].="IBERDROLA"

# NATURGY's market 
naturgy = df1[df1.market.=="NATURGY",:]
naturgy = combine(groupby(naturgy, [:date, :group]), :consumers => sum => :consumers)
naturgy = transform!(groupby(naturgy, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
naturgy.share2=naturgy.share.*naturgy.share
naturgy = combine(groupby(naturgy, [:date]), :share2 => sum => :share2)
naturgy[:,"market"].="NATURGY"

# EDP's market 
edp = df1[df1.market.=="EDP",:]
edp = combine(groupby(edp, [:date, :group]), :consumers => sum => :consumers)
edp = transform!(groupby(edp, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
edp.share2=edp.share.*edp.share
edp = combine(groupby(edp, [:date]), :share2 => sum => :share2)
edp[:,"market"].="EDP"

# REPSOL's market 
repsol = df1[df1.market.=="REPSOL",:]
repsol = combine(groupby(repsol, [:date, :group]), :consumers => sum => :consumers)
repsol = transform!(groupby(repsol, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
repsol.share2=repsol.share.*repsol.share
repsol = combine(groupby(repsol, [:date]), :share2 => sum => :share2)
repsol[:,"market"].="REPSOL"

# Bind together 
same = [endesa; iberdrola;naturgy; edp; repsol]
same = leftjoin(same,weights,on=[:date,:market])
same = combine(groupby(same,:date), [:share2,:consumers] => ((s,c)-> (HHI=sum(s.*c)/sum(c))) => :same)



# B. TRADITIONAL REGULATED AND TRADITIONAL COMMERCIAL CONSIDERED AS DIFFERENT FIRMS 
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df1.group=string.(df1.group,"-",df1.regulated)

# ENDESA's market 
endesa = df1[df1.market.=="ENDESA",:]
endesa = combine(groupby(endesa, [:date, :group]), :consumers => sum => :consumers)
endesa = transform!(groupby(endesa, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
endesa.share2=endesa.share.*endesa.share
endesa = combine(groupby(endesa, [:date]), :share2 => sum => :share2)
endesa[:,"market"].= "ENDESA"

# IBERDROLA's market 
iberdrola = df1[df1.market.=="IBERDROLA",:]
iberdrola = combine(groupby(iberdrola, [:date, :group]), :consumers => sum => :consumers)
iberdrola = transform!(groupby(iberdrola, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
iberdrola.share2=iberdrola.share.*iberdrola.share
iberdrola = combine(groupby(iberdrola, [:date]), :share2 => sum => :share2)
iberdrola[:,"market"].="IBERDROLA"

# NATURGY's market 
naturgy = df1[df1.market.=="NATURGY",:]
naturgy = combine(groupby(naturgy, [:date, :group]), :consumers => sum => :consumers)
naturgy = transform!(groupby(naturgy, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
naturgy.share2=naturgy.share.*naturgy.share
naturgy = combine(groupby(naturgy, [:date]), :share2 => sum => :share2)
naturgy[:,"market"].="NATURGY"

# EDP's market 
edp = df1[df1.market.=="EDP",:]
edp = combine(groupby(edp, [:date, :group]), :consumers => sum => :consumers)
edp = transform!(groupby(edp, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
edp.share2=edp.share.*edp.share
edp = combine(groupby(edp, [:date]), :share2 => sum => :share2)
edp[:,"market"].="EDP"

# REPSOL's market 
repsol = df1[df1.market.=="REPSOL",:]
repsol = combine(groupby(repsol, [:date, :group]), :consumers => sum => :consumers)
repsol = transform!(groupby(repsol, :date), :consumers => function share(x)  x/sum(x)*100  end  => :share)
repsol.share2=repsol.share.*repsol.share
repsol = combine(groupby(repsol, [:date]), :share2 => sum => :share2)
repsol[:,"market"].="REPSOL"

# Bind together 
different = [endesa; iberdrola;naturgy; edp; repsol]
different = leftjoin(different,weights,on=[:date,:market])
different = combine(groupby(different,:date), [:share2,:consumers] => ((s,c)-> (HHI=sum(s.*c)/sum(c))) => :dif)



# PLOT
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df1=leftjoin(same,different,on=:date)

# Date
df1.date=replace.(df1.date, "T1" => "03")
df1.date=replace.(df1.date, "T2" => "06")
df1.date=replace.(df1.date, "T3" => "09")
df1.date=replace.(df1.date, "T4" => "12")
df1.date=replace.(df1.date, "_" => "-")
df1.date = Date.(df1.date, "yyyy-mm")


p2=plot(
    df1.date, df1.same,legend=:bottomright,linestyle=:solid, linecolor = :black, ylims=(0,10000), label="as same firm",
    size=(600,400),
    grid = true, gridalpha = .2,
    legendfontsize = 11, ytickfontsize = 11,xtickfontsize = 11,
    xticks = ([Date(2011,1,1),Date(2013,01,01),Date(2015,01,01),Date(2017,01,01),Date(2019,01,01)],["2011","2013","2015","2017","2019"])
)
plot!(
    df1.date, df1.dif,legend=:bottomright, linestyle=:dash,linecolor = :black, ylims=(0,10000), label="as different firm",
    size=(600,400),
    grid = true, gridalpha = .2,
    legendfontsize = 9, ytickfontsize = 9,xtickfontsize = 9,
    xticks = ([Date(2011,1,1),Date(2013,01,01),Date(2015,01,01),Date(2017,01,01),Date(2019,01,01)],["2011","2013","2015","2017","2019"])
)
savefig(p2,"analysis/output/figure_1b.png")


println("\n
The plot figure_1b.png has been successfully created in the analysis/output folder.\n")




#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Figure 2a: Share of consumers on time-of-use
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Preparing data set 
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df2=copy(df)

# Create categorical variable for time of use 
df2.tou=ifelse.(contains.(df2.tariff,"DHA"),"tou","no-tou")

# Traditional
trad_names=["ENDESA","IBERDROLA","NATURGY","EDP","REPSOL"]
trad=df2[in(trad_names).(df2.group), :]

# Traditional regulated
reg = trad[trad.regulated.==true,:]
reg = combine(groupby(reg, [:date,:market,:group,:tou]), :consumers => sum => :consumers)
reg = transform!(groupby(reg, [:date,:market,:group]),:consumers => sum => :total_group)
reg.prop = reg.consumers./reg.total_group
reg = reg[reg.tou.=="tou",:]
reg = combine(groupby(reg,:date), [:prop,:total_group] => ((p,t)-> (prop=sum(p.*t)/sum(t))) => :prop)
reg[!,"type"].= "Trad - reg"

# Traditional in incumbent market 
inc = trad[(trad.regulated.==false).&(trad.market.==trad.group),:]
inc = combine(groupby(inc, [:date,:market,:group,:tou]), :consumers => sum => :consumers)
inc = transform!(groupby(inc, [:date,:market,:group]),:consumers => sum => :total_group)
inc.prop = inc.consumers./inc.total_group
inc = inc[inc.tou.=="tou",:]
inc = combine(groupby(inc,:date), [:prop,:total_group] => ((p,t)-> (prop=sum(p.*t)/sum(t))) => :prop)
inc[!,"type"].= "Trad - com - inc"

# Traditional not in incumbent market 
ninc = trad[(trad.regulated.==false).&(trad.market.!=trad.group),:]
weight = combine(groupby(ninc, [:date,:market]), :consumers => sum => :consumers) # market weight 
ninc = combine(groupby(ninc, [:date,:market,:group,:tou]), :consumers => sum => :consumers)
ninc = transform!(groupby(ninc, [:date,:market,:group]),:consumers => sum => :total_group)
ninc.prop = ninc.consumers./ninc.total_group
ninc = ninc[ninc.tou.=="tou",:]
ninc = combine(groupby(ninc,[:date,:market]), [:prop,:total_group] => ((p,t)-> (prop=sum(p.*t)/sum(t))) => :prop) # weighting first by group in each market
ninc = leftjoin(ninc,weight,on=[:date,:market])
ninc = combine(groupby(ninc,:date), [:prop,:consumers] => ((p,c)-> (prop=sum(p.*c)/sum(c))) => :prop) # finally weighting by market
ninc[!,"type"].= "Trad - com"

# New entrants
entrant=df2[.!in(trad_names).(df2.group), :]
weight = combine(groupby(entrant, [:date,:market]), :consumers => sum => :consumers) # market weight 
entrant = combine(groupby(entrant, [:date,:market,:group,:tou]), :consumers => sum => :consumers)
entrant = transform!(groupby(entrant, [:date,:market,:group]),:consumers => sum => :total_group)
entrant.prop = entrant.consumers./entrant.total_group
entrant = entrant[entrant.tou.=="tou",:]
entrant = combine(groupby(entrant,[:date,:market]), [:prop,:total_group] => ((p,t)-> (prop=sum(p.*t)/sum(t))) => :prop) # weighting first by group in each market
entrant = leftjoin(entrant,weight,on=[:date,:market])
entrant = combine(groupby(entrant,:date), [:prop,:consumers] => ((p,c)-> (prop=sum(p.*c)/sum(c))) => :prop) # finally weighting by market
entrant[!,"type"].= "New entrants"



# PLOT
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df2=[reg;inc;ninc;entrant]

# Date
df2.date=replace.(df2.date, "T1" => "03")
df2.date=replace.(df2.date, "T2" => "06")
df2.date=replace.(df2.date, "T3" => "09")
df2.date=replace.(df2.date, "T4" => "12")
df2.date=replace.(df2.date, "_" => "-")
df2.date = Date.(df2.date, "yyyy-mm")


p3=plot(
    df2.date, df2.prop,group=df2.type,markershape = :auto, legend=:topleft, linecolor = :black,markercolor=:black,
    size=(600,400),
    grid = true, gridalpha = .2,
    legendfontsize = 9, ytickfontsize = 9,xtickfontsize = 9,
    xticks = ([Date(2011,1,1),Date(2013,01,01),Date(2015,01,01),Date(2017,01,01),Date(2019,01,01)],["2011","2013","2015","2017","2019"])
)
savefig(p3,"analysis/output/figure_2a.png")


println("\n
The plot figure_2a.png has been successfully created in the analysis/output folder.")
