fluidPage(
  markdown("## `ui.R` / `server.R` / `global.R`"),
  sliderInput("n", "N", 0, 100, global_value),
  verbatimTextOutput("txt", placeholder = TRUE),
)
