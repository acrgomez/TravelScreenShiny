#
# This is a Shiny web application by Ana Gomez
#


shinyServer(function(input, output,session) {

    session$onSessionEnded(function() {
        stopApp()
    })
    
    
    ############################################################################
    ############################################################################
    

    
    
    output$figPanel <- renderPlot({
        if(input$colorblind) { 
          colList<<- cividis(9)
          
        } else {
          colList <<- c('darkseagreen2', 'deepskyblue', 'seagreen4', 'royalblue3', 'bisque', 'darksalmon', 'brown3', 'firebrick1','darkorange')
          
          }
        ##Grid of ribbon plots
        relT <<- as.numeric(input$relT)          # Overall (0) or arrival (1) screening
        ff <<- as.numeric(input$ff)
        ftime <<- as.numeric(input$ftime)          #Travel time (hours)
        del.d <<- ftime/24
        R0 <<- as.numeric(input$R0)
        gg <<- as.numeric(input$gg)
        f.evaded <<- as.numeric(input$f.evaded)
        
        meanIncubate <<- as.numeric(input$meanIncubate)
        meanToAdmit <<- as.numeric(input$meanToAdmit)
        scaleIncubate <<- 2.73
        shapeIncubate <<- meanIncubate/scaleIncubate
        
        ##Advanced parameters
        #Specify efficacy parameters. These will be fed in to the external functions.
        rd <<- as.numeric(input$rd) #efficacy of departure questionnaire (proportion of travelers that report honestly)
        ra <<- as.numeric(input$ra) #efficacy of arrival questionnaire
        sdep <<- as.numeric(input$sdep) #efficacy of departure fever screening (based on fever detection sensitivity)
        sa <<- as.numeric(input$sa) #efficacy of arrival fever screening
        nboot <<- as.numeric(input$nboot)       # n bootstrap samples
        popn <<- as.numeric(input$popn)        # population size of infected travelers
        
        
        
        make_plots(meanIncubate = as.numeric(input$meanIncubate), 
                   meanToAdmit = as.numeric(input$meanToAdmit), 
                   R0 = as.numeric(input$R0), 
                   ff = as.numeric(input$ff), 
                   gg = .2, 
                   flight.hrs = as.numeric(input$ftime), 
                   screenType = as.character(input$relT))
        
       
    },height=1000)

    output$columnText1 <- renderText({
      "
    Preprint with detailed information on the model is now on medrxiv: <a href='https://www.medrxiv.org/content/10.1101/2020.01.28.20019224v1'>https://www.medrxiv.org/content/10.1101/2020.01.28.20019224v1</a>
      
      <br>
      <br>
      This is an adaptation of the model presented in  <a href='https://elifesciences.org/articles/05564'>Gostic KM, Kucharski AJ, Lloyd-Smith JO. (2015) eLife 4:e05564</a>,
      which evaluates the effectiveness of traveller screening for emerging pathogens. 
      Further details can be found there, and in a manuscript we have written on traveller 
      screening for 2019-nCoV which presents estimates and uncertainties that reflect 
      current knowledge of this virus.
      <br>
      As new parameter estimates and more knowledge of the natural history of 2019-nCoV become 
      available, this app can be used to estimate the effectiveness of different traveller 
      screening programs.  
      
      <br>
      <br>
      The first plot shows the proportion of infected travellers expected to be 
      detected by screening programs that encompass screening for fever (or other distinctive symptoms),
      screening for known risk of exposure, or both. The results assume that the source population is 
      experiencing a growing epidemic. The 95% confidence interval shown reflects the random variation 
      in outcome for a set of 50 travellers. The results are conditioned on the parameter values and do
      not capture uncertainties regarding the natural history or epidemiology of the virus. 
      Parameter values can be adjusted on the interactive panel to the left, including whether 
      screening occurs at departure or arrival or both.
      <br>
      <br>
      The second plot shows the expected outcomes for infected travellers, showing the factors
      that led to their infection being detected or missed (as shown in the legend).
      <br>
      <br>
      The last plot shows the expected proportion of exposed travellers who were detected or
      missed by screening as a function of the time between an individual's exposure and the
      departure leg of the journey. The colors again indicate the reason they were detected or
      missed. 
      
      
      <br>
      <br>
      <br>
      <br>
      
      
      
      This Shiny app is based on the analysis presented in:
      <br>
      <a href='https://www.medrxiv.org/content/10.1101/2020.01.28.20019224v1'>
      Estimated effectiveness of traveller screening to prevent international 
      spread of 2019 novel coronavirus (2019-nCoV), by Katelyn M. Gostic, Ana C. R. Gomez, 
      Riley O. Mummah, Adam J. Kucharski, and James O. Lloyd-Smith. </a>
            
      
      <br>
      <br>
      Code development for the app by Ana Gomez (acrgomez at ucla dot edu), 
      with underlying model code from Katie Gostic (kgostic at uchicago dot edu).
            <br>
      <br>
      The associated manuscript is currently available at <a href='https://kgostic.github.io/traveller_screening/'>https://kgostic.github.io/traveller_screening/</a>
            <br>
      <br>
      Funding support from NSF, DARPA, SERDP, The McDonnell foundation, CAPES, 
      Wellcome Trust & the Royal Society
       <br>
    
      "
        
    })
})

