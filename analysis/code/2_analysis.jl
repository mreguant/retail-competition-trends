##################################################################################################################################################################################
#
# ANALYSIS
#
##################################################################################################################################################################################


### Load Packages
using DataFrames
using Statistics
using CSV
using FixedEffectModels
using CategoricalArrays
using RegressionTables
using JuMP
using Ipopt
using DataStructures
using Printf


# Set working directory
cd(dirname(dirname(@__DIR__)))

try
    mkdir("analysis/output")
catch
    nothing    
end




# 0. Explore dropouts 
#_______________________________________________________________________________________________________________________________________________________________________________
##################################################################################################################################################

# Consumer data
df = CSV.read("analysis/input/choice_search_dataset.csv",DataFrame)
df.diff = df.consumer_reg .- df.consumer_reg_lag

# Calculate dropout
df.dropout = -df.diff .+ df.registration_distr_reg .+ df.switch_inc_reg .+ df.switch_others_reg .- df.switch_reg_inc .- df.switch_reg_others
df.dropout_p = df.dropout ./df.consumer_reg_lag
df=df[.!((df.year.==2016).&(df.quarter.==1)),:]

# Mean by group 
combine(groupby(df, [ :market]), :dropout_p => mean=> :dropout_p)

# Dropout = phi
phi = round(sum(df.dropout)/sum(df.consumer_reg_lag),digits= 3)





# 1. Choice Search Model 
#_______________________________________________________________________________________________________________________________________________________________________________

df = CSV.read("analysis/input/choice_search_dataset.csv",DataFrame)


## SOLVING FOR STRUCTURAL MODEL
phi = 0.003;
df.consumer_other_lag = df.consumer_commercial_lag .- df.consumer_inc_lag;
df.new_consumer =  df.consumer_reg .+ df.consumer_commercial .- (df.consumer_reg_lag .+ df.consumer_commercial_lag) * (1.0-phi); 

df=df[.!((df.year.==2016).&(df.quarter.==1)),:]
sort!(df, [:market, :date]);



