rm(list = ls())
setwd('/Users/macbook/Dropbox/Dissertation/Data/Israel')
# setwd('C:\\Users\\Jesse\\Dropbox\\Dissertation\\Data\\Israel')
# setwd('/media/jesse/Files/Dropbox/Dissertation/Data/Israel')
library(foreign)
library(data.table)
library(TSA)
library(vars)
library(zoo)
library(xts)
library(lubridate)
library(changepoint)
library(bcp)
library(ecp)
# Read in data
data <- fread('isr_eventdata.csv')
# Data setup
old_data <- data

data <- old_data
setkeyv(data, c('year', 'month', 'day'))
# Create a WEEK count
data$date <- as.Date(paste(data$year, data$month, data$day, sep = '-'), format = '%Y-%m-%d')
data <- data[date > as.Date('2001-01-01') & date < as.Date('2005-02-09')]

# data$week <- floor_date(data$date, 'month')
### ROUND DATES DOWN TO MONTH
data$date_month <- floor_date(data$date, 'month')
data$week <- floor_date(data$date, 'week')
# data$week <- data$week - (min(data$week)-1)
# Drop a couple of miscoded locations
data <- data[lat > 30]

# Deal with actions with UNKNOWN outcomes
data[isr_noncom == 555, isr_noncom := median(isr_noncom[isr_noncom != 555], na.rm = T)]
data[pal_milita == 555, pal_milita := median(pal_milita[pal_milita != 555], na.rm = T)]
data[isr_milita == 555, isr_milita := median(isr_milita[isr_milita != 555], na.rm = T)]
data[propertyda == 555, propertyda := median(propertyda[propertyda != 555], na.rm = T)]

# Actor setup
pal_milactors = c('palgun', 'palmil', 'hamas', 'ij', 'palgov', 'pflp', 'prc', 'dflp', 'pflp')
pal_civactors = c('palciv', 'palag', 'palres', 'palind')
isr_milactors = c('isrpol', 'idf', 'isrgov')
isr_civactors = c('isrciv', 'isrres', 'isrpol')
small_arms = c('anti-tank missile', 'anti-tank missiles', 'grenade', 'knife', 'medium arms', 'small arms',
               'stones', 'tear gas', 'rubber bullets', 'concussion grenade', 'concussion grenades')
               ## NOTE: TRYING OUT CODING ARTILLERY AS SMALL ARMS - UNCLEAR USE OF WORD IN ARABIC
               # , 'artillery')

big_arms = c('aircraft', 'belt', 'car bomb', 'drone', 'explosives', 'fighter jets',
             'heavy arms', 'helicopter', 'helicopters', 'land-land missile', 'land-land missiles',
             'mortar', 'rockets', 'shelling'
             ## NOTE: ARTILLERY TEMPORARILY MOVED TO SMALL ARMS
             , 'artillery')
direct_fire = c('anti_tank missile', 'anti_tank missiles', 'grenade', 'knife', 'medium arms', 'small arms',
                'stones', 'tear gas', 'rubber bullets', 'concussion grenade', 'concussion grenades',
                'heavy arms')
indirect_fire = c('aircraft', 'belt', 'car bomb', 'drone', 'explosives', 'fighter jets',
                  'helicopter', 'helicopters', 'land-land missile', 'land-land missiles',
                  'mortar', 'rockets', 'shelling')
violent_events = c('shelling', 'shooting', 'beating', 'bombing', 'firefight', 'raid', 'air strike', 'shelrock')
nonviol_events = c('bulldozing', 'crowd control', 'detainment', 'fortification', 'movement restriction', 'vandalism'
                   , 'border closure', 'clash')

# ################### ################### ################### ##################
# REMOVING ALL NON-VIOLENT EVENTS: ONLY KEEPING VIOLENCE
data <- data[(interactio %in% violent_events) & ((actor1 %in% pal_milactors) | (actor1 %in% isr_milactors))]
data <- data[!context %in% c('clash', 'demonstration')]

# Flagging arrest-raids as non-violent actions
# data <- data[!(interactio == 'raid' & actor1 %in% isr_milactors & actor2 == 'palres' & detainment > 0
#                & technology == 'medium arms'
#               & propertyda == 0 & is.na(technolo_1)
#               & pal_fatali == 0 & isr_fatali == 0 & pal_combin == 0), ]

