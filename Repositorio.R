# =============================================================================
#  Repositorio.R
# -----------------------------------------------------------------------------
#
#  ARCHIVOS DE ENTRADA
#    sesiones_dt.csv.gz                 
#    legisladores_bloque_provincia.csv
#
#  SALIDAS (carpeta salidas/)
#    puntos_ideales_pca.csv      diputado × año: dim1 (punto ideal), dim2, bloque, provincia
#    red_grado.csv               diputado × año: grado en la red de afinidad
#    controles.txt               conteos y verificaciones de la corrida
#    puntos_ideales_por_anio.png
#    red_afinidad_AAAA.png       una por año

install.packages("igraph")
install.packages("ggraph")

library(tidyverse)
library(igraph)
library(ggraph)

dir.create("salidas", showWarnings = FALSE)
controles <- character()                      # lo que se va anotando para controles.txt
anotar <- function(...) { txt <- sprintf(...); cat(txt, "\n"); controles <<- c(controles, txt) }

CORTE_COR <- 0.60       # correlación mínima para unir a dos diputados
N_BLOQUES <- 8          # bloques con color propio; el resto, gris "Otros"

# Diputados de referencia para orientar el eje:
# 03_generar_ideal_points.R y 03_puntos_ideales.py (derecha = positivo).
DERECHA <- c("MILEI, JAVIER GERARDO", "ESPERT, JOSE LUIS", "PIPARO, CAROLINA",
             "IGLESIAS, FERNANDO ADOLFO", "BORNORONI, GABRIEL", "LEMOINE, LILIA",
             "ALMIRON, LISANDRO", "MAYORAZ, NICOLAS")
IZQUIERDA <- c("KIRCHNER, MAXIMO CARLOS", "MOREAU, LEOPOLDO", "TAILHADE, RODOLFO",
               "YASKY, HUGO", "PALAZZO, SERGIO OMAR", "GROSSO, LEONARDO",
               "SANTORO, LEANDRO", "HELLER, CARLOS")

arreglar_comillas <- function(x) gsub('"{2,}', '"', x)
no_diputados <- c(",", "DIP, PENDIENTE DE INCORPORACION")

# -----------------------------------------------------------------------------
# 1. Carga de bases de datos
# -----------------------------------------------------------------------------
stopifnot("Falta sesiones_dt.csv.gz en esta carpeta" = file.exists("sesiones_dt.csv.gz"),
          "Falta legisladores_bloque_provincia.csv en esta carpeta" =
            file.exists("legisladores_bloque_provincia.csv"))

sesiones <- read.csv("sesiones_dt.csv.gz", encoding = "UTF-8") %>%
  mutate(legislador = arreglar_comillas(legislador)) %>%
  filter(!legislador %in% no_diputados,
         voto %in% c("AFIRMATIVO", "NEGATIVO", "AUSENTE", "ABSTENCION"))

legisladores_info <- read.csv("legisladores_bloque_provincia.csv", encoding = "UTF-8") %>%
  mutate(legislador = arreglar_comillas(legislador)) %>%
  distinct(legislador, yr, .keep_all = TRUE)   # PIPI 2025 venía dos veces (comillas distintas)

anotar("Votaciones: %d (%s a %s) | filas usadas: %d | diputados: %d",
       n_distinct(sesiones$id_votacion), min(sesiones$yr), max(sesiones$yr),
       nrow(sesiones), n_distinct(sesiones$legislador))
sin_info <- sesiones %>% distinct(legislador, yr) %>%
  anti_join(legisladores_info, by = c("legislador", "yr"))
anotar("Diputado-año sin bloque/provincia en legisladores_info: %d %s", nrow(sin_info),
       if (nrow(sin_info)) paste0("(", paste(head(unique(sin_info$legislador), 5), collapse = "; "), ")") else "")

# -----------------------------------------------------------------------------
# 2. Matriz de votos POR AÑO (filas = legislador; columnas = id_votacion)
#    Sí = 1, No = −1, ausente/abstención = 0. Sólo entran los diputados que
#    estuvieron ese año; si alguien entró o salió a mitad de año, las votaciones
#    en las que no estaba también quedan en 0.
# -----------------------------------------------------------------------------
matriz_anio <- function(a) {
  sesiones %>%
    filter(yr == a) %>%
    mutate(voto_num = case_when(voto == "AFIRMATIVO" ~ 1,
                                voto == "NEGATIVO"   ~ -1,
                                TRUE                 ~ 0)) %>%
    distinct(legislador, id_votacion, .keep_all = TRUE) %>%
    select(legislador, id_votacion, voto_num) %>%
    pivot_wider(names_from = id_votacion, values_from = voto_num, values_fill = 0) %>%
    column_to_rownames("legislador") %>%
    as.matrix()
}

# -----------------------------------------------------------------------------
# 3. Puntos ideales con PCA, año por año
# -----------------------------------------------------------------------------
reescalar <- function(x) (x - min(x)) / (max(x) - min(x)) * 2 - 1   # a [−1, 1]

anios <- sort(unique(sesiones$yr))
puntos <- map_dfr(anios, function(a) {
  m <- matriz_anio(a)
  m <- m[rowSums(abs(m)) > 0, , drop = FALSE]            # sin ningún Sí ni No: fuera
  m <- m[, apply(m, 2, sd) > 0, drop = FALSE]             # votaciones sin variación: fuera
  pca <- prcomp(m, scale. = TRUE)
  d1 <- reescalar(pca$x[, 1]); d2 <- reescalar(pca$x[, 2])
  # Orientación: la derecha de referencia tiene que quedar positiva
  der <- mean(d1[names(d1) %in% DERECHA]); izq <- mean(d1[names(d1) %in% IZQUIERDA])
  invertir <- if (!is.nan(der)) der < 0 else izq > 0
  if (isTRUE(invertir)) d1 <- -d1
  var_exp <- summary(pca)$importance[2, 1:2]
  anotar("%d: %d diputados x %d votaciones | PC1 explica %.0f%%, PC2 %.0f%% | eje %s",
         a, nrow(m), ncol(m), 100 * var_exp[1], 100 * var_exp[2],
         if (isTRUE(invertir)) "invertido" else "sin invertir")
  tibble(legislador = rownames(m), yr = a, dim1 = d1, dim2 = d2)
})

