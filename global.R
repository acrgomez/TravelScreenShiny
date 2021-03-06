library(ggplot2)
library(grid)
library(gridExtra)
library(tidyverse)


## ------------------------------------------------------------
## \\\\\\\\\\\\\\ DEFINE GLOBAL VARIABLES ////////////////// ##
## ------------------------------------------------------------
## Set Global Vars
pathogen=c("nCoV")
pathtablab=c("2019-nCoV")
par(mfrow = c(length(pathtablab), 1))
#Growing (0) or flat (1) epidemic
flatA=0
cat.labels = c('detected: departure fever screen', "detected: departure risk screen", "detected: arrival fever screen",
               "detected: arrival risk screen", 'missed: had both', 'missed: had fever', 'missed: had risk awareness', 
               'missed: undetectable')


## -----------------------------------------------------
## \\\\\\\\\\\\\\ DEFINE FUNCTIONS ////////////////// ##
## -----------------------------------------------------
incubation.d <- function(x){
  pgamma(x, shape = shapeIncubate, scale = scaleIncubate)
}

# ---------
# Calculate infection age distributions for a growing epidemic
pdf.cdf.travel<-function(x,r0,gen.time,type){
  # Input: x - time since exposure, r0 - pathogen R_0 value, gen.time - pathogen generation time,
  # type - [pdf = 1, cdf = 2]
  # Output: if type = 1, output the density of infection age x among a population of 
  # exposed individuals attempting travel. If type = 2, output the cumulative density.
  alpha=r0/gen.time
  f01<-function(tt){exp(-alpha*tt)}                  #dI/dt
  f11<-function(tt){(1/alpha)*(1-exp(-alpha*tt))}    #I(t)
  if(type==1){
    sapply(x,function(a){if(a<gen.time){f01(a)/f11(gen.time)}else{0}}) #pdf
  }else{
    sapply(x,function(a){if(a<gen.time){f11(a)/f11(gen.time)}else{1}}) #cdf
  }
}
## --------------

## -------------------------
exposure.distn = function(x,r0, meanToAdmit, meanIncubate){
  ## Draw from the infection age cdf using an input uniform random variable, x
  (data.frame(xx = seq(0, 40, by = 0.1)) %>%             # Evaluate cdf at a range of values
     mutate(c.dens = pdf.cdf.travel(xx, r0, meanToAdmit+meanIncubate, type = 2)) %>%
     filter(c.dens>x) %>%                                # Extract the first value at which the cum.dens > x
     pull(xx))[1]
}
## -------------------------