function solve_model(df::DataFrame,spec::String) 

    ### MODEL 
    M=5; # five markets
    J=6; # six firms (regulated=1, traditional)
    T=length(unique(df.date)); # 15 quarters in the sample

    # NOTEL J = 6 is the regulated firm
    # matrix stating whether a firm is an incumbent in the market
    incMat = zeros(M,J);
    non_incMat = zeros(M,J);
    tradMat = zeros(M,J);
    for m in 1:M
        for j in 1:J-1
            tradMat[m,j] = 1;
            if isequal(m,j)
                incMat[m,j] = 1;
            else
                non_incMat[m,j] = 1;
            end
        end
    end

    # a vector stating whether a firm is regulated
    regMat = zeros(J);
    regMat[6] = 1;

    # moments to match -- missing number of consumers by firm-market
    switch_i_r = transpose(reshape(convert(Array, df.switch_inc_reg/100000.0),(T,M)));
    switch_o_r = transpose(reshape(convert(Array, df.switch_others_reg/100000.0),(T,M))); 
    switch_r_i = transpose(reshape(convert(Array, df.switch_reg_inc/100000.0),(T,M))); 
    switch_r_o = transpose(reshape(convert(Array, df.switch_reg_others/100000.0),(T,M)));
    lag_r      = transpose(reshape(convert(Array, df.consumer_reg_lag/100000.0),(T,M))); 
    lag_o      = transpose(reshape(convert(Array, df.consumer_OTHERS_lag/100000.0),(T,M))); 
    lag_j      = [transpose(reshape(convert(Array, df.consumer_EDP_lag/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_ENDESA_lag/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_IBERDROLA_lag/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_NATURGY_lag/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_REPSOL_lag/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_reg_lag/100000.0),(T,M)))];
    consumers = [transpose(reshape(convert(Array, df.consumer_EDP/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_ENDESA/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_IBERDROLA/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_NATURGY/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_REPSOL/100000.0),(T,M))),
                    transpose(reshape(convert(Array, df.consumer_reg/100000.0),(T,M)))];                
    new        = transpose(reshape(convert(Array, df.new_consumer/100000.0),(T,M))); 
    new_r      = transpose(reshape(convert(Array, df.registration_distr_reg/100000.0),(T,M))); 
    quarter    = transpose(reshape(convert(Array, df.quarter),(T,M)));
    smartm    = transpose(reshape(convert(Array, df.smartmeter),(T,M))); 
    weight     = transpose(reshape(convert(Array, df.consumer_market/10000.0),(T,M))); 

    price = [transpose(reshape(convert(Array, df.price_EDP*100),(T,M))),
    transpose(reshape(convert(Array, df.price_ENDESA*100),(T,M))),
    transpose(reshape(convert(Array, df.price_IBERDROLA*100),(T,M))),
    transpose(reshape(convert(Array, df.price_NATURGY*100),(T,M))),
    transpose(reshape(convert(Array, df.price_REPSOL*100),(T,M))),
    transpose(reshape(convert(Array, df.price_reg*100),(T,M)))];                

    model = Model(optimizer_with_attributes(Ipopt.Optimizer, "print_level"=> 2, "nlp_scaling_method" => "gradient-based"));

    # Structural variables to construct objects
    @variable(model, Lambda[1:M,1:T,1:J]);
    @variable(model, Lambdao[1:M,1:T]);
    @variable(model, W[1:M,1:T,1:J]);
    @variable(model, Wo[1:M,1:T]);

    @variable(model, P[1:M,1:T,1:J]);
    @variable(model, Po[1:M,1:T]);  # probability of choosing others (1-sum(P))
    @variable(model, V[1:M,1:T,1:J]);

    # Moments to match (11 per period)
    @variable(model, N_i_r[1:M,1:T]);
    @variable(model, N_o_r[1:M,1:T]);
    @variable(model, N_r_i[1:M,1:T]);
    @variable(model, N_r_o[1:M,1:T]);
    @variable(model, A_r[1:M,1:T]);
    @variable(model, N_j[1:M,1:T,1:J]);

    # Parameters we are searching for
    # simple
    @variable(model, alphaP);
    @variable(model, incP);
    @variable(model, regP);
    @variable(model, alphaL);
    @variable(model, betaL[1:4]);
    @variable(model, incL);
    @variable(model, regL);
    # non-parametric
    @variable(model, deltaPr[1:M,1:T]);
    @variable(model, deltaPi[1:M,1:T]);
    @variable(model, deltaPo[1:M,1:T]);
    # smart meter
    @variable(model, smartL);
    @variable(model, smartP); 
    @variable(model, smartPinc); 
    # Prices
    @variable(model, priceL);
    @variable(model, priceP);
    # fixed effects
    @variable(model, deltaL[1:M,1:T]);
    @variable(model, deltaP[1:M,1:T]);
    @variable(model, marketL[1:M]);
    @variable(model, marketP[1:M]);
    @variable(model, timeL[1:T]);
    @variable(model, timeP[1:T]);


    # Objective function (missing number of customers)
    @NLobjective(model, Min, sum(weight[m,t] * (
            (N_i_r[m,t] - switch_i_r[m,t])^2 + (N_o_r[m,t] - switch_o_r[m,t])^2
            + (N_r_i[m,t] - switch_r_i[m,t])^2 + (N_r_o[m,t] - switch_r_o[m,t])^2
            + sum((N_j[m,t,j] - consumers[j][m,t])^2 for j=1:J)/J
            + (A_r[m,t]-new_r[m,t])^2
    )
    for m=1:M, t=1:T)/(M*T));

    # Definition for Lambda
    @NLconstraint(model, [m=1:M, t=1:T, j=1:J], Lambda[m,t,j] == exp(W[m,t,j])/(1+exp(W[m,t,j])));
    @NLconstraint(model, [m=1:M, t=1:T], Lambdao[m,t] == exp(Wo[m,t])/(1+exp(Wo[m,t])));

    # Definition for P
    @NLconstraint(model, [m=1:M, t=1:T, j=1:J], P[m,t,j] == exp(V[m,t,j])/(1.0+sum(exp(V[m,t,k]) for k=1:J)));
    @NLconstraint(model, [m=1:M, t=1:T], Po[m,t] == 1.0/(1.0+sum(exp(V[m,t,k]) for k=1:J)));

    # Specifications
    if spec=="non-parametric"
        @constraint(model, [m=1:M, t=1:T, j=1:J], W[m,t,j] == deltaL[m,t]); # betaL[quarter[m,t]]);
        @constraint(model, [m=1:M, t=1:T], Wo[m,t] == deltaL[m,t]);     
        @constraint(model, [m=1:M, t=1:T, j=1:J], V[m,t,j] == 
                            regMat[j]*deltaPr[m,t]+incMat[m,j]*deltaPi[m,t]+non_incMat[m,j]*deltaPo[m,t]);
    end
    if spec=="baseline"
        @constraint(model, [m=1:M, t=1:T, j=1:J], W[m,t,j] ==  betaL[quarter[m,t]] + regMat[j]*regL + incMat[m,j]*incL);
        @constraint(model, [m=1:M, t=1:T], Wo[m,t] == betaL[quarter[m,t]]);     
        @constraint(model, [m=1:M, t=1:T, j=1:J], V[m,t,j] == 
                            regMat[j]*regP + incMat[m,j]*incP + alphaP);    
    end
    if spec=="prices" 
        @constraint(model, [m=1:M, t=1:T, j=1:J], W[m,t,j] ==             
                            timeL[t] + marketL[m] + regMat[j]*regL + incMat[m,j]*incL);
        @constraint(model, [m=1:M, t=1:T], Wo[m,t] ==betaL[quarter[m,t]]+ timeL[t] + marketL[m]);     
        @constraint(model, [m=1:M, t=1:T, j=1:J], V[m,t,j] == 
                            marketP[m] + timeP[m] + regMat[j]*regP + incMat[m,j]*incP + priceP*price[j][m,t]);
    end
    if spec=="smart_prices" 
        @constraint(model, [m=1:M, t=1:T, j=1:J], W[m,t,j] ==  
        timeL[t] + marketL[m] + regMat[j]*regL + incMat[m,j]*incL +  smartL*smartm[m,t]);
        @constraint(model, [m=1:M, t=1:T], Wo[m,t] == 
        timeL[t] + marketL[m] +  smartL*smartm[m,t]);     
        @constraint(model, [m=1:M, t=1:T, j=1:J], V[m,t,j] == 
        timeP[t] + marketP[m] + regMat[j]*regP + incMat[m,j]*incP + smartP*smartm[m,t] 
        + smartPinc*incMat[m,j]*smartm[m,t] +  priceP*price[j][m,t]);
    end
    if spec=="overkill" 
        @constraint(model, [m=1:M, t=1:T, j=1:J], W[m,t,j] ==  #betaL[quarter[m,t]] 
        deltaL[m,t]  + regMat[j]*regL + incMat[m,j]*incL);
        @constraint(model, [m=1:M, t=1:T], Wo[m,t] == #betaL[quarter[m,t]] 
        deltaL[m,t]);     
        @constraint(model, [m=1:M, t=1:T, j=1:J], V[m,t,j] == 
        deltaP[m,t] + regMat[j]*regP + incMat[m,j]*incP + smartPinc*incMat[m,j]*smartm[m,t] + priceP*price[j][m,t]);
    end

    # Definitions for Number of Switchers and New Customers
    @NLconstraint(model, [m=1:M, t=1:T], N_i_r[m,t] == Lambda[m,t,m] * (1.0 - phi) * lag_j[m][m,t] * P[m,t,J]); # coming from incumbent
    @NLconstraint(model, [m=1:M, t=1:T], N_i_r[m,t] + N_o_r[m,t] == 
                                            (sum(Lambda[m,t,k] * lag_j[k][m,t] for k=1:J-1)
                                            + Lambdao[m,t] * lag_o[m,t]) * (1.0 - phi) * P[m,t,J]);
    @NLconstraint(model, [m=1:M, t=1:T], N_r_i[m,t] == Lambda[m,t,J] * (1.0 - phi) * lag_r[m,t] * P[m,t,m]); # choosing incumbent
    @NLconstraint(model, [m=1:M, t=1:T], N_r_o[m,t]+ N_r_i[m,t] == 
                                            Lambda[m,t,J] * (1.0 - phi) * lag_r[m,t] * (1.0 - P[m,t,J]));  # choosing any but regulated
    @NLconstraint(model, [m=1:M, t=1:T, j=1:J], N_j[m,t,j] == 
                            (1.0-phi) * (
                                (1.0 - Lambda[m,t,j]) * lag_j[j][m,t] # stayers
                                + (sum(Lambda[m,t,k] * lag_j[k][m,t] for k=1:J)  # traditional into j
                                + Lambdao[m,t] * lag_o[m,t]) * P[m,t,j] # others into j
                            )
                            + new[m,t] * P[m,t,j]);
    @constraint(model, [m=1:M, t=1:T], A_r[m,t] == new[m,t] * P[m,t,J]);

    optimize!(model);

    #check that model matches lambdas
    mean(df.lambdas)-mean(JuMP.value.(Lambda))

    return [mean(df.lambdas)-mean(JuMP.value.(Lambda)),
            JuMP.value.(incL),
            JuMP.value.(regL),
            JuMP.value.(smartL),
            JuMP.value.(incP),
            JuMP.value.(regP),
            JuMP.value.(smartP),
            JuMP.value.(smartPinc),
            JuMP.value.(priceP),
            mean(JuMP.value.(Lambda)), 
            mean([mean(JuMP.value.(P)[i,:,J]) for i=1:M]),
            mean([mean(JuMP.value.(P)[i,:,i]) for i=1:M]),
            mean([mean(JuMP.value.(Po)[i,:]) for i=1:M])];
