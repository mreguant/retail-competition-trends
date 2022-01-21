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



#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
df1=copy(df)

# Market weights 
weight =  combine(groupby(df1, [:date, :market]), :consumers => sum => :w)

# Traditional regulated and traditional commercial considered as a same firm
same = combine(groupby(df1, [:date, :market, :group]), :consumers => sum => :consumers)
same = transform!(groupby(same, [:date,:market]), :consumers => function share(x)  x/sum(x)*100  end  => :share)
same.share2 = same.share .* same.share
same = combine(groupby(same, [:date,:market]), :share2 => sum => :share2)
same = leftjoin(same,weight,on=[:date,:market])
same = combine(groupby(same,:date), [:share2,:w] => ((s,w)-> (prop=sum(s.*w)/sum(w))) => :same)

# Traditional regulated and traditional commercial considered as different firms 
df1.group=string.(df1.group,"-",df1.regulated)
dif = combine(groupby(df1, [:date, :market, :group]), :consumers => sum => :consumers)
dif = transform!(groupby(dif, [:date,:market]), :consumers => function share(x)  x/sum(x)*100  end  => :share)
dif.share2 = dif.share .* dif.share
dif =combine(groupby(dif, [:date,:market]), :share2 => sum => :share2)
dif = leftjoin(dif,weight,on=[:date,:market])
dif = combine(groupby(dif,:date), [:share2,:w] => ((s,w)-> (prop=sum(s.*w)/sum(w))) => :dif)

# Merge
df1=leftjoin(same,dif,on=:date)

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
    df1.date, df1.dif,legend=:bottomright, linestyle=:dash,linecolor = :black, ylims=(0,10000), label="as different firms",
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

df2=copy(df)

# Aggregate all new entrants together 
trad_names=["ENDESA","IBERDROLA","NATURGY","EDP","REPSOL"]
df2.group[.!in(trad_names).(df2.group), :].="OTHERS"

# Create categorical variable for time of use 
df2.tou=ifelse.(contains.(df2.tariff,"DHA"),"tou","no-tou")

# Create incumbent variable 
df2.incumbent=ifelse.(df.market.==df.group,1,0)

# Create label 
df2.type = ifelse.( 
    (df2.incumbent .== 1) .& (df2.regulated .== 0), "Trad-com-inc", ifelse.( 
        (df2.incumbent .== 1) .& (df2.regulated .== 1) ,"Trad-reg", ifelse.( 
            (df2.group .!= "OTHERS"), "Trad-com", "New entrants"
            )
    )
)

# Calculate share of consumers in time-of-use in each market 
df2 = combine(groupby(df2, [:date,:type, :tou]), :consumers => sum => :consumers)
transform!(groupby(df2, [:date,:type]), :consumers => function share(x) x / sum(x) end => :prop)
df2 = filter(row -> ( row.tou =="tou")  , df2)

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