## --------------
screen.passengers = function(d, del.d, f, g, sd = 1, sa =1, rd = 1, ra = 1, 
                             phi.d, incubation.d, pathogen, relative=0, split1=0, 
                             arrival_screen, departure_screen){
  ## Arrival Screening Decision Tree Model
  #   INPUTS:
  #   d = days since onset
  #   del.d = days spent in flight (can be a fraction)
  #   f = probability that patients present with fever at onset
  #   g = probability that patients are aware of exposure risk factors
  #   sd = symptom screen effectiveness on departure
  #   sa = symptom screen effectiveness on arrival
  #   rd = risk factor screen effectiveness on departure
  #   ra = risk factor screen effectiveness on arrival
  #   phi.d = call to function describing pdf of time from exposure to outcome
  #   incubation.d = call to function describing pdf of time from exposure to onset
  #   pathogen = name of the pathogen (e.g. "H7N9")
  #   relative: this takes a logical value. The default is 0 or FALSE, which tells the function to return
  #                the absolute proprtion of travellers detected at arrival. If relative is set to 1 or TRUE, 
  #                the script will return the proportion of infected travellers detected at arrival given 
  #                that they were missed during departure screening
  #                (i.e. [# detected at arrival]/[# missed at departure])
  #   split1: If 1, the function outputs the following vector:
  #                [stopped.at.departure.fever,
  #                 stopped.at.departure.risk,
  #                 stopped.at.arrival.fever,
  #                 stopped.at.arrival.risk,
  #                 cleared.at.arrival]
  #           If 0 (default), the function outputs only: 
  #                 1-[cleared.at.arriva]
  #           If 2, outputs  [stopped.at.departure.fever,
  #                 stopped.at.departure.risk,
  #                 stopped.at.arrival.fever,
  #                 stopped.at.arrival.risk,
  #                 cleared.at.arrival,
  #                 missed.both,
  #                 missed.fever,
  #                 missed.risk,
  #                 not.detectable]
  #         
  #           ALL OUTPUTS ARE GIVEN AS THE PROPORTION OF INFECTED TRAVELLERS IN EACH OUTCOME CLASS
  
  ##Define an internal function to pass travellers in any detection class
  # through the model
  screen.cases = function(case){
    
    #Case 1 = has fever and aware of risk factors
    #Case 2 = has fever and NOT aware of risk factors
    #Case 3 = does NOT have fever and aware of risk factors
    #Case 4 = does NOT have fever and NOT aware of risk factors
    #The proportion of travellers that fall into each case (detection class)
    #is determined by values of f and g
    
    #Split in to groups with and without symptoms upon departure
    Sd = incubation.d(d) #Incubation.d(d) is the CDF of exposure -> onset
    NSd = (1-incubation.d(d))
    
    #SYMPTOM SCREEN
    #First screen symptomatic patients
    #Sd.... denotes symptom onset at departure
    if(!departure_screen | case %in% c(3,4)){          #If no departure screen, or no fever present at onset, skip symptom screen
      Sd.sspass = Sd #If no fever at onset, all pass           #Move on
      Sd.ssfail = 0                                            #Detained
    }else{                                             #If fever at onset, perform symptom screen
      Sd.sspass = Sd*(1-sd) #(1-sd) pass                       #Move on 
      Sd.ssfail = Sd*sd     # (sd) fail                        #Detained
    }
    
    #No symptom screen for asymptomatic patients (all pass)
    #NSd.... denotes NO symptom onset at departure
    NSd.sspass = NSd                                           #Move on
    NSd.ssfail = 0                                             #Detained
    
    
    ## RISK SCREEN - only those in sspass categories move on
    if(!departure_screen | case %in% c(2,4)){        ## Don't screen
      Sd.sspass.rspass = Sd.sspass                        # Move on
      Sd.sspass.rsfail = 0                                # Detained
      NSd.sspass.rspass = NSd.sspass                      # Move on
      NSd.sspass.rsfail = 0                               # Detained
    }else{                                            ## Do screen
      Sd.sspass.rspass = Sd.sspass*(1-rd)                  # Move on
      Sd.sspass.rsfail = Sd.sspass*rd                      # Detained
      NSd.sspass.rspass = NSd.sspass*(1-rd)                # Move on
      NSd.sspass.rsfail = NSd.sspass*rd                    # Detained
    }
    
    
    ### \\\\\\\\\\\\\\\\\\\\\\\\\\\\ FLIGHT TAKES OFF /////////////////////////////// ###
    #TOTAL FLYING AND DETAINED
    #Passengers can be stoped if (1) Symptomatic and fail symptom screen, (2) Asymptomatic and fail SS (this should be 0),
    #  (3) Symptomatic, pass SS but fail RS, (4) Asymptomatic and pass SS but fail RS
    stopped.at.departure.fever = Sd.ssfail + NSd.ssfail  
    stopped.at.departure.risk = Sd.sspass.rsfail + NSd.sspass.rsfail
    stopped.at.departure = stopped.at.departure.fever+stopped.at.departure.risk
    #Passengers are only cleared if they pass both screens
    cleared.at.departure = Sd.sspass.rspass + NSd.sspass.rspass
    
    #With symptoms at departure
    Sd.arrive = Sd.sspass.rspass
    #Without symptoms at departure
    NSd.arrive = NSd.sspass.rspass
    
    
    ### \\\\\\\\\\\\\\\\\\\\\\\\\\\\ FLIGHT LANDS /////////////////////////////// ###
    #SYMPTOM DEVELOPMENT IN FLIGHT
    #calculate the conditional probability of developing symptoms on flight given no
    #symptoms at departure
    p.new.symptoms = ifelse(arrival_screen, ((incubation.d(d+del.d)-incubation.d(d))/(1-incubation.d(d))), 0)
    Sa.arrive = NSd.arrive*p.new.symptoms #Sa.... denotes symptoms on arrival, but not at departure
    NS.arrive = NSd.arrive*(1-p.new.symptoms) #NS... denotes no symptoms on arrival
    #No modulation of Sd.arrive because this group was already symptomatic
    #Now there are three branches: Sa (symptoms on arrival), Sd (symptoms on departure), NS (no symptoms)
    #Remember we are still in a function that applies this decision tree to each of 4 f,g cases
    
    #SYMPTOM SCREEN
    #First screen symptomatic patients
    if(!arrival_screen | case %in% c(3,4)){          #If no arrival screen, or no fever present at onset, skip symptom screen
      Sd.arrive.sspass = Sd.arrive                                             #Move on 
      Sd.arrive.ssfail = 0                                                     #Detained
      Sa.arrive.sspass = Sa.arrive                                             #Move on
      Sa.arrive.ssfail = 0                                                     #Detained
    }else{                                            # Do screen
      Sd.arrive.sspass = Sd.arrive*(1-sa)    #(1-sa) pass                      #Move on 
      Sd.arrive.ssfail = Sd.arrive*sa        # (sa) faill                      #Detained
      Sa.arrive.sspass = Sa.arrive*(1-sa)                                      #Move on
      Sa.arrive.ssfail = Sa.arrive*sa                                          #Detained
    }
    
    
    #No symptom screen for asymptomatic patients (all pass)
    NS.arrive.sspass = NS.arrive                                                   #Move on
    NS.arrive.ssfail = 0                                                           #Detained
    
    
    #RISK SCREEN
    if(!arrival_screen | case %in% c(2,4)){          #If no arrival screen, or no risk awareness, don't screen
      Sd.arrive.sspass.rspass = Sd.arrive.sspass                           # Move on
      Sd.arrive.sspass.rsfail = 0                                          # Detained
      Sa.arrive.sspass.rspass = Sa.arrive.sspass                           # Move on
      Sa.arrive.sspass.rsfail = 0                                          # Detained
      NS.arrive.sspass.rspass = NS.arrive.sspass                           # Move on
      NS.arrive.sspass.rsfail = 0                                          # Detained
    }else{                                           #If passengers are aware of risk factors, perform screen
      Sd.arrive.sspass.rspass = Sd.arrive.sspass*(1-ra)                    # Move on
      Sd.arrive.sspass.rsfail = Sd.arrive.sspass*ra                        # Detained
      Sa.arrive.sspass.rspass = Sa.arrive.sspass*(1-ra)                    # Move on
      Sa.arrive.sspass.rsfail = Sa.arrive.sspass*ra                        # Detained
      NS.arrive.sspass.rspass = NS.arrive.sspass*(1-ra)                    # Move on
      NS.arrive.sspass.rsfail = NS.arrive.sspass*ra                        # Detained
    }
    
    
    #TOTAL DETAINED AND FREE
    #Passengers in each of three classes (Sd, Sa, NS) are detained if they fail SS or pass SS and fail RS
    stopped.at.arrival.fever=(Sd.arrive.ssfail + Sa.arrive.ssfail + NS.arrive.ssfail)
    stopped.at.arrival.risk=(Sd.arrive.sspass.rsfail + Sa.arrive.sspass.rsfail + NS.arrive.sspass.rsfail)
    stopped.at.arrival = stopped.at.arrival.risk+stopped.at.arrival.fever
    
    #Passengers in each of three classes are cleared only if they pass both screens
    cleared.at.arrival = (Sd.arrive.sspass.rspass + Sa.arrive.sspass.rspass + NS.arrive.sspass.rspass)
    
    
    #specify whether relative or absolute
    # Give proportion caught
    if(relative==1){
      outputs=1-cleared.at.arrival/cleared.at.departure #
      names(outputs) = 'excess.frac.caught.at.arrival'
    }else{
      outputs=1-cleared.at.arrival #overall fraction missed
      names(outputs) = 'p.missed'
    }
    
    if(split1%in%c(1,2)){
      #den1=1#cleared.at.departure
      if(case %in% c(1,2)){ ## If symptoms could have developed
        outputs=c(stopped.at.departure.fever, stopped.at.departure.risk, stopped.at.arrival.fever, stopped.at.arrival.risk, 
                  Sd.arrive.sspass.rspass+Sa.arrive.sspass.rspass, NS.arrive.sspass.rspass)
      }else{
        outputs=c(stopped.at.departure.fever, stopped.at.departure.risk, stopped.at.arrival.fever, stopped.at.arrival.risk, 0, cleared.at.arrival)
      }
      names(outputs) = c('caught.dpt.fever', 'caught.dpt.risk', 'caught.arv.fever', 'caught.arv.risk', 'missed.sd', 'missed.nsd')
    }
    
    return(outputs)
    
  }
  
  
  ff1=f
  gg1=g
  
  #Define the proportion of travellers that fall into each detection class (case)
  cases1 = c(1*c(ff1*gg1, ff1*(1-gg1), (1-ff1)*gg1, (1-ff1)*(1-gg1)))
  
  if(split1 == 2){
    c1 = cases1[1]*screen.cases(1) %>% as.numeric() # Had both
    c2 = cases1[2]*screen.cases(2) %>% as.numeric() # Had fever only
    c3 = cases1[3]*screen.cases(3) %>% as.numeric() # Had risk only
    c4 = cases1[4]*screen.cases(4) %>% as.numeric() # Had neither (not detectable)
    
    return(c('caught.dpt.fever' = c1[1]+c2[1]+c3[1]+c4[1], 
             'caught.dpt.risk'= c1[2]+c2[2]+c3[2]+c4[2], 
             'caught.arv.fever' = c1[3]+c2[3]+c3[3]+c4[3], 
             'caught.arv.risk' = c1[4]+c2[4]+c3[4]+c4[4], 
             'missed.both' = c1[5],
             'missed.fever.only' = c2[5],
             'missed.risk.only' = c3[6]+c1[6],
             'not.detectable' = c2[6]+c4[6]))
  }
  
  #Run the screen.cases function for the appropriate case and weight by the 
  #  appropriate proportion of travellers
  cases1[1]*screen.cases(1)+cases1[2]*screen.cases(2)+cases1[3]*screen.cases(3)+cases1[4]*screen.cases(4)
  
}
## --------------