df_analisis <- puntos %>%
  left_join(legisladores_info, by = c("legislador", "yr")) %>%
  mutate(bloque = replace_na(bloque, "Sin dato"))

# Colores FIJOS por bloque en todos los gráficos y años: los N_BLOQUES bloques con más
# diputado-año tienen color propio; el resto va en gris como "Otros". Así un bloque
# tiene el mismo color en el gráfico de puntos y en todas las redes.
bloques_top <- df_analisis %>% count(bloque, sort = TRUE) %>% slice_head(n = N_BLOQUES) %>% pull(bloque)
paleta <- setNames(c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9",
                     "#D55E00", "#F0E442", "#000000")[seq_along(bloques_top)], bloques_top)
paleta <- c(paleta, Otros = "#BBBBBB")
agrupar_bloque <- function(b) factor(ifelse(b %in% bloques_top, b, "Otros"), levels = names(paleta))
df_analisis <- df_analisis %>% mutate(bloque_graf = agrupar_bloque(bloque))

write_csv(df_analisis %>% select(legislador, yr, dim1, dim2, bloque, provincia),
          "salidas/puntos_ideales_pca.csv")

# -----------------------------------------------------------------------------
# 4. Gráfico de puntos ideales (un panel por año)
# -----------------------------------------------------------------------------
g_puntos <- ggplot(df_analisis, aes(x = dim1, y = dim2, color = bloque_graf)) +
  geom_point(alpha = 0.8, size = 1.8) +
  facet_wrap(~ yr) +
  scale_color_manual(values = paleta, drop = FALSE) +
  theme_minimal() +
  labs(
    title = "Espacio político: puntos ideales de legisladores (PCA por año)",
    subtitle = "Dimensión 1 orientada: derecha positiva. Cada año tiene su propia escala.",
    x = "Dimensión 1 (punto ideal)",
    y = "Dimensión 2",
    color = "Bloque político"
  ) +
  theme(legend.position = "bottom")
print(g_puntos)
ggsave("salidas/puntos_ideales_por_anio.png", g_puntos, width = 11, height = 8, dpi = 150, bg = "white")

# -----------------------------------------------------------------------------
# 5. Red de afinidad y cohesión legislativa (una por año)
# -----------------------------------------------------------------------------
redes <- map(anios, function(a) {
  m <- matriz_anio(a)
  m <- m[apply(m, 1, sd) > 0, , drop = FALSE]             # sin variación: no se puede correlacionar
  matriz_cor <- cor(t(m))
  matriz_adj <- ifelse(matriz_cor > CORTE_COR, 1, 0)      # SIN "< 1": quedan los que votaron igual
  matriz_adj[is.na(matriz_adj)] <- 0
  net <- graph_from_adjacency_matrix(matriz_adj, mode = "undirected", diag = FALSE)

  meta <- tibble(legislador = V(net)$name, yr = a) %>%
    left_join(legisladores_info, by = c("legislador", "yr")) %>%
    mutate(bloque = replace_na(bloque, "Sin dato"))
  V(net)$bloque    <- meta$bloque
  V(net)$provincia <- meta$provincia
  V(net)$deg       <- degree(net)
  anotar("Red %d: %d nodos, %d aristas, %d aislados", a, vcount(net), ecount(net), sum(degree(net) == 0))
  net
})
names(redes) <- anios

grado <- map_dfr(anios, function(a) {
  net <- redes[[as.character(a)]]
  tibble(legislador = V(net)$name, yr = a, bloque = V(net)$bloque, grado = V(net)$deg)
})
write_csv(grado, "salidas/red_grado.csv")

# Visualización de la red con ggraph (semilla fija)
for (a in anios) {
  net <- redes[[as.character(a)]]
  V(net)$bloque_graf <- as.character(agrupar_bloque(V(net)$bloque))
  set.seed(2026)
  g_red <- ggraph(net, layout = "fr") +
    geom_edge_link(alpha = 0.05, color = "grey70") +
    geom_node_point(aes(color = bloque_graf, size = deg), alpha = 0.85) +
    scale_color_manual(values = paleta) +
    theme_void() +
    labs(
      title = paste("Red de afinidad en votaciones nominales ·", a),
      subtitle = sprintf("Unión si la correlación de votos es > %.2f", CORTE_COR),
      color = "Bloque político",
      size = "Grado de conexión"
    ) +
    theme(legend.position = "right", plot.title = element_text(face = "bold", size = 14))
  print(g_red)
  ggsave(sprintf("salidas/red_afinidad_%d.png", a), g_red, width = 10, height = 8, dpi = 150, bg = "white")
}

# -----------------------------------------------------------------------------
# 6. Controles finales
# -----------------------------------------------------------------------------
anotar("Puntos ideales: %d filas diputado-año | duplicados diputado-año: %d",
       nrow(puntos), sum(duplicated(puntos[, c("legislador", "yr")])))
anotar("Comillas: %s", paste(unique(grep("TOPO|PIPI", puntos$legislador, value = TRUE)), collapse = " | "))
writeLines(controles, "salidas/controles.txt", useBytes = TRUE)
cat("\nListo: revisá la carpeta salidas/\n")
