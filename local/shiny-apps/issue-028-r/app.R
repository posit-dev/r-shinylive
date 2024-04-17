library(shiny)

ui <- fluidPage(verbatimTextOutput("search_values"))

server <- function(input, output, session) {
  observe({
    str(reactiveValuesToList(session$clientData))
  })

  output$search_values <- renderText({
    invalidateLater(1000)
    paste(capture.output({
      print(Sys.time())
      str(getQueryString())
    }), collapse = "\n")
  })
}

shinyApp(ui, server)