# -------------------------------
#get_frac_caught = function(tSinceExposed, ff, gg, R0, meanToAdmit, meanIncubate = NULL, dscreen, ascreen, shapeIncubate = NULL, scaleIncubate = 2.73){
get_frac_caught = function(tSinceExposed, ff, gg, R0, meanToAdmit, dscreen, ascreen, incubation.d){
  ## Calculate the fraction/probability of each screening outcome given a fixed time since exposure
  ## INPUTS
  ## f1 - probability of fever at onset
  ## g1 - probability aware of risk
  ## meanToAdmit - mean days from onset to admission (this is the detectable window) 
  ## meanIncubate - mean incubation period (exposure ot onset). If meanIncubate specified, assume a gamma distribution with scale = 2.73 and calculate appropriate shape. Alternatively, can specify shape and scale explicitly.
  ## OUTPUTS - vector. Fraction caught by: departure risk, departure fever, arrival risk, arrival fever, cleared.
  
  # if(length(meanIncubate)>0){         ## If mean incubation period specified, calculate shape
  #   shapeIncubate = meanIncubate/scaleIncubate
  # }else if(length(shapeIncubate)==0){ ## Else, use explicit shape and scale inputs
  #   stop('Error - Must specify meanIncubate or shape and scale!')
  # }
  # # Get probability that symptoms have developed.
  # incubation.d<-(function(d)pgamma(d, shape = shapeIncubate, scale = scaleIncubate))
  ## Outputs
  screen.passengers(tSinceExposed, del.d, ff, gg, sdep, sa, rd, ra, phi.d, incubation.d, pathogen, relative = 0, split1 = 2, arrival_screen = ascreen, departure_screen = dscreen)
}
# ## Test function
# get_frac_caught(tSinceExposed = 2, ff = .7, gg = .2, R0 = 2, meanToAdmit = 5.5, dscreen = TRUE, ascreen = FALSE, incubation.d)
# -------------------------------

