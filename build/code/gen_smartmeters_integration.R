
#############################################################################################################
# This code generates the file "smartmeter.csv" which contains the percentage of smart meters integration 
# by distributor. 
#############################################################################################################


#### Set up working directory 

rm(list=ls())


library(dplyr) 
library(tidyr) #long wide
library(tibble) #add_columns()

shared_drive_path <- "G:/.shortcut-targets-by-id/1228X8RU2Xkced7TkxtaslDYk-7N6XLww/ENECML/"
path <- paste0(shared_drive_path,"05_retail_competition/raw_data/smartmeters_raw/")
setwd(path)
getwd()




#######################################################################
##### 1. Cleaning csv ##################################
#######################################################################

# 2015 _______________________________________________________________________________________________
# Load data
df1<-read.csv("smartmeters15.csv")

# Get rid of headers 
df1<-df1[df1$JULIO!="JULIO",]

# SIN DATOS to NA 
df1[df1=="SIN DATOS"]<-NA

# Convert to numeric 
df1[, 2:7] <- lapply(df1[, 2:7], as.numeric)


# To absolute value, negative values are a reading problem from excel 
df1 <- df1 %>% mutate_if(is.numeric, abs)

# Add label 
df1$year<-"2015"


# Insert column 
df1<-add_column(df1,NA,.after = "CODIGO.DIS") # Jan 
df1<-add_column(df1,NA,.after = "CODIGO.DIS") # Feb
df1<-add_column(df1,NA,.after = "CODIGO.DIS") # March 
df1<-add_column(df1,NA,.after = "CODIGO.DIS") # April
df1<-add_column(df1,NA,.after = "CODIGO.DIS") # May
df1<-add_column(df1,NA,.after = "CODIGO.DIS") # June



# 2016 _______________________________________________________________________________________________
# Load data
df21<-read.csv("smartmeters16_1.csv")
df22<-read.csv("smartmeters16_2.csv")


# Get rid of headers 
df21<-df21[df21$ENERO!="ENERO",]
df22<-df22[df22$JULIO!="JULIO",]
df22 <-df22[df22$CODIGO.DIS!= "", ]
df22<-df22[df22$JULIO!="Situación especial",]


# SIN DATOS to NA 
df21[df21=="SIN DATOS"]<-NA
df22[df22=="SIN DATOS"]<-NA


# Convert to numeric 
df21[, 2:7] <- lapply(df21[, 2:7], as.numeric)
df22[, 2:7] <- lapply(df22[, 2:7], as.numeric)

# To absolute value, negative values are a reading problem from excel 
df21 <- df21 %>% mutate_if(is.numeric, abs)
df22 <- df22 %>% mutate_if(is.numeric, abs)
df2<-merge(df21,df22,by="CODIGO.DIS",all.x = T)


# Add label 
df2$year<-"2016"


# 2017 _______________________________________________________________________________________________
# Load data
df3<-read.csv("smartmeters17.csv")

# Delete rows with blank values and headers
df3 <- df3[df3$DIS!= "", ]
df3 <- df3[df3$DIS!= "DIS", ]

# SIN DATOS to NA 
df3[df3=="SIN DATOS"]<-NA

# To numeric
df3[, 2:13] <- lapply(df3[, 2:13], as.numeric)
df3 <- df3 %>% mutate_if(is.numeric, abs)


# Add label 
df3$year<-"2017"


# 2018 _______________________________________________________________________________________________
# Load data
df4<-read.csv("smartmeters18.csv")

# Delete rows with blank values and headers
df4 <- df4[df4$DIS!= "", ]
df4 <- df4[df4$DIS!= "DIS", ]

# SIN DATOS to NA 
df4[df4=="SIN DATOS"]<-NA


# To numeric
df4<-as.data.frame(lapply(df4, function(y) gsub("%", "", y)))
df4<-as.data.frame(lapply(df4, function(y) gsub(",", ".", y)))
df4[, 2:13] <- lapply(df4[, 2:13], as.numeric)
df4 <- df4 %>% mutate_if(is.numeric, abs)
df4 <- df4 %>% mutate_if(is.numeric, ~./100)


# Add label 
df4$year<-"2018"



# 2019 _______________________________________________________________________________________________
# Load data
df5<-read.csv("smartmeters19.csv")

# Delete rows with blank values and headers
df5 <- df5[df5$DIS!= "", ]
df5 <- df5[df5$DIS!= "DIS", ]

# SIN DATOS to NA 
df5[df5=="SIN DATOS"]<-NA


# To numeric
df5<-as.data.frame(lapply(df5, function(y) gsub("%", "", y)))
df5<-as.data.frame(lapply(df5, function(y) gsub(",", ".", y)))
df5[, 2:13] <- lapply(df5[, 2:13], as.numeric)
df5 <- df5 %>% mutate_if(is.numeric, abs)
df5 <- df5 %>% mutate_if(is.numeric, ~./100)


