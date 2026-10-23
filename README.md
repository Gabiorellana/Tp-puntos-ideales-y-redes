# Puntos ideales y redes de afinidad en la Cámara de Diputados (2022–2026)

**Integrantes:** Gabriela Orellana, Cecilia Orellana, Franco Garcia

\---

## Qué hicimos

Usamos las dos herramientas de las clases 2 y 3 para mirar cómo vota la Cámara:

1. **Puntos ideales.** Ubicamos a cada diputado en un eje, año por año, según cómo votó. Usamos el "atajo PCA" visto en la clase 2: la primera componente principal de la matriz de votos.
2. **Redes de afinidad.** Unimos a dos diputados si sus votos de ese año se parecen (correlación mayor a 0,60) y medimos cuántas conexiones tiene cada uno (grado).

Con esos resultados buscamos patrones, alianzas y distanciamientos entre diputados y bloques.

## Datos

|Archivo|De dónde sale|Qué tiene|
|-|-|-|
|`sesiones\\\\\\\_dt.csv.gz`|`clase\\\\\\\_02\\\\\\\_puntos\\\\\\\_ideales.zip` → `2\\\\\\\_datos/`|Un voto por fila: 537 votaciones nominales del 11/03/2022 al 09/09/2026|
|`legisladores\\\\\\\_bloque\\\\\\\_provincia.csv`|`redes\\\\\\\_clase3.zip` → `datos/`|Bloque y provincia de cada diputado, por año|

## Método

**Puntos ideales (PCA por año)**:

* Sí = 1, No = −1, ausente o abstención = 0.
* Se estandariza cada votación y se dejan afuera las votaciones sin variación (unánimes).
* La primera componente principal es el punto ideal y se lleva a la escala \[−1, 1].
* La derecha queda positiva.

**Redes de afinidad.** Para cada año:

* se calcula la correlación entre los votos de cada par de diputados;
* se los une si la correlación es mayor a 0,60;
* se calcula el grado de cada diputado (cuántas conexiones tiene).

El dibujo usa el layout Fruchterman-Reingold con semilla fija, para que salga igual en cada corrida.

**Limpieza de nombres.** Hay diputados cuyo apodo va entre comillas, por ejemplo `RODRIGUEZ, ALEJANDRO "TOPO"` y `ALI, ERNESTO "PIPI"`. En los archivos aparecen con 2, 4 u 8 comillas, porque las comillas se duplican cada vez que el archivo se lee y se vuelve a guardar. Se dejó una sola comilla para que la misma persona no cuente como dos. También se sacaron dos filas que no son diputados: un nombre vacío y "DIP, PENDIENTE DE INCORPORACION".

## Resultados (`salidas/`)

|Archivo|Qué muestra|
|-|-|
|`puntos\\\\\\\_ideales\\\\\\\_por\\\\\\\_anio.png`|Puntos ideales de cada diputado, un panel por año, coloreados por bloque|
|`red\\\\\\\_afinidad\\\\\\\_AAAA.png`|Red de afinidad de cada año: el tamaño del punto indica el grado|
|`puntos\\\\\\\_ideales\\\\\\\_pca.csv`|Diputado × año: `dim1` (punto ideal), `dim2`, bloque, provincia|
|`red\\\\\\\_grado.csv`|Diputado × año: grado en la red|
|`controles.txt`|Conteos y verificaciones de la corrida|

Controles de la corrida:

* 537 votaciones y 498 diputados.
* Ningún diputado se pierde al cruzar con bloque y provincia.
* 1.416 filas diputado-año, sin duplicados.
* 258 diputados en 2026.

## Qué encontramos

> Los números salen de `puntos\\\\\\\_ideales\\\\\\\_pca.csv` y `red\\\\\\\_grado.csv`.

**Patrones**

* Todos los años el eje separa al bloque peronista (Frente de Todos, luego Unión por la Patria) de PRO, UCR y La Libertad Avanza. El bloque peronista tiene un punto ideal promedio de entre −0,67 y −0,92.
* Desde 2024, La Libertad Avanza ocupa el extremo derecho: promedio 0,90 en 2024 y 0,98 en 2026.

**Alianzas**

* En 2024 y 2026, PRO queda pegado a La Libertad Avanza: promedios de 0,73 contra 0,90 en 2024, y de 0,90 contra 0,98 en 2026.
* En 2026, la UCR también se ubica junto a ellos, con un promedio de 0,91.

**Distanciamientos**

* La UCR se mueve: estaba en una posición intermedia en 2025 (promedio 0,05) y queda junto a La Libertad Avanza en 2026 (0,91).
* Coalición Cívica cruza al lado negativo del eje: pasa de 0,70 en 2023 a −0,19 en 2024 y −0,43 en 2025.
* Provincias Unidas (2025–2026) queda en el centro (cerca de −0,2) y con mucha dispersión (desvío 0,39). Parece un bloque que no vota en conjunto.

**Hallazgos**

* 2025 aparece mucho más disperso que los demás años: el desvío de La Libertad Avanza pasa de 0,09–0,15 a 0,39. En el gráfico se ven dos líneas paralelas. Una hipótesis a verificar es que 2025 mezcla dos composiciones de la Cámara (antes y después del recambio del 10/12/2025): 375 diputados en un solo año.

## 