# -------------------------------
## Write a function that repeats get_frac_caught over a grid of times since exposure
get_frac_caught_over_time = function(ff, gg, R0, meanToAdmit, ascreen, dscreen, incubation.d){
  arrive.times=seq(0,15,0.1)
  sapply(arrive.times, function(tt){get_frac_caught(tSinceExposed = tt, ff, gg, R0, meanToAdmit, dscreen, ascreen,incubation.d)}) %>% t() %>% as.data.frame() %>% mutate(
    days.since.exposed = arrive.times)
}
# Test
# get_frac_caught_over_time(ff = .7, gg = .2, R0 = 2, meanToAdmit = 5.5, ascreen = TRUE, dscreen = FALSE, function(x){pgamma(x, 1.6, scale = 2.8)})
# -------------------------------

# -------------------------------
# Simulate the fraction of the population caught or missed in a growing epidemic.
one_bootstrap = function(meanIncubate, meanToAdmit, R0, ff, gg, del.d, arrival_screen, departure_screen){
  ## For each individual in the population, draw times since exposre from the appropriate distribution
  infAge=sapply(runif(popn),function(x){exposure.distn(x, R0, meanToAdmit, meanIncubate)})
  
  
  outcomesBoth=sapply(infAge, FUN = function(x){screen.passengers(x, del.d, ff, gg, sdep, sa, rd, ra, 0, incubation.d, pathogen, relative = 0, split1 = 2, arrival_screen, departure_screen)})
  ## Output individual probability missed
  pCaught_both = colSums(outcomesBoth[1:4,])
  caughtBoth = sapply(pCaught_both,function(x){ifelse(x<runif(1, 0, 1),0,1)})                   ## Draw whether individual was missed
  
  
  ## Fever only
  # outcomesFever=sapply(infAge,function(x){
  #   f0=rbinom(1,fever.sample.size,fever.prob)/fever.sample.size  ## Draw binomial probability of fever
  #   g0=0  ## Draw binomial probability of known risk  
  #   screenWrapper(x, f0, g0)})     
  outcomesFever=sapply(infAge, FUN = function(x){screen.passengers(x, del.d, ff, 0, sdep, sa, rd, ra, phi.d, incubation.d, pathogen, relative = 0, split1 = 2, arrival_screen, departure_screen)})
  pCaught_fever = colSums(outcomesFever[1:4,])                                                    ## Output individual probability missed
  caughtFever = sapply(pCaught_fever,function(x){ifelse(x<runif(1, 0, 1),0,1)})                   ## Draw whether individual was missed
  
  
  ## Risk only
  # outcomesRisk=sapply(infAge,function(x){
  #   f0=0  ## Draw binomial probability of fever
  #   g0=rbinom(1,risk.sample.size, risk.prob)/risk.sample.size                                   ## Draw binomial probability of known risk  
  #   screenWrapper(x, f0, g0)})                                                                  ## Output individual probability missed
  outcomesRisk=sapply(infAge, FUN = function(x){screen.passengers(x, del.d, 0, gg, sdep, sa, rd, ra, phi.d, incubation.d, pathogen, relative = 0, split1 = 2, arrival_screen, departure_screen)})
  pCaught_risk = colSums(outcomesRisk[1:4,])
  caughtRisk = sapply(pCaught_risk,function(x){ifelse(x<runif(1, 0, 1),0,1)})                   ## Draw whether individual was missed
  
  
  ## Return frac.missed.both, frac.missed.fever, frac.missed.risk
  # return(c(frac.missed.both = 1- sum(caughtBoth)/popn,
  #          frac.missed.fever = 1- sum(caughtFever)/popn,
  #          frac.missed.risk = 1- sum(caughtRisk)/popn))
  
  # if(outtype == 'caught'){
  #   return(c(frac.missed.both = 1- sum(caughtBoth)/popn,
  #                     frac.missed.fever = 1- sum(caughtFever)/popn,
  #                     frac.missed.risk = 1- sum(caughtRisk)/popn))
  # }else if(outtype == 'meanOutcomes'){
  return(list(outcomesBoth = rowMeans(outcomesBoth),
              outcomesFever = rowMeans(outcomesFever),
              outcomesRisk = rowMeans(outcomesRisk),
              caught = c(frac.missed.both = 1- sum(caughtBoth)/popn,
                         frac.missed.fever = 1- sum(caughtFever)/popn,
                         frac.missed.risk = 1- sum(caughtRisk)/popn)))
}
# ## Test
# one_bootstrap(meanIncubate = 4.5, meanToAdmit = 5.5, R0 = 2, ff = .7, gg = .1, del.d = 1, arrival_screen = TRUE, departure_screen = TRUE)
# -------------------------------