end

spec = [Vector{Float64}(undef,1) for _ in 1:4];
spec[1] = solve_model(df,"baseline");
spec[2] = solve_model(df,"prices");
spec[3] = solve_model(df,"smart_prices");
spec[4] = solve_model(df,"overkill");

titles = OrderedDict(2=>"Incumbent (\$\\beta^i\$) ",
            3=>"Regulated (\$\\beta^r\$) ",
            4=>"Smart meter ",
            10=>"\$\\overline{\\lambda}\$ ",
            5=>"Incumbent (\$\\theta^i\$) ",
            6=>"Regulated (\$\\theta^r\$) ",
            7=>"Smart meter ",
            8=>"Smart meter * Inc ",
            9=>"Price ",
            12=>"\$\\overline{P}\$ Incumbent ",
            11=>"\$\\overline{P}\$  Regulated ",
            13=>"\$\\overline{P}\$  Fringe ");



# In REPL
for (key,title) in titles
    print(title)
    for i=1:4
        print(" & ")    
        print(@sprintf "%.2f" spec[i][key])
    end
    print(" \\\\")
    println()
end


# Save as txt output
header = s"""\begin{tabular}{@{\extracolsep{15pt}}lcccc}
            \toprule\n& (1) &(2) & (3)  & (4) \\
            \midrule
            \multicolumn{5}{c}{\textbf{Panel A: Search}} \\[1ex]"""
            


