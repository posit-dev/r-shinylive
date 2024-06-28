library(shiny)

shinyServer(function(input, output, session) {
  output$txt <- renderText({
    paste0("The value of n*2 is ", 2 * input$n)
  })
})