### Types of location
# Population
data[, mean_palevent_pop := mean(as.numeric(Population[actor1 %in% pal_milactors]), na.rm = T), by = list(date_month)]
data[, sd_palevent_pop := sd(as.numeric(Population[actor1 %in% pal_milactors]), na.rm = T), by = list(date_month)]
data[is.na(mean_palevent_pop), mean_palevent_pop := 0]
data[is.na(sd_palevent_pop), sd_palevent_pop := 0]
data[, mean_isrevent_pop := mean(as.numeric(Population[actor1 %in% isr_milactors]), na.rm = T), by = list(date_month)]
data[, sd_isrevent_pop := sd(as.numeric(Population[actor1 %in% isr_milactors]), na.rm = T), by = list(date_month)]
data[is.na(mean_isrevent_pop), mean_isrevent_pop := 0]
data[is.na(sd_isrevent_pop), sd_isrevent_pop := 0]

# Israel vs palestine location
data[, mean_palevent_pal := mean(palestine[actor1 %in% pal_milactors], na.rm = T), by = list(date_month)]
data[is.na(mean_palevent_pal), mean_palevent_pal := mean(data$mean_palevent_pal, na.rm = T)]
data[, mean_isrevent_pal := mean(palestine[actor1 %in% isr_milactors], na.rm = T), by = list(date_month)]
data[is.na(mean_isrevent_pal), mean_isrevent_pal := mean(data$mean_isrevent_pal, na.rm = T)]

# Distance from border
data[, mean_palevent_bdist := mean(mindist_border[actor1 %in% pal_milactors], na.rm = T), by = list(date_month)]
data[, sd_palevent_bdist := sd(mindist_border[actor1 %in% pal_milactors], na.rm = T), by = list(date_month)]
data[is.na(mean_palevent_bdist), mean_palevent_bdist := mean(data$mean_palevent_bdist, na.rm = T)]
data[is.na(sd_palevent_bdist), sd_palevent_bdist := max(data$sd_palevent_bdist, na.rm = T)]
data[, mean_isrevent_bdist := mean(mindist_border[actor1 %in% isr_milactors], na.rm = T), by = list(date_month)]
data[, sd_isrevent_bdist := sd(mindist_border[actor1 %in% isr_milactors], na.rm = T), by = list(date_month)]
data[is.na(mean_isrevent_bdist), mean_isrevent_bdist := mean(data$mean_isrevent_bdist, na.rm = T)]
data[is.na(sd_isrevent_bdist), sd_isrevent_bdist := mean(data$sd_isrevent_bdist, na.rm = T)]

### Casualties
data[, paldead_mo := sum(pal_fatali), by = list(date_month)]
data[, paldead_civ_mo := sum(pal_nonc_1), by = list(date_month)]
data[, paldead_milt_mo := sum(pal_mili_1), by = list(date_month)]
data[, paldead_mili_mo := sum(pal_mili_2), by = list(date_month)]
data[is.na(paldead_mo), paldead_mo := 0]
data[is.na(paldead_civ_mo), paldead_civ_mo := 0]
data[is.na(paldead_mili_mo), paldead_mili_mo := 0]
data[is.na(paldead_milt_mo), paldead_milt_mo := 0]
data[, paldead_mil_mo := paldead_milt_mo + paldead_mili_mo, by = list(date_month)]
data[, paldead_mili_mo := NULL]
data[, paldead_milt_mo := NULL]

data[, isrdead_mo := sum(isr_fatali), by = list(date_month)]
data[, isrdead_civ_mo := sum(isr_nonc_1), by = list(date_month)]
data[, isrdead_mil_mo := sum(isr_combat), by = list(date_month)]
data[is.na(isrdead_mo), isrdead_mo := 0]
data[is.na(isrdead_civ_mo), isrdead_civ_mo := 0]
data[is.na(isrdead_mil_mo), isrdead_mil_mo := 0]

data[, palwound_mo := sum(pal_combin), by = list(date_month)]
data[, palwound_civ_mo := sum(pal_noncom), by = list(date_month)]
data[, palwound_mil_mo := sum(pal_milita), by = list(date_month)]
data[is.na(palwound_mo), palwound_mo := 0]
data[is.na(palwound_civ_mo), palwound_civ_mo := 0]
data[is.na(palwound_mil_mo), palwound_mil_mo := 0]

data[, isrwound_civ_mo := sum(isr_noncom), by = list(date_month)]
data[, isrwound_mil_mo := sum(isr_milita), by = list(date_month)]
data[, isrwound_pol_mo := sum(isr_police), by = list(date_month)]
data[, isrwound_mil_mo := isrwound_mil_mo + isrwound_pol_mo, by = list(date_month)]
data[, isrwound_pol_mo := NULL]
data[is.na(isrwound_civ_mo), isrwound_civ_mo := 0]
data[is.na(isrwound_mil_mo), isrwound_mil_mo := 0]
data[, isrwound_mo := isrwound_civ_mo + isrwound_mil_mo]
data[is.na(isrwound_mo), isrwound_mo := 0]

data[, palcas_mo := paldead_mo]
data[, isrcas_mo := isrdead_mo]