footer = s"""\midrule
                Market, Date & No & Yes & Yes & Yes\\
                Market X Date & No & No & No & Yes \\
                \bottomrule
                \end{tabular}"""




# Generate latex output 
###################################################################################################################################################################################
open("analysis/output/table_1.txt","a") do io
    println(io,header)
    for (key,title) in titles
        if key in [10,12]
            println(io,s"\midrule")
        elseif key == 5
            println(io,s"\midrule \multicolumn{5}{c}{\textbf{Panel B: Incumbency Advantage}} \\[1ex]")
        end 
        println(io,title)
            for i=1:4
                println(io," & ")    
                println(io, if spec[i][key]!=0 @sprintf "%.2f" spec[i][key] else "" end)
            end
        println(io," \\\\")
    end
    println(io,footer)
end


println("The file table_1.txt has been successfully created in the analysis\\output folder.")


###################################################################################################################################################################################










# 2. Smart Meter Regressions 
#_______________________________________________________________________________________________________________________________________________________________________________

df = CSV.read("analysis/input/smart_meter_regression_dataset.csv",DataFrame)


df = combine(groupby(df, [:date,:market,:group,:tou,:smartmeter, ]), :consumer => sum => :consumer)
transform!(groupby(df, [:date, :market]), :consumer => function share(x) x / sum(x) end => :share_group)
transform!(groupby(df, [:date, :market]), :consumer => sum => :consumer_market)


# At tariff level
df_fringe_tou = filter(row -> (row.tou == 1  && row.group == "OTHERS") , df)
model_tou = reg(df_fringe_tou, @formula(log(share_group)   ~ smartmeter+ fe(market) + fe(date)), Vcov.cluster(:market), weights = :consumer_market)

# At group level
df_fringe_agg = combine(groupby(filter(row -> (row.group == "OTHERS" ) , df), [:date, :market, :smartmeter,:consumer_market]), :share_group => sum => :share_group)
model_agg = reg(df_fringe_agg, @formula(log(share_group)   ~ smartmeter+ fe(market) + fe(date)), Vcov.cluster(:market), weights = :consumer_market)




# Generate latex output 
###################################################################################################################################################################################
regtable(model_agg,model_tou; renderSettings = asciiOutput(), estimformat = "%0.2f",statisticformat="%0.2f", regression_statistics = [:nobs,:adjr2])
regtable(model_agg,model_tou; renderSettings = latexOutput("analysis/output/figure_2b.tex"))

println("The file figure_2b.tex has been successfully created in the analysis\\output folder.")

##################################################################################################################################################################################