# Add label 
df5$year<-"2019"


# Rbind all year togethers 
newnames<-c("distr",	"Jan",	"Feb",	"Mar",	"Apr",	"May", "Jun","Jul",	"Aug",	"Sep",	"Oct",	"Nov",	"Dec",	"year")
df<-list(df1,df2,df3,df4,df5)
df<-lapply(df, setNames, newnames)%>%
  bind_rows()


# Write to csv
# write.csv(df,"smartmeter_unweighted.csv",row.names = F)


# To long 
df <- df %>% gather(month, smartmeters, -c(distr, year))




#######################################################################
##### 2. Transforming format ##################################
#######################################################################
# Load weighs (number of consumers)
path <- paste0(shared_drive_path,"05_retail_competition/raw_data/")
setwd(path)
w<-read.csv("consumers_ccaa.csv")


# Check no missing for important distributors
large<-c("R1-001","R1-002","R1-003","R1-005","R1-008","R1-299")
df%>%filter(distr %in%large)%>%filter(is.na(smartmeters))

# Drop missing 
df<-na.omit(df)

# Change label to quarters
df$month<-gsub("Jan","T1",df$month)
df$month<-gsub("Feb","T1",df$month)
df$month<-gsub("Mar","T1",df$month)

df$month<-gsub("Apr","T2",df$month)
df$month<-gsub("May","T2",df$month)
df$month<-gsub("Jun","T2",df$month)

df$month<-gsub("Jul","T3",df$month)
df$month<-gsub("Aug","T3",df$month)
df$month<-gsub("Sep","T3",df$month)

df$month<-gsub("Oct","T4",df$month)
df$month<-gsub("Nov","T4",df$month)
df$month<-gsub("Dec","T4",df$month)

# Mean 
df$FECHA<-paste(df$year,df$month,sep="_")
df<-df%>%select(-year,-month)
df<-df%>%group_by(distr,FECHA)%>%summarise(smartmeters=mean(smartmeters))
names(df)[1]<-"COD_DIS"

# Weight for VIESGO and BARRAS 
wv<-w%>%
  filter(COD_DIS=="R1-005"|COD_DIS=="R1-003")%>%
  select(FECHA,COD_DIS,Suma.de.NUMERO_SUMINISTROS)%>%
  group_by(FECHA,COD_DIS)%>%
  summarise(cons=sum(Suma.de.NUMERO_SUMINISTROS))%>%
  group_by(FECHA)%>%
  mutate(total=sum(cons),weight=round(cons/total,4))%>%
  select(FECHA,COD_DIS,weight)
 

# Weight for others 
wo<-w%>%
  filter(!COD_DIS %in% large)%>%
  select(FECHA,COD_DIS,Suma.de.NUMERO_SUMINISTROS)%>%
  group_by(FECHA,COD_DIS)%>%
  summarise(cons=sum(Suma.de.NUMERO_SUMINISTROS))%>%
  group_by(FECHA)%>%
  mutate(total=sum(cons),weight=round(cons/total,4))%>%
  select(FECHA,COD_DIS,weight)


# Large not viesgo: nothing
notviesgo<-c("R1-001","R1-002","R1-008","R1-299")
df1<-df%>%filter(COD_DIS %in% notviesgo)
df1$COD_DIS[df1$COD_DIS=="R1-001"]<-"IBERDROLA"
df1$COD_DIS[df1$COD_DIS=="R1-002"]<-"GAS NATURAL"
df1$COD_DIS[df1$COD_DIS=="R1-008"]<-"EDP"
df1$COD_DIS[df1$COD_DIS=="R1-299"]<-"ENDESA"
names(df1)[1]<-"group"

# Viesgo 
df2<-df%>%filter(COD_DIS=="R1-005"|COD_DIS=="R1-003")
df2<-merge(df2,wv,by=c("FECHA","COD_DIS"),all.x=T)
df2$value<-df2$smartmeters*df2$weight
df2<-df2%>%group_by(FECHA)%>%summarise(smartmeters=sum(value))
df2$group<-"REPSOL"

# Others 
df3<-df%>%filter(!COD_DIS %in% large)
df3<-merge(df3,wo,by=c("FECHA","COD_DIS"),all.x=T)
df3$weight[is.na(df3$weight)]<-0
df3$value<-df3$smartmeters*df3$weight
df3<-df3%>%group_by(FECHA)%>%summarise(smartmeters=sum(value))
df3$group<-"OTROS"


# rbind
dfinal<-plyr::rbind.fill(df1,df2,df3)
names(dfinal)[3]<-"smartmeter"


# write.csv
write.csv(dfinal,"smartmeter.csv",row.names = F)
