library(shiny);library(tidyverse);library(viridis)

shinyUI(fluidPage(
  titlePanel("Estimating the effectiveness of traveller screening programs to detect people infected with 2019-nCoV"),
  fluidRow(
    column(width = 3,
           
           h5("Last updated: 2020-Jan-28"),
           h3("Parameters"),
           helpText("Please select parameter values", 
                    "and click submit"),
           helpText("Allow a few seconds for calculations"),
           
           radioButtons(inputId = "relT",label = "Screening", 
                        choices = c("Departure only"='departure',"Arrival only"='arrival', "Both"='both'),
                        selected= 'departure',inline=T),
           sliderInput(inputId="meanIncubate",label="Mean incubation period (days)",
                       min = 0,max=20,value = 5.0,step = .1),
           sliderInput(inputId="meanToAdmit",label="Maximum time from onset to patient isolation (days)",
                       min = 0,max=20,value = 4,step = .1),
           sliderInput(inputId="ff",label="Proportion of cases that develop fever",
                       min = 0,max=1,value = 0.95,step = .01),
           sliderInput(inputId="gg",label="Proportion of cases aware that they had risky exposure",
                       min = 0,max=1,value = 0.2,step = .01),
           sliderInput(inputId="ftime",label="Flight duration (hours)",
                       min = 0,max=100,value = 24,step = .1),
           sliderInput(inputId="f.evaded",label="Fraction of infected travelers who evade screening",
                       min = 0,max=1,value = 0,step = .01),
           withMathJax(),
           sliderInput(inputId="R0",label= '\\( R_0 \\)',
                       min = 0,max=15,value = 2,step = .01),
           
           checkboxInput(inputId="colorblind", label="Use colorblind-friendly palette", value = FALSE),
           submitButton("Submit"),
           h4("Advanced Parameters"),
           helpText("Below are the advanced model parameters"),
           helpText("Current default values are selected"),
           
           sliderInput(inputId="rd",label="Efficacy of departure questionnaire (proportion of travelers that report honestly)",
                       min = 0,max=1,value = .25,step = .1),
           sliderInput(inputId="ra",label="Efficacy of arrival questionnaire",
                       min = 0,max=1,value = .25,step = .1),
           sliderInput(inputId="sdep",label="Efficacy of departure fever screening (fever detection sensitivity)",
                       min = 0,max=1,value = .7,step = .1),
           sliderInput(inputId="sa",label="Efficacy of arrival fever screening",
                       min = 0,max=1,value = .7,step = .1),
           sliderInput(inputId="nboot",label="Number of bootstrap samples",
                       min = 0,max=100,value = 20,step = 1),
           sliderInput(inputId="popn",label="Bootstrap population size",
                       min = 0,max=200,value = 50,step = 1),
           submitButton("Submit")
           
    ),
    column(width =6,
           plotOutput(outputId = "figPanel")
           
           
    ),
    
    column(width =3,style = "background-color:#f1f1f1;",
           htmlOutput(outputId = "columnText1"),
           htmlOutput(outputId = "columnText2")
           
           
           
           
    )
    
  )
))
