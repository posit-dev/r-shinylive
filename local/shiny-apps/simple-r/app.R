library(shiny)

shinyApp(
    fluidPage(
        sliderInput("n", "N", 0, 100, 40),
        verbatimTextOutput("txt", placeholder = TRUE),
    ),
    function(input, output) {
        output$txt <- renderText({
            paste0("The value of n*2 is ", 2 * input$n)
        })
    }
)
