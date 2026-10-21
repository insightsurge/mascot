main <- new.env(parent = environment())
sys.source(file.path("app", "view", "main.R"), envir = main)
shiny::shinyApp(main$app_ui, main$app_server)