data[, pal_casratio := 0.0]
data[, isr_casratio := 0.0]
data[(palcas_mo + isrcas_mo) > 0, pal_casratio := (palcas_mo) / (isrcas_mo + palcas_mo)]
data[(palcas_mo + isrcas_mo) > 0, isr_casratio := (isrcas_mo) / (isrcas_mo + palcas_mo)]
# data[is.na(pal_casratio), pal_casratio := mean(pal_casratio, na.rm = T)]
# data[is.na(isr_casratio), isr_casratio := mean(isr_casratio, na.rm = T)]
data[, pal_casratio_w := pal_casratio * palcas_mo]
data[, isr_casratio_w := isr_casratio * isrcas_mo]

### Interactions
data[, event := 1.0]
data[, pal_event := sum(event == 1 & (actor1 %in% pal_milactors & interactio %in% violent_events) | (interactio == 'firefight')), by = list(date_month)]
data[, isr_event := sum(event == 1 & (actor1 %in% isr_milactors & interactio %in% violent_events) | (interactio == 'firefight')), by = list(date_month)]
data[, mut_event := sum(event == 1 & interactio %in% 'firefight'), by = list(date_month)]

# Shootings
data[, pal_shooting := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'shooting')), by = list(date_month)]
data[pal_event > 0, pal_shooting := pal_shooting / pal_event, by = list(date_month)]
data[, isr_shooting := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'shooting')), by = list(date_month)]
data[isr_event > 0, isr_shooting := isr_shooting / isr_event, by = list(date_month)]

# Firefights
data[, pal_firefight := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'firefight')), by = list(date_month)]
data[pal_event > 0, pal_firefight := pal_firefight / pal_event, by = list(date_month)]
data[, isr_firefight := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'firefight')), by = list(date_month)]
data[isr_event > 0, isr_firefight := isr_firefight / isr_event, by = list(date_month)]

# Shellings
data[, pal_shelling := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'shelling')), by = list(date_month)]
data[pal_event > 0, pal_shelling := pal_shelling / pal_event, by = list(date_month)]
data[, pal_smallshelling := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'shelling' & technolo_1 %in% small_arms)), by = list(date_month)]
data[pal_event > 0, pal_smallshelling := pal_smallshelling / pal_event, by = list(date_month)]
data[, pal_bigshelling := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'shelling' & technolo_1 %in% big_arms)), by = list(date_month)]
data[pal_event > 0, pal_bigshelling := pal_bigshelling / pal_event, by = list(date_month)]

data[, isr_shelling := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'shelling')), by = list(date_month)]
data[isr_event > 0, isr_shelling := isr_shelling / isr_event, by = list(date_month)]
data[, isr_smallshelling := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'shelling' & technolo_1 %in% small_arms)), by = list(date_month)]
data[isr_event > 0, isr_smallshelling := isr_smallshelling / isr_event, by = list(date_month)]
data[, isr_bigshelling := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'shelling' & technolo_1 %in% big_arms)), by = list(date_month)]
data[isr_event > 0, isr_bigshelling := isr_bigshelling / isr_event, by = list(date_month)]

# Bombings
data[, pal_bombing := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'bombing')), by = list(date_month)]
data[pal_event > 0, pal_bombing := pal_bombing / pal_event, by = list(date_month)]
data[, pal_suicidebombing := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'bombing' & (context %in% 'suicide' | technolo_1 %in% 'belt'))), by = list(date_month)]
data[pal_event > 0, pal_suicidebombing := pal_suicidebombing / pal_event, by = list(date_month)]
data[, isr_bombing := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'bombing')), by = list(date_month)]
data[isr_event > 0, isr_bombing := isr_bombing / isr_event, by = list(date_month)]

# Raids
data[, pal_raid := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'raid')), by = list(date_month)]
data[pal_event > 0, pal_raid := pal_raid / pal_event, by = list(date_month)]
data[, isr_raid := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'raid')), by = list(date_month)]
data[isr_event > 0, isr_raid := isr_raid / isr_event, by = list(date_month)]
data[, isr_smallraid := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'raid' & technolo_1 %in% small_arms)), by = list(date_month)]
data[isr_event > 0, isr_smallraid := isr_smallraid / isr_event, by = list(date_month)]
data[, isr_bigraid := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'raid' & technolo_1 %in% big_arms)), by = list(date_month)]
data[isr_event > 0, isr_bigraid := isr_bigraid / isr_event, by = list(date_month)]

# Beatings 
data[, pal_beating := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'beating')), by = list(date_month)]
data[pal_event > 0, pal_beating := pal_beating / pal_event, by = list(date_month)]

# Clashes
data[, pal_clash := as.numeric(sum(actor1 %in% pal_milactors & interactio == 'crowd control')), by = list(date_month)]
data[pal_event > 0, pal_clash := pal_clash / pal_event, by = list(date_month)]

# Air strikes
data[, isr_airstrike := as.numeric(sum(actor1 %in% isr_milactors & interactio == 'air strike')), by = list(date_month)]
data[isr_event > 0, isr_airstrike := isr_airstrike / isr_event, by = list(date_month)]

# Nonviolent/defensive
data[, isr_nonviol := as.numeric(sum(actor1 %in% isr_milactors & interactio %in% c('bulldozing', 'detainment', 'movement restriction'))), by = list(date_month)]
data[isr_event > 0, isr_nonviol := isr_nonviol / isr_event, by = list(date_month)]

### Type of technology
# Heavy vs light arms
data[, pal_bigtech := as.numeric(sum(actor1 %in% pal_milactors & technology %in% big_arms)), by = list(date_month)]
data[, pal_smalltech := as.numeric(sum(actor1 %in% pal_milactors & technology %in% small_arms)), by = list(date_month)]
data[pal_event > 0, pal_bigtech := pal_bigtech / pal_event, by = list(date_month)]
data[, isr_bigtech := as.numeric(sum(actor1 %in% isr_milactors & technology %in% big_arms)), by = list(date_month)]
data[, isr_smalltech := as.numeric(sum(actor1 %in% isr_milactors & technology %in% small_arms)), by = list(date_month)]
data[isr_event > 0, isr_bigtech := isr_bigtech / isr_event, by = list(date_month)]

# Direct vs indirect fire
data[, pal_direct := as.numeric(sum((actor1 %in% pal_milactors & technology %in% direct_fire) | (interactio %in% 'firefight'))), by = list(date_month)]
data[pal_event > 0, pal_direct := pal_direct / pal_event, by = list(date_month)]
data[, pal_indirect := as.numeric(sum(actor1 %in% pal_milactors & technology %in% indirect_fire)), by = list(date_month)]
data[pal_event > 0, pal_indirect := pal_indirect / pal_event, by = list(date_month)]
data[, isr_direct := as.numeric(sum((actor1 %in% isr_milactors & technology %in% direct_fire) | (interactio %in% 'firefight'))), by = list(date_month)]
data[isr_event > 0, isr_direct := isr_direct / isr_event, by = list(date_month)]
data[, isr_indirect := as.numeric(sum(actor1 %in% isr_milactors & technology %in% indirect_fire)), by = list(date_month)]
data[isr_event > 0, isr_indirect := isr_indirect / isr_event, by = list(date_month)]


# On-site vs remote attacks
data[, pal_remote := as.numeric(sum(actor1 %in% pal_milactors 
                                    & (technology %in% indirect_fire | interactio %in% 'shelling')
                                    & israel == 1)), by = list(date_month)]
data[pal_event > 0, pal_remote := pal_remote / pal_event, by = list(date_month)]
plot(data$pal_remote)


### Targets
data[, pal_civtargeting := as.numeric(sum(actor1 %in% pal_milactors & actor2 %in% isr_civactors & interactio %in% violent_events)), by = list(date_month)]
data[pal_event > 0, pal_civtargeting := pal_civtargeting / pal_event, by = list(date_month)]
data[, pal_miltargeting := as.numeric(sum(actor1 %in% pal_milactors & actor2 %in% isr_milactors & interactio %in% violent_events)), by = list(date_month)]
data[pal_event > 0, pal_miltargeting := pal_miltargeting / pal_event, by = list(date_month)]

data[, isr_civtargeting := as.numeric(sum(actor1 %in% isr_milactors & actor2 %in% pal_civactors 
                                          & interactio %in% violent_events & interactio != 'raid')), by = list(date_month)]
data[isr_event > 0, isr_civtargeting := isr_civtargeting / isr_event, by = list(date_month)]
data[, isr_miltargeting := as.numeric(sum(actor1 %in% isr_milactors & actor2 %in% pal_milactors & interactio %in% violent_events)), by = list(date_month)]
data[isr_event > 0, isr_miltargeting := isr_miltargeting / isr_event, by = list(date_month)]


## Test
data[, isr_bigtech := isr_bigtech * isr_event]
data[, isr_raid := isr_raid * isr_event]
data[, pal_indirect := pal_indirect * pal_event]
data[, pal_remote := pal_remote * pal_event]
data[, isr_civtargeting := isr_civtargeting * isr_event]
data[, pal_civtargeting := pal_civtargeting * isr_event]

### Collapse to year-month level
old_data2 <- data
#data <- old_data2
data <- data[!duplicated(data[, date_month]), ]
# data <- data[!duplicated(data[, list(date)]), ]
# data <- data[!duplicated(data[, list(year,month)]), ]


#################################################################
######## Preliminary models
######## Changepoint detection (CPT)
library(bcp)
library(forecast)
library(TTR)
bcp_function <- function(inputs){
  # inputs <- scale(inputs)
  bcp_est <- bcp(inputs, w0 = 0.001, p0 = 0.00001, burnin = 1000, mcmc = 10000)
  plot(bcp_est, separated = F)
  return(bcp_est)
}

### Palestinian strategy
# Location
# inputs1 <- SMA(xts(data[, list(log(mean_palevent_pop+1))], order.by = data$date), n = Nsmooth)
inputs1 <- xts(data[, list(log(mean_palevent_pop+1))], order.by = data$date)
# inputs1 <- SMA(xts(data[, list(mean_palevent_bdist)], order.by = data$date), n = Nsmooth)
# inputs1 <- xts(data[, list(mean_palevent_bdist)], order.by = data$date)
inputs1 <- inputs1[!is.na(inputs1)]
pal_diffloc <- diff(inputs1)
pos_pal_diffloc <- abs(inputs1)
pos_pal_diffloc[pal_diffloc < 0] <- 0
pos_pal_diffloc <- cumsum(pos_pal_diffloc)
pos_pal_loc_bcp <- bcp_function(pos_pal_diffloc)
pos_pal_locmeans <- pos_pal_loc_bcp$posterior.mean
pos_pal_locprobs <- pos_pal_loc_bcp$posterior.prob

neg_pal_diffloc <- -abs(inputs1)
neg_pal_diffloc[pal_diffloc > 0] <- 0
neg_pal_diffloc <- cumsum(neg_pal_diffloc)
neg_pal_loc_bcp <- bcp_function(neg_pal_diffloc)
neg_pal_locmeans <- neg_pal_loc_bcp$posterior.mean
neg_pal_locprobs <- neg_pal_loc_bcp$posterior.prob

plot(inputs1, type = 'l', main = 'Palestinian Mean Target Population')
par(new = T)
plot(xts(pos_pal_locprobs, order.by = data$date), col = 'blue', axes = FALSE, bty = "n", xlab = "", ylab = "", ylim = c(0,1), main = NA)
lines(xts(neg_pal_locprobs, order.by = data$date), col = 'red')


# Technology
# inputs2 <- SMA(xts(data[, list(pal_remote)], order.by = data$date), n = Nsmooth)
inputs2 <- xts(data[, list(pal_indirect)], order.by = data$date)
inputs2 <- inputs2[!is.na(inputs2)]
pal_difftech <- diff(inputs2)
pos_pal_difftech <- inputs2
pos_pal_difftech[pal_difftech < 0] <- 0
pos_pal_difftech <- cumsum(pos_pal_difftech)
pos_pal_tech_bcp <- bcp_function(pos_pal_difftech)
pos_pal_techmeans <- pos_pal_tech_bcp$posterior.mean
pos_pal_techprobs <- pos_pal_tech_bcp$posterior.prob

neg_pal_difftech <- inputs2
neg_pal_difftech[pal_difftech > 0] <- 0
neg_pal_difftech <- -cumsum(neg_pal_difftech)
neg_pal_tech_bcp <- bcp_function(neg_pal_difftech)
neg_pal_techmeans <- neg_pal_tech_bcp$posterior.mean
neg_pal_techprobs <- neg_pal_tech_bcp$posterior.prob

plot(inputs2, type = 'l', main = 'Palestinian Indirect-Fire Use')
par(new = T)
plot(xts(pos_pal_techprobs, order.by = data$date), col = 'blue', axes = FALSE, bty = "n", xlab = "", ylab = "", ylim = c(0,1), main = NA)
lines(xts(neg_pal_techprobs, order.by = data$date), col = 'red')

# Target
# inputs3 <- SMA(xts(data[, list(pal_civtargeting)], order.by = data$date), n = Nsmooth)
inputs3 <- xts(data[, list(pal_civtargeting)], order.by = data$date)
inputs3 <- inputs3[!is.na(inputs3)]
pal_difftarg <- diff(inputs3)
pos_pal_difftarg <- inputs3
pos_pal_difftarg[pal_difftarg < 0] <- 0
pos_pal_difftarg <- cumsum(pos_pal_difftarg)
pos_pal_targ_bcp <- bcp_function(pos_pal_difftarg)
pos_pal_targmeans <- pos_pal_targ_bcp$posterior.mean
pos_pal_targprobs <- pos_pal_targ_bcp$posterior.prob

neg_pal_difftarg <- inputs3
neg_pal_difftarg[pal_difftarg > 0] <- 0
neg_pal_difftarg <- -cumsum(neg_pal_difftarg)
neg_pal_targ_bcp <- bcp_function(neg_pal_difftarg)
neg_pal_targmeans <- neg_pal_targ_bcp$posterior.mean
neg_pal_targprobs <- neg_pal_targ_bcp$posterior.prob

