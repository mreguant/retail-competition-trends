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
df.FECHA=replace.(df.FECHA, "T1" => "03")
df.FECHA=replace.(df.FECHA, "T2" => "06")
df.FECHA=replace.(df.FECHA, "T3" => "09")
df.FECHA=replace.(df.FECHA, "T4" => "12")
df.FECHA=replace.(df.FECHA, "_" => "-")
df.FECHA = Date.(df.FECHA, "yyyy-mm")
df=rename(df,"FECHA"=>"date")

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


#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Figure 1b: HHI for each market over time
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Load data 
df = CSV.read("analysis/input/HHI.csv",DataFrame,missingstring="NA", )


# Date
df.quarter=string.(df.quarter,"Q")
replace!(df.quarter, "1Q" => "03")
replace!(df.quarter, "2Q" => "06")
replace!(df.quarter, "3Q" => "09")
replace!(df.quarter, "4Q" => "12")
df.date = Date.(string.(df[!, "year"], "-", df[!, "quarter"]), "yyyy-mm")


# only two line 
df1=df[df.type.!="non-regulated",:]
replace!(df1.type, "whole" => "same")
replace!(df1.type, "whole (reg com sep)" => "dif")

df1=unstack(df1,:date,:type,:HHI)

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








#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Figure 2a: Shares of Time of Use in Trad-reg vs. trad-com-inc vs. trad-com-non-inc vs. non-trad
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Load data 

df = CSV.read("analysis/input/shares_ToU.csv",DataFrame,missingstring="NA")

# Date
df.quarter=string.(df.quarter,"Q")
replace!(df.quarter, "1Q" => "03")
replace!(df.quarter, "2Q" => "06")
replace!(df.quarter, "3Q" => "09")
replace!(df.quarter, "4Q" => "12")
df.date = Date.(string.(df[!, "year"], "-", df[!, "quarter"]), "yyyy-mm")


# filter plot = "by-type"
df1=df[df.plot.=="by-type",:]


p3=plot(
    df1.date, df1.prop,group=df1.category,markershape = :auto, legend=:topleft, linecolor = :black,markercolor=:black,
    size=(600,400),
    grid = true, gridalpha = .2, 
    legendfontsize = 9, ytickfontsize = 9,xtickfontsize = 9,
    xticks = ([Date(2011,1,1),Date(2013,01,01),Date(2015,01,01),Date(2017,01,01),Date(2019,01,01)],["2011","2013","2015","2017","2019"])
)

savefig(p3,"analysis/output/figure_2a.png")





println("\n
The plot figure_1a.png has been successfully created in the analysis/output folder.\n
The plot figure_1b.png has been successfully created in the analysis/output folder.\n
The plot figure_2a.png has been successfully created in the analysis/output folder.")
