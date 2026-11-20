# Small app exported by .github/workflows/test-deploy-app.yaml
library(shiny)

ui <- fluidPage(
  sliderInput("n", "Number", min = 1, max = 10, value = 5),
  textOutput("doubled")
)

server <- function(input, output, session) {
  output$doubled <- renderText(input$n * 2)
}

shinyApp(ui, server)