plot(as.vector(inputs3), type = 'l', ylim = c(0,1))
lines(pos_pal_targprobs, col = 'blue')
lines(neg_pal_targprobs, col = 'red')

plot(inputs3, type = 'l', main = 'Palestinian Civilian Targeting')
par(new = T)
plot(xts(pos_pal_targprobs, order.by = data$date), col = 'blue', axes = FALSE, bty = "n", xlab = "", ylab = "", ylim = c(0,1), main = NA)
lines(xts(neg_pal_targprobs, order.by = data$date), col = 'red')


### Israeli strategy
# Location
# inputs1 <- EMA(xts(data[, list(log(mean_isrevent_pop+1))], order.by = data$date), n = Nsmooth)
# inputs1 <- xts(data[, list(log(mean_isrevent_pop+1))], order.by = data$date)
# inputs1 <- SMA(xts(data[, list(mean_isrevent_bdist)], order.by = data$date), n = Nsmooth)
inputs1 <- xts(data[, list(mean_isrevent_bdist)], order.by = data$date)
inputs1 <- inputs1[!is.na(inputs1)]
isr_diffloc <- diff(inputs1)
pos_isr_diffloc <- abs(inputs1)
pos_isr_diffloc[isr_diffloc < 0] <- 0
pos_isr_diffloc <- cumsum(pos_isr_diffloc)
pos_isr_loc_bcp <- bcp_function(pos_isr_diffloc)
pos_isr_locmeans <- pos_isr_loc_bcp$posterior.mean
pos_isr_locprobs <- pos_isr_loc_bcp$posterior.prob

neg_isr_diffloc <- -abs(inputs1)
neg_isr_diffloc[isr_diffloc > 0] <- 0
neg_isr_diffloc <- cumsum(neg_isr_diffloc)
neg_isr_loc_bcp <- bcp_function(neg_isr_diffloc)
neg_isr_locmeans <- neg_isr_loc_bcp$posterior.mean
neg_isr_locprobs <- neg_isr_loc_bcp$posterior.prob

plot(inputs1, type = 'l', main = 'Israeli Attacks in Palestine vs Israel')
par(new = T)
plot(xts(pos_isr_locprobs, order.by = data$date), col = 'blue', axes = FALSE, bty = "n", xlab = "", ylab = "", ylim = c(0,1), main = NA)
lines(xts(neg_isr_locprobs, order.by = data$date), col = 'red')


# Technology
# inputs2 <- SMA(xts(data[, list(isr_bigtech)], order.by = data$date), n = Nsmooth)
inputs2 <- xts(data[, list(isr_bigtech)], order.by = data$date)
inputs2 <- inputs2[!is.na(inputs2)]
isr_difftech <- diff(inputs2)
pos_isr_difftech <- inputs2
pos_isr_difftech[isr_difftech < 0] <- 0
pos_isr_difftech <- cumsum(pos_isr_difftech)
pos_isr_tech_bcp <- bcp_function(pos_isr_difftech)
pos_isr_techmeans <- pos_isr_tech_bcp$posterior.mean
pos_isr_techprobs <- pos_isr_tech_bcp$posterior.prob

neg_isr_difftech <- inputs2
neg_isr_difftech[isr_difftech > 0] <- 0
neg_isr_difftech <- -cumsum(neg_isr_difftech)
neg_isr_tech_bcp <- bcp_function(neg_isr_difftech)
neg_isr_techmeans <- neg_isr_tech_bcp$posterior.mean
neg_isr_techprobs <- neg_isr_tech_bcp$posterior.prob

plot(inputs2, type = 'l', main = 'Israeli reliance on heavy arms')
par(new = T)
plot(xts(pos_isr_techprobs, order.by = data$date), col = 'blue', axes = FALSE, bty = "n", xlab = "", ylab = "", ylim = c(0,1), main = NA)
lines(xts(neg_isr_techprobs, order.by = data$date), col = 'red')


# Target
# inputs3 <- SMA(xts(data[, list(isr_civtargeting)], order.by = data$date), n = Nsmooth)
inputs3 <- xts(data[, list(isr_civtargeting)], order.by = data$date)
inputs3 <- inputs3[!is.na(inputs3)]
isr_difftarg <- diff(inputs3)
pos_isr_difftarg <- inputs3
pos_isr_difftarg[isr_difftarg < 0] <- 0
pos_isr_difftarg <- cumsum(pos_isr_difftarg)
pos_isr_targ_bcp <- bcp_function(pos_isr_difftarg)
pos_isr_targmeans <- pos_isr_targ_bcp$posterior.mean
pos_isr_targprobs <- pos_isr_targ_bcp$posterior.prob

