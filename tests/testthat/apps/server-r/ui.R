library(shiny)

shinyUI(fluidPage(
  sliderInput("n", "N", 0, 100, 40),
  verbatimTextOutput("txt", placeholder = TRUE),
))