#DDP Week 4 Final Project
#Julio Costa 
#2020-05-08

# Load packages
library(shiny)
library(shinythemes)
library(dplyr)
library(readr)
library(forecast)
library(lubridate)
library(xts)


# Load data
state_data <- read_csv("data/us-states.csv")


# Define UI
ui <- fluidPage(theme = shinytheme("lumen"),
                titlePanel("Covid-19 Cases and Deaths per State"),
                sidebarLayout(
                    sidebarPanel(
                        
                        # Select state to plot
                        selectInput(inputId = "state", label = strong("Select State"),
                                    choices = unique(state_data$state),
                                    selected = "New York"),
                        
                        # Select type  to plot; i.e, either number of cases or deaths;
                        #data is cumulative.
                        selectInput(inputId = "type", label = strong("Select Type"),
                                    choices = c("cases","deaths"),
                                    selected = "cases"),
                        
                        #Select Model for forecast
                        selectInput(inputId = "model", label = strong("Select Forecast Model"),
                                    choices = c("ets","auto.arima"),
                                    selected = "ets"),
                        
                        textOutput(outputId = "desc"),
                        
                        # Seletct Number of Days to Forecast
                        sliderInput(inputId="h", label="Number of Periods:",
                                    min=1,max=30,value=4,step=1),
                        HTML("Number of Days for Forecasting"),
                        
                        # Select date range to be plotted
                        dateRangeInput("date", strong("Date range"), start = "2020-01-21", end = "2020-05-02",
                                       min = "2020-01-21", max = "2020-05-02"),
                        
                        # Select whether to overlay smooth trend line
                        checkboxInput(inputId = "smoother", label = strong("Overlay smooth trend line"), value = FALSE),
                        
                        # Display only if the smoother is checked
                        conditionalPanel(condition = "input.smoother == true",
                                         sliderInput(inputId = "f", label = "Smoother span:",
                                                     min = 0.01, max = 1, value = 0.67, step = 0.01,
                                                     animate = animationOptions(interval = 100)),
                                         HTML("Higher values give more smoothness.")
                        )
                        
                       
                    ),
                    
                    # Output: Description, lineplot, and reference
                    mainPanel(
                        plotOutput(outputId = "lineplot", height = "300px"),
                        plotOutput(outputId = "forecastplot",height = "300px")
                    )
                )
)

# Define server function
server <- function(input, output) {
    
    # Subset data
    selected_trends <- reactive({
        req(input$date)
        validate(need(!is.na(input$date[1]) & !is.na(input$date[2]), "Error: Please provide both a start and an end date."))
        validate(need(input$date[1] < input$date[2], "Error: Start date should be earlier than end date."))
        state_data %>%
            select(date,state,type=input$type) %>%
            filter(
                state == input$state,
                date > as.POSIXct(input$date[1]) & date < as.POSIXct(input$date[2],))
      
    })
    
    #subset for forecast
    
    sel_fc<-reactive({
        state_data %>%
            filter(state==input$state,
                   date > as.POSIXct(input$date[1]) & date < as.POSIXct(input$date[2],)) %>%
            select(date,type=input$type)
    })
    
  
    
    # Create scatterplot object the plotOutput function is expecting
    
    output$lineplot <- renderPlot({
        color = "#434343"
        par(mar = c(4, 4, 1, 1))
        plot(x = selected_trends()$date, y = selected_trends()$type, type = "l",
            xlab = "Date", ylab = input$type, col = color, fg = color, col.lab = color, col.axis = color)
         # Display only if smoother is checked
        if(input$smoother){
           smooth_curve <- lowess(x = as.numeric(selected_trends()$date), y = selected_trends()$type, f = input$f)
            lines(smooth_curve, col = "#E6553A", lwd = 3)
       }
    })
    
    output$forecastplot <- renderPlot({
        color = "#434343"
        par(mar = c(4, 4, 1, 1))
        plot(forecast(ets(xts(sel_fc()[,-1],order.by=sel_fc()$date)),h=input$h,level=.95),
             type="l",xlab="Day",ylab=input$type, col = color, fg = color, col.lab = color, col.axis = color)
        if(input$model=="auto.arima"){
            plot(forecast(auto.arima(xts(sel_fc()[,-1],order.by=sel_fc()$date)),h=input$h,level=.95),
                 type="l",xlab="Day",ylab=input$type, col = color, fg = color, col.lab = color, col.axis = color)
        }
    
        
        
    })
   

    # Pull in description of forecast model
    output$desc <- renderText({
         paste("ets: fit the Exponential smoothing state space mode; " ,
        "auto.arima: fit the best ARIMA model to univariate time series.")
    })
}

# Create Shiny object
shinyApp(ui = ui, server = server)