neg_isr_difftarg <- inputs3
neg_isr_difftarg[isr_difftarg > 0] <- 0
neg_isr_difftarg <- -cumsum(neg_isr_difftarg)
neg_isr_targ_bcp <- bcp_function(neg_isr_difftarg)
neg_isr_targmeans <- neg_isr_targ_bcp$posterior.mean
neg_isr_targprobs <- neg_isr_targ_bcp$posterior.prob

plot(inputs3, type = 'l', main = 'Israeli civilian targeting')
par(new = T)
plot(xts(pos_isr_targprobs, order.by = data$date), col = 'blue', axes = FALSE, bty = "n", xlab = "", ylab = "", ylim = c(0,1), main = NA)
lines(xts(neg_isr_targprobs, order.by = data$date), col = 'red')


# Casualty Ratio
# inputs4 <- SMA(xts(data[, list(pal_casratio)], order.by = data$date), n = Nsmooth)
inputs4 <- xts(data[, list(pal_casratio)], order.by = data$date)
inputs4 <- inputs4[!is.na(inputs4)]
pal_diffcasr <- diff(inputs4)
pos_pal_diffcasr <- inputs4
pos_pal_diffcasr[pal_diffcasr < 0] <- 0
pos_pal_diffcasr <- cumsum(pos_pal_diffcasr)
pos_pal_casr_bcp <- bcp_function(pos_pal_diffcasr)
pos_pal_casrmeans <- pos_pal_casr_bcp$posterior.mean
pos_pal_casrprobs <- lag(pos_pal_casr_bcp$posterior.prob)

neg_pal_diffcasr <- inputs4
neg_pal_diffcasr[pal_diffcasr > 0] <- 0
neg_pal_diffcasr <- -cumsum(neg_pal_diffcasr)
neg_pal_casr_bcp <- bcp_function(neg_pal_diffcasr)
neg_pal_casrmeans <- neg_pal_casr_bcp$posterior.mean
neg_pal_casrprobs <- neg_pal_casr_bcp$posterior.prob

plot(as.vector(inputs4), type = 'l', ylim = c(0,1))
lines(pos_pal_casrprobs, col = 'blue')
lines(neg_pal_casrprobs, col = 'red')

plot(inputs4, type = 'l', main = 'PAL/ISR casualty ratio (killed & wounded)')
par(new = T)
plot(xts(pos_pal_casrprobs, order.by = data$date), col = 'blue', axes = FALSE, bty = "n", xlab = "", ylab = "", ylim = c(0,1), main = NA)
lines(xts(neg_pal_casrprobs, order.by = data$date), col = 'red')



############ IMPULSES AND RESPONSES
### Israeli action, Palestinian response
# Casualty ratio
# ts_data <- SMA(xts(data[, list(pal_casratio)], order.by = data$date_month), n = Nsmooth)
ts_data <- xts(data[, list(pal_casratio)], order.by = data$date_month)
ts_data <- ts_data[!is.na(ts_data)]


#############################################################################
#############################################################################
input_data <- data.table(pos_pal_locprobs, neg_pal_locprobs
                         , pos_pal_techprobs, neg_pal_techprobs
                         , pos_pal_targprobs, neg_pal_targprobs
                         , pos_isr_locprobs, neg_isr_locprobs
                         , pos_isr_techprobs, neg_isr_techprobs
                         , pos_isr_targprobs, neg_isr_targprobs
                         , pos_pal_casrprobs, neg_pal_casrprobs
                         , as.Date(index(ts_data)))
setnames(input_data, c('pos_pal_loc', 'neg_pal_loc'
                       , 'pos_pal_tech', 'neg_pal_tech'
                       , 'pos_pal_targ', 'neg_pal_targ'
                       , 'pos_isr_loc', 'neg_isr_loc'
                       , 'pos_isr_tech', 'neg_isr_tech'
                       , 'pos_isr_targ', 'neg_isr_targ'
                       , 'pos_pal_casr', 'neg_pal_casr'
                       , 'date_month'))
input_data <- input_data[complete.cases(input_data), ]

## VAR TS modeling
var_function <- function(inputs, exog = NULL){
  # model1 <- VAR(inputs, exogen = exog, p = 2, ic = 'AIC', type = 'const')
  model1 <- SVAR(inputs, exogen = exog, p = 2, ic = 'AIC', type = 'const')
  print(summary(model1))
  return(model1)
}

set.seed(10002)

#### PAL ACTIONS
# Positive shock on CIVILIAN TARGETING from ISRAELI HEAVY WEAPONRY USE
exog = cbind(lag(xts(input_data[,list(pos_pal_casr)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_pal_casr)], order.by = input_data$date_month), 2),
             lag(xts(input_data[,list(pos_isr_tech)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_isr_tech)], order.by = input_data$date_month),2))
exog[is.na(exog)] <- 0
model1 <- auto.arima(input_data[, list(pos_pal_targ)], xreg = exog, trace = T)
model1

# Positive shock on INDIRECT FIRE WEAPONS from ISRAELI HEAVY WEAPONRY USE
exog = cbind(lag(xts(input_data[,list(pos_pal_casr)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_pal_casr)], order.by = input_data$date_month), 2),
             lag(xts(input_data[,list(pos_isr_tech)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_isr_tech)], order.by = input_data$date_month),2))
exog[is.na(exog)] <- 0
model2 <- auto.arima(input_data[, list(pos_pal_tech)], xreg = exog, trace = T)
model2

# Negative  shock on MEAN TARGET POPULATION from ISRAELI PROJECTION INTO PALESTINE 
exog = cbind(lag(xts(input_data[,list(pos_pal_casr)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_pal_casr)], order.by = input_data$date_month), 2),
             lag(xts(input_data[,list(neg_isr_loc)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(neg_isr_loc)], order.by = input_data$date_month),2))
exog[is.na(exog)] <- 0
model3 <- auto.arima(input_data[, list(neg_pal_loc)], xreg = exog, trace = T)
model3


#####################################################################################
#### ISR ACTIONS

# Positive shock on HEAVY WEAPONS USE from PALESTINIAN INDIRECT FIRE USE
exog = cbind(lag(xts(input_data[,list(neg_pal_casr)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(neg_pal_casr)], order.by = input_data$date_month), 2),
             lag(xts(input_data[,list(pos_pal_tech)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_pal_tech)], order.by = input_data$date_month),2))
exog[is.na(exog)] <- 0
model1 <- auto.arima(input_data[, list(pos_isr_tech)], xreg = exog, trace = T)
model1

# Positive shock on CIVILIAN TARGETING from PALESTINIAN CIVILIAN TARGETING
exog = cbind(lag(xts(input_data[,list(neg_pal_casr)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(neg_pal_casr)], order.by = input_data$date_month), 2),
             lag(xts(input_data[,list(pos_pal_targ)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_pal_targ)], order.by = input_data$date_month),2))
exog[is.na(exog)] <- 0
model2 <- auto.arima(input_data[, list(pos_isr_targ)], xreg = exog, trace = T)
model2

# Positive shock on FORCE PROJECTION INTO PALESTINE from PALESTINIAN CIVILIAN TARGETING AND INDIRECT FIRE USE
exog = cbind(lag(xts(input_data[,list(neg_pal_casr)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(neg_pal_casr)], order.by = input_data$date_month), 2),
             lag(xts(input_data[,list(pos_pal_targ)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_pal_targ)], order.by = input_data$date_month),2),
             lag(xts(input_data[,list(pos_pal_tech)], order.by = input_data$date_month)),
             lag(xts(input_data[,list(pos_pal_tech)], order.by = input_data$date_month),2))
exog[is.na(exog)] <- 0
model3 <- auto.arima(input_data[, list(neg_isr_loc)], xreg = exog, trace = T)
model3


## Positive shock on CIVILIAN TARGETING - POSITIVE
inputs = xts(input_data[,list(pos_pal_targ
                              , pos_isr_targ
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'pos_isr_targ'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)

## Negative shock on CIVILIAN TARGETING - NEGATIVE
inputs = xts(input_data[,list(neg_pal_targ
                              , neg_isr_targ
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'neg_isr_targ'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)

#####################################################################################
## Positive shock on INDIRECT TACTICS - POSITIVE
inputs = xts(input_data[,list(pos_pal_tech
                              , pos_isr_tech
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'pos_isr_tech'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)

## Negative shock on INDIRECT TACTICS - NEGATIVE
inputs = xts(input_data[,list(neg_pal_loc, neg_pal_tech
                              , neg_isr_tech
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'neg_isr_tech'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)


#####################################################################################
## Positive shock on LOCATION - POSITIVE
inputs = xts(input_data[,list(pos_pal_tech
                              , pos_isr_loc
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'pos_isr_loc'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)

## Positive shock on LOCATION - NEGATIVE
inputs = xts(input_data[,list(neg_pal_tech
                              , pos_isr_loc
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'pos_isr_loc'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)

## Negative shock on LOCATION - NEGATIVE
inputs = xts(input_data[,list(neg_pal_loc, neg_pal_tech
                              , neg_isr_loc
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'neg_isr_loc'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)

## Negative shock on LOCATION - POSITIVE
inputs = xts(input_data[,list(pos_pal_loc, pos_pal_targ
                              , neg_isr_loc
)], order.by = input_data$date_month)
model2 <- var_function(inputs, exog = exog)
response <- 'neg_isr_loc'
irf_m2 <- irf(model2, n.ahead = 3, runs = 1000, response = response)
plot(irf_m2)