make_plots = function(meanIncubate, meanToAdmit, R0, ff, gg, flight.hrs, screenType){
  if(screenType == 'both'){
    arrival_screen = departure_screen = TRUE
  }else if (screenType == 'arrival'){
    arrival_screen = TRUE
    departure_screen = FALSE
  }else if(screenType == 'departure'){
    arrival_screen = FALSE
    departure_screen = TRUE
  }
  
  
  # -------------------------------
  # Ribbon Plot
  # -------------------------------
  get_frac_caught_over_time(ff, gg, R0, meanToAdmit, arrival_screen, departure_screen, incubation.d) %>%
    ## Specify minim and maximum y values in each band
    mutate(dFeverMin = 0, dFeverMax = dFeverMin + caught.dpt.fever,
           dRiskMin = dFeverMax, dRiskMax = dRiskMin + caught.dpt.risk,
           aFeverMin = dRiskMax, aFeverMax = aFeverMin + caught.arv.fever,
           aRiskMin = aFeverMax, aRiskMax = aRiskMin +caught.arv.risk,
           mbMin = aRiskMax, mbMax = mbMin+missed.both,
           mfMin = mbMax, mfMax = mfMin+missed.fever.only,
           mrMin = mfMax, mrMax = mrMin+missed.risk.only,
           ndMin = mrMax, ndMax = ndMin + not.detectable) %>%
    select(days.since.exposed, contains('Min'), contains('Max')) %>%
    ## Pivot to long data frame
    pivot_longer(cols = dFeverMin:ndMax, names_to = c('outcome', 'minOrMax'), names_pattern = '(\\w+)(M\\w\\w)', values_to = 'yy') -> temp
  ## Use full join to create columns for time, ymin, ymax, and band type
  full_join(filter(temp, minOrMax == 'Min'), filter(temp, minOrMax == 'Max'), by = c('days.since.exposed', 'outcome'), suffix = c('min', 'max'))%>%
    select(-starts_with('min')) %>% 
    ## Clean up categorical variables so that plot labels are publication quality 
    mutate(outcome = factor(outcome, levels =c('dFever', 'dRisk', 'aFever', 'aRisk', 'mb', 'mf', 'mr', 'nd'), 
                            labels =(cat.labels))) -> rib
  ## Plot
  
  
  
  bootList <- replicate(n = nboot, one_bootstrap(meanIncubate, meanToAdmit, R0, ff, gg, del.d, arrival_screen, departure_screen)) 
  
  # -------------------------------
  ### Fraction missed
  # -------------------------------
  sapply(bootList[4,], function(yy){yy})  %>% t() %>% as.data.frame() %>%
    pivot_longer(1:3, names_to = c('screen_type'), names_pattern = 'frac.missed.(\\w+)', values_to = 'frac.missed') %>%
    group_by(screen_type) %>%
    summarise(med = median(frac.missed),
              lower = quantile(frac.missed, probs = .025),
              upper = quantile(frac.missed, probs = .975)) -> fracMis
  
  #fracMissed
  #ggsave('2020_nCov/Shiny_fraction_missed.pdf', width = 4, height = 4, units = 'in')  
  
  # -------------------------------
  ## Stacked barplot
  # -------------------------------
  bind_rows(
    bothMedians = sapply(bootList[1,], function(yy){yy}) %>% rowMeans,
    feverMedians = sapply(bootList[2,], function(yy){yy}) %>% rowMeans,
    riskMedians = sapply(bootList[3,], function(yy){yy}) %>% rowMeans
  ) %>%
    mutate(strategy = c('both', 'fever', 'risk')) -> meanOutcomes
  names(meanOutcomes) = c('d.fever', 'd.risk', 'a.fever', 'a.risk', 'm.b', 'm.f', 
                          'm.r', 'nd',  'strategy')
  
  meanOutcomes %>%
    pivot_longer(cols = 1:8) %>%
    mutate(outcome = factor(name, levels = (c('d.fever', 'd.risk', 'a.fever', 'a.risk', 'm.b', 'm.f', 'm.r', 'nd')),
                            labels =(cat.labels)),
           strategy = factor(strategy)) -> stackedB
  
  dashedLine = group_by(stackedB, strategy) %>%
    filter(name %in% c('m.b', 'm.f', 'm.r', 'nd')) %>%
    group_by(strategy) %>%
    summarise(yy = sum(value))
  
  stackedB$outcome <- factor(stackedB$outcome,levels=rev(levels(stackedB$outcome)))
  ggplot(stackedB)+
    geom_bar(aes(x = strategy, y = value, fill = outcome), stat = 'identity',width = .65)+
    scale_fill_manual(values = rev(colList)) +
    xlab('Screening type')+
    ylab('Fraction screened          Fraction detected') +
    geom_text(data=fracMis,aes(x=1:3,y=1-lower+1.3,label=paste(round(1-med,4)*100,"% [",round(1-lower,4)*100,", ",round(1-upper,4)*100,"]",sep="")))+
    geom_segment(data=fracMis,aes(x = screen_type, xend = screen_type, y = 1-lower+1.25, yend = 1-upper+1.25),lwd=2)+
    geom_point(data=fracMis,aes(x = screen_type, y = 1-med+1.25), size = 4,alpha=.7)+
    scale_y_continuous(lim=c(0,2.25),breaks=c(seq(0,1,.25),seq(1.25,2.25,.25)),labels = c(seq(0,1,.25),seq(0,1,.25)))+
    geom_hline(yintercept = 1.125) +
    geom_segment(data = dashedLine, aes(x = as.numeric(strategy)-.5, xend = as.numeric(strategy)+.5, y = 1-yy, yend = 1-yy), linetype = 2)+
    scale_x_discrete(labels=c("fever & risk","fever","risk"))+
    theme_bw(base_size = 16)+
    theme(legend.position="bottom",legend.title = element_blank())+
    ggtitle("Screening in a population of infected travellers, 
            each with a different time of exposure")+
    guides(fill = guide_legend(nrow = 4))-> stackedBars
  
  dashedCurve <- filter(rib, outcome =="missed: had both")
  ggplot(rib)+
    geom_ribbon(aes(x = days.since.exposed, ymin = yymin, ymax = yymax, fill = outcome))+
    scale_fill_manual(values = colList,guide = guide_legend(reverse=TRUE))+
    theme_bw(base_size = 16) +
    theme(legend.position="none")+
    ggtitle("Probability of detecting any single infected 
             individual, given time since exposure")+
    geom_line(data=dashedCurve,aes(x=days.since.exposed,y=yymin),lty=2)+
    #theme(legend.position = 'none')+
    ylab('Probability exposed individual is missed or detected')+
    xlab('Days since exposure') -> ribbon
  
  
  
  #shape=k scale= theta
  #scale = variance/mean
  #shape = mean/scale
  theta = varIncubate/meanIncubate
  k = meanIncubate/theta   
  xx = seq(0, 25, by = .01)
  dat <- data.frame(xval=xx,
                    vals=dgamma(xx,shape = k,scale = theta))

  
  IncPlot <-ggplot(dat)+
    geom_line(aes(x=xval,y=vals),lwd=1)+
    scale_x_continuous(limits = c(0,25))+
    xlab("incubation period (days)")+
    theme_bw(base_size=16)+
    ggtitle("Assumed incubation period distribution")+
    ylab("density")
  
  return(grid.arrange(stackedBars,ribbon,IncPlot) )
}

# Test
#make_plots(meanIncubate = 4.5, meanToAdmit = 5.5, R0 = 2, ff = .7, gg = .2, flight.hrs = 24, screenType = 'both')
