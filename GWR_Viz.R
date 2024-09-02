################ app.R #######################
library(shiny)
library(plotly)
library(spgwr)
library(sp)
library(spdep)
library(RColorBrewer)

# Generating sample data

set.seed(123) # Try different values
n <- 100 # Maybe 200? but it will affect the bandwidth and may cause the app to crush
coords <- cbind(runif(n), runif(n))
x1 <- runif(n)
x2 <- runif(n)
y <- 2 + 3 * x1 + 4 * x2 + rnorm(n, sd = 0.5)


data <- data.frame(x = coords[,1], y = coords[,2], x1 = x1, x2 = x2, z = y)
coordinates(data) <- ~x+y


################## UI Side #################


ui <- fluidPage(
  titlePanel("Interactive 3D Geographically Weighted Regression (GWR) Visualization"),
  
  sidebarLayout(
    sidebarPanel(
      h3("Controls"),
      sliderInput("bandwidth", "Bandwidth:", min = 0.1, max = 1, value = 0.5, step = 0.1),
      selectInput("view_type", "View Type:", 
                  choices = c("Raw Data", "GWR Results", "Model Comparison"),
                  selected = "Raw Data"),
      actionButton("help_button", "Help & Tutorial"),
      width = 3
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Visualization",
                 plotlyOutput("main_plot", height = "600px"),
                 verbatimTextOutput("gwr_summary"),
                 width = 9),
        tabPanel("Interpretation", 
                 h3("Interpreting GWR Results"),
                 p("Geographically Weighted Regression (GWR) provides local coefficient estimates for each location in your study area. These coefficients allow you to understand how relationships between variables change across space. Here's how to interpret the results:"),
                 tags$ul(
                   tags$li("Coefficient values: These indicate the strength and direction of the relationship between the independent variables and the dependent variable at each location. Positive values suggest a positive relationship, while negative values indicate a negative relationship."),
                   tags$li("Varying coefficients: Unlike global regression models that produce a single coefficient for the entire study area, GWR coefficients vary by location. This variation reflects how the relationship between variables differs across space, capturing local variations that global models might overlook."),
                   tags$li("T-values: These values indicate the statistical significance of the local coefficients. High absolute T-values suggest that the relationship at a particular location is statistically significant, while low T-values indicate a weaker or non-significant relationship.")
                 ),
                 p("Use the 3D visualization to explore how these relationships vary across space. Areas with higher elevation or different colors in the plot typically indicate stronger relationships or more significant coefficients. By interacting with the plot, you can gain deeper insights into the spatial heterogeneity in your data, which is a key feature of GWR.")
        ),
        
        tabPanel("Help", 
                 h3("How to Use This App"),
                 p("1. Start by exploring the raw data using the 2D and 3D visualizations. This helps you understand the initial spatial distribution of your data."),
                 p("2. Adjust the bandwidth slider to change the kernel function's influence area. The bandwidth controls how localized the GWR model is, with smaller bandwidths resulting in more local models."),
                 p("3. Click 'Run GWR Analysis' to perform the GWR and view the results. The app will calculate local regression coefficients that vary across space."),
                 p("4. Compare GWR results with the global regression model by selecting the 'Model Comparison' view. This will show you how GWR captures spatial heterogeneity better than a traditional Ordinary Least Squares (OLS) model."),
                 p("5. Use the 'Interpretation' tab for detailed guidance on understanding the results of the GWR analysis."),
                 br(),
                 h4("Key Concepts:"),
                 tags$ul(
                   tags$li("Bandwidth: The bandwidth controls the radius of influence for each regression point. Smaller bandwidths lead to more localized models, emphasizing the effect of nearby data points, while larger bandwidths produce results more akin to global regression."),
                   tags$li("Local Coefficients: GWR computes separate coefficients for each location, allowing relationships between variables to vary across space. This feature is crucial for identifying local patterns that a global model might miss."),
                   tags$li("Spatial Heterogeneity: This refers to the way relationships between variables can change depending on geographic location. GWR is particularly effective in capturing and visualizing these variations, making it a powerful tool for spatial analysis.")
                 ),
                 p("For further reading and a more in-depth understanding of GWR, consider reviewing the following references:"),
                 tags$ul(
                   tags$li("Brunsdon, C., Fotheringham, A. S., & Charlton, M. E. (1996). Geographically weighted regression: A method for exploring spatial nonstationarity. *Geographical Analysis*, 28(4), 281-298. doi:10.1111/j.1538-4632.1996.tb00936.x"),
                   tags$li("Fotheringham, A. S., Brunsdon, C., & Charlton, M. (2002). *Geographically Weighted Regression: The Analysis of Spatially Varying Relationships*. Wiley."),
                   tags$li("Wheeler, D., & Tiefelsdorf, M. (2005). Multicollinearity and correlation among local regression coefficients in geographically weighted regression. *Journal of Geographical Systems*, 7(2), 161-187. doi:10.1007/s10109-005-0155-6")
                 )
        )
      )
        )
     
    )
  )

###################### Server Side #################################
server <- function(input, output, session) {
  
  # Reactive GWR model
  gwr_model <- reactive({
    gwr(z ~ x1 + x2, data = data, bandwidth = input$bandwidth, hatmatrix = TRUE)
  })
  
  # Main plot rendering
  output$main_plot <- renderPlotly({
    if (input$view_type == "Raw Data") {
      plot_ly(data = as.data.frame(data), x = ~x, y = ~y, z = ~z, type = "scatter3d", mode = "markers",
              marker = list(size = 5, color = ~z, colorscale = "Viridis", showscale = TRUE)) %>%
        layout(scene = list(xaxis = list(title = "X Coordinate"),
                            yaxis = list(title = "Y Coordinate"),
                            zaxis = list(title = "Dependent Variable")),
               title = "Raw Data Distribution")
    } else if (input$view_type == "GWR Results") {
      gwr_result <- gwr_model()
      coef_data <- as.data.frame(gwr_result$SDF)
      
      plot_ly() %>%
        add_trace(data = coef_data, x = ~x, y = ~y, z = ~`(Intercept)`, type = "scatter3d", mode = "markers",
                  marker = list(size = 5, color = ~`(Intercept)`, colorscale = "Viridis", showscale = TRUE),
                  name = "Intercept") %>%
        add_trace(data = coef_data, x = ~x, y = ~y, z = ~x1, type = "scatter3d", mode = "markers",
                  marker = list(size = 5, color = ~x1, colorscale = "RdBu", showscale = TRUE),
                  name = "X1 Coefficient") %>%
        add_trace(data = coef_data, x = ~x, y = ~y, z = ~x2, type = "scatter3d", mode = "markers",
                  marker = list(size = 5, color = ~x2, colorscale = "RdBu", showscale = TRUE),
                  name = "X2 Coefficient") %>%
        layout(scene = list(xaxis = list(title = "X Coordinate"),
                            yaxis = list(title = "Y Coordinate"),
                            zaxis = list(title = "Coefficient Value")),
               title = "GWR Coefficients")
    } else if (input$view_type == "Model Comparison") {
      gwr_result <- gwr_model()
      ols_result <- lm(z ~ x1 + x2, data = data)
      
      plot_ly() %>%
        add_trace(data = as.data.frame(data), x = ~x, y = ~y, z = ~z, type = "scatter3d", mode = "markers",
                  marker = list(size = 5, color = "blue", opacity = 0.5),
                  name = "Observed Data") %>%
        add_trace(data = as.data.frame(data), x = ~x, y = ~y, z = ~fitted(ols_result), type = "scatter3d", mode = "markers",
                  marker = list(size = 5, color = "red", opacity = 0.5),
                  name = "OLS Predictions") %>%
        add_trace(data = as.data.frame(data), x = ~x, y = ~y, z = ~gwr_result$SDF$pred, type = "scatter3d", mode = "markers",
                  marker = list(size = 5, color = "green", opacity = 0.5),
                  name = "GWR Predictions") %>%
        layout(scene = list(xaxis = list(title = "X Coordinate"),
                            yaxis = list(title = "Y Coordinate"),
                            zaxis = list(title = "Dependent Variable")),
               title = "Model Comparison: Observed vs OLS vs GWR")
    }
  })
  
  # GWR Summary
  output$gwr_summary <- renderPrint({
    if (input$view_type %in% c("GWR Results", "Model Comparison")) {
      gwr_result <- gwr_model()
      cat("GWR Model Summary:\n")
      print(summary(gwr_result))
    }
  })
  
  # Help & Tutorial Button
  
  observeEvent(input$help_button, {
    showModal(modalDialog(
      title = "GWR Visualization Help & Tutorial",
      HTML("
        <h4>Welcome to the Interactive GWR Visualization!</h4>
        <p>This app helps you understand Geographically Weighted Regression (GWR) through interactive 3D visualizations.</p>
        <h5>Key Concepts:</h5>
        <ul>
          <li><strong>GWR:</strong> A spatial analysis method that allows regression coefficients to vary over space.</li>
          <li><strong>Bandwidth:</strong> Controls the extent of geographical weighting. Smaller values result in more local models.</li>
        </ul>
        <h5>How to Use:</h5>
        <ol>
          <li>Start with the 'Raw Data' view to understand the spatial distribution of your data.</li>
          <li>Switch to 'GWR Results' to see how coefficients vary across space.</li>
          <li>Use the 'Model Comparison' view to compare GWR with global OLS regression.</li>
          <li>Adjust the bandwidth slider to see how it affects the GWR results.</li>
          <li>Interact with the 3D plots: rotate, zoom, and hover for more information.</li>
        </ol>
        <p>Remember: GWR is sensitive to bandwidth selection. Experiment with different values to understand its impact!</p>
      "),
      easyClose = TRUE,
      footer = NULL
    ))
  })
}

#####################

shinyApp(ui = ui, server = server)