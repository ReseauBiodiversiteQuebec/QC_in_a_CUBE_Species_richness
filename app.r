#### Packages ####
# -------------- #
library(shiny)
library(leaflet)
library(sf)
library(htmltools)
library(terra)

pal <- colorNumeric(
    palette = "viridis",
    domain = c(0, 195) # from 0 to max species
)
qc <- st_read(
    "/vsicurl/https://object-arbutus.cloud.computecanada.ca/bq-io/acer/TdeB_benchmark_SDM/TdB_bench_maps/species_richness/raw_obs/QC_CUBE_Richesse_spe_N02_wkt_raw_obs_SIMPL_latlon.gpkg",
    query = "SELECT geom FROM QC_CUBE_Richesse_spe_N02_wkt_raw_obs_SIMPL_latlon"
)

ui <- bootstrapPage(
    tags$style(
        type = "text/css",
        "html, body {width:100%;height:100%}"
    ),
    leafletOutput(
        "map",
        width = "100%",
        height = "100%"
    ),
    absolutePanel(
        top = 10,
        right = 10,
        selectInput(
            "maptype",
            "Niveau spatial: ",
            choices = c("Provinces naturelles", "Régions naturelles", "Niveaux physiographiques", "Districts écologiques", "10x10 km")
        ),
        sliderInput(
            inputId = "year",
            label = "Année",
            min = 1990,
            max = 2019,
            value = 21,
            step = 1
        )
    )
)

server <- function(input, output, session) {
    # Selected year
    year_obs <- reactive({
        input$year
    })


    filteredData <- reactive({
        if (input$maptype == "Provinces naturelles") {
            map <- st_read(
                "/vsicurl/https://object-arbutus.cloud.computecanada.ca/bq-io/acer/TdeB_benchmark_SDM/TdB_bench_maps/species_richness/raw_obs/QC_CUBE_Richesse_spe_N01_wkt_raw_obs_SIMPL_latlon.gpkg",
                query = paste0("SELECT reg_name, X", year_obs(), ", geom FROM QC_CUBE_Richesse_spe_N01_wkt_raw_obs_SIMPL_latlon")
            )
        }
        if (input$maptype == "Régions naturelles") {
            map <- st_read(
                "/vsicurl/https://object-arbutus.cloud.computecanada.ca/bq-io/acer/TdeB_benchmark_SDM/TdB_bench_maps/species_richness/raw_obs/QC_CUBE_Richesse_spe_N02_wkt_raw_obs_SIMPL_latlon.gpkg",
                query = paste0("SELECT reg_name, X", year_obs(), ", geom FROM QC_CUBE_Richesse_spe_N02_wkt_raw_obs_SIMPL_latlon")
            )
        }
        if (input$maptype == "Niveaux physiographiques") {
            map <- st_read(
                "/vsicurl/https://object-arbutus.cloud.computecanada.ca/bq-io/acer/TdeB_benchmark_SDM/TdB_bench_maps/species_richness/raw_obs/QC_CUBE_Richesse_spe_N03_wkt_raw_obs_SIMPL_latlon.gpkg",
                query = paste0("SELECT reg_name, X", year_obs(), ", geom FROM QC_CUBE_Richesse_spe_N03_wkt_raw_obs_SIMPL_latlon")
            )
        }
        if (input$maptype == "Districts écologiques") {
            map <- st_read(
                "/vsicurl/https://object-arbutus.cloud.computecanada.ca/bq-io/acer/TdeB_benchmark_SDM/TdB_bench_maps/species_richness/raw_obs/QC_CUBE_Richesse_spe_N04_wkt_raw_obs_SIMPL_latlon.gpkg",
                query = paste0("SELECT reg_name, X", year_obs(), ", geom FROM QC_CUBE_Richesse_spe_N04_wkt_raw_obs_SIMPL_latlon")
            )
        }
        if (input$maptype == "10x10 km") {
            map <- st_read(
                "/vsicurl/https://object-arbutus.cloud.computecanada.ca/bq-io/acer/TdeB_benchmark_SDM/TdB_bench_maps/species_richness/raw_obs/QC_CUBE_Richesse_spe_10x10_wkt_raw_obs_SIMPL_latlon.gpkg",
                query = paste0("SELECT ID, X", year_obs(), ", geom FROM QC_CUBE_Richesse_spe_10x10_wkt_raw_obs_SIMPL_latlon")
            )
        }

        names(map)[2] <- "richness"
        if (input$maptype == "10x10 km") {
            labels <- sprintf(
                "<strong>Pixel # %s</strong></br> Richesse spécifique = %g",
                map$ID,
                map$richness
            ) %>%
                lapply(htmltools::HTML)
        } else {
            labels <- sprintf(
                "<strong>%s</strong></br> Richesse spécifique = %g",
                map$reg_name,
                map$richness
            ) %>%
                lapply(htmltools::HTML)
        }
        map$labels <- labels
        return(map)
    })

    output$map <- renderLeaflet({
        leaflet(qc) %>%
            addTiles() %>%
            fitBounds(
                lng1 = -79.76332, # st_bbox(qc)[1],
                lat1 = 44.99136, # st_bbox(qc)[2],
                lng2 = -56.93521, # st_bbox(qc)[3],
                lat2 = 62.58192 # st_bbox(qc)[4]
            ) %>%
            addLegend(
                pal = pal, values = c(0, 195), opacity = 0.7, title = NULL,
                position = "bottomright"
            )
    })

    observe({
        # names(filteredData())[2] <- "richness"
        leafletProxy("map", data = filteredData()) %>%
            clearShapes() %>%
            addPolygons(
                fillCol = ~ pal(filteredData()$richness),
                weight = .75,
                opacity = 1,
                color = "grey",
                fillOpacity = 0.7,
                highlightOptions = highlightOptions(
                    weight = 1.5,
                    # color = "black",
                    fillOpacity = 0.8,
                    bringToFront = TRUE
                ),
                label = filteredData()$labels
            )
    })
}

shinyApp(ui = ui, server = server)
