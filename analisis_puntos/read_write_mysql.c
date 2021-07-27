/*
* $Id$
* Description:
*
*
* Author: Raquel Lorente Plazas <raquel@meteored.com> 03/2021
*         Marcos Molina Cano <marcos@meteored.com>
 *         Juan Sanchez <raquel@meteored.com>
 *         Laura Palacios Peña <laura@meteored.com>
*        Guillermo Ballester Valor <gbv@oxixares.com>
*
*
*/
/*!
  \file ecmwf_plocales.c
  \brief Asocia coordenadas de tabla puntos de plocales a la posición del grid
*/

/* Compilación y ejecución
 * icc -DHAVE_CONFIG_H -I. -I../..  -I../../src/plocgfs -I../../src_ecmwf/tools -I/usr/include/mysql     -O2 -xHOST -Wall -g  -MT read_write_mysql.o -MD -MP -MF .deps/ecmwf_plocales.Tpo -c -o read_write_mysql.o  read_write_mysql.c
 *
 * icc -O2 -xHOST -Wall -g -o read_write_mysql  read_write_mysql.o ecmwf_plocales_io.o  ../../src/plocgfs/.libs/libprediloc.so -lcartograf -lgramet -lm -lmysqlclient ../../src_ecmwf/tools/.libs/libcep.so
 *
 * ./read_write_mysql -i /home/cep/ecmwf/BP_2021030300/ECMWF_2021030300_003 -g /home/cep/ecmwf_ens/BP_2021030300/ECMWF_EST_2021030300_003 -d 2021030300 -p 003 -q
*/



#include "ecmwf_plocales.h"


//#define DEBUG
#define NEWT_ALG
//#define NO_CORREC


/* Variables globales */
struct mrloc LOCQ[NLOC]; /*!< Array donde se almacenan los datos de las estaciones */
struct map_point POINTS[NLOC]; /*!< Array donde se almacenan los datos de lat y lon en formato real */
size_t SRT[NLOC]; /*!< Array donde se colocan el orden para leer datos de los grid */
size_t SRT2[NLOC]; /*!< Array donde se colocan el orden para leer datos de los grid */
struct grd_def GRID; /*!< Definición de las características del grid del modelo */
struct grd_def GRIDG; /*!< Definición de las características del grid del fichero de perfiles generico */
char DATE[32]; /*!< Cadena donde se coloca la fecha */
time_t TREF; /*!< Instante unix de la proyeccion, tomado de referencia */
char PROY[16]; /*!< Cadena donde se coloca la proyección */
char GRDFILEP[256]; /*!< Path del fichero con el Grid de profiles_ecmwf */
char GRDFILEG[256]; /*!< Path del fichero con el Grid de ecmwf_profile_gen */
char LOCFILE[256]; /*!< Path del fichero con el listado de localidades */
char PAISES[256]; /*!< Nombre del fichero con la lista de paises prioritarios para ese dominio */
char EXCLUIDOS[PLOCALES_NPAISES][128]; /*!< Array de cadenas con los nombres de los paises prioritarios de un dominio */
char SALIDA[256]; /*!< Nombre del fichero de salida modo txt */
char SALIDAQ[256]; /*!< Nombre del fichero de salida modo sql*/
char FICH_DSC[256]; /*!< Fichero descriptor del grid gds, para modelos locales */
char PREDIC[NLOC][512]; /*!< Array de cadenas donde se guardan las predicciones de cada localidad */
double LATS[NLOC]; /*!< Array con las latitudes auxiliares de los puntos */
double LONS[NLOC]; /*!< Array con las longitides auxiliares de los puntos */
double PREC[NLOC], CPREC[NLOC];
int ALTS[NLOC]; /*!< Array con altitudes auxiliares */
int ZONAH[NLOC]; /*!< Array con zonas horarias auxiliares */
int COD_PGEO[NLOC]; /*!< Array con el indice cod_pgeo al que pertenece cada estacion */
struct gridprofile_ecmwf SONDEOS[NLOC]; /*!< EL gran array de estructuras \ref gridprofile_ecmwf */
struct gridprofile_adds ADDS[NLOC]; /*!< EL gran array de estructuras \ref gridprofile_adds */
struct ecmwf_profile_gen PROFG[NLOC]; /*!< El gran array de estructuras \ref ecmwf_profile_gen */
int NOLOCDATA; /*!< Indica si se ponen los metadatos al inicio del fichero de texto */
int NOTOUCH; /*!< Indica si se no se modifica la BD, aunque se genere el fichero SQL */
int NOSQL; /*!< Indica que hay que introducir los datos generados a la tabla */
int NOTXT; /*!< Indica si hay que sacar el fichero en formato txt. Si != 0 entonces no hay fichero txt */
int DH; /*!< Intervalo básico de horas entre predicciones, por defecto 3 */
int TESTMODE; /*!< Si != 0 indica que los datos se introducen en la tabla de pruebas 'predicciones_prueba' */
char MODELO[16]; /*!< nombre del modelo */
int NPAISES; /*!< número de paises en la lista de prioritarios del dominio */
MYSQL mys;



int main ( int argc, char *argv[] )
{
    FILE *fwrite, *fwrite2, *fp;
    MYSQL *conn; /* variable de conexión para MySQL */
    MYSQL_RES *res; /* variable que contendra el resultado de la consuta */
    MYSQL_ROW row; /* variable que contendra los campos por cada registro consultado */
    char *server = "localhost"; /*direccion del servidor 127.0.0.1, localhost o direccion ip */
    char *user = "ogimet"; /*usuario para consultar la base de datos */
    char *password = NULL; /* contraseña para el usuario en cuestion */
    char *database = "plocales"; /*nombre de la base de datos a consultar */
    int last_pgeo;
    size_t codini, codfin;
    size_t i, j, nlv, pos;
    int fila, columna;


    conn = mysql_init(NULL); /*inicializacion a nula la conexión */


    fwrite = fopen("./write_mysql.txt", "w+");
    fwrite2 = fopen("./localidades_por_celdas.txt", "w+");

    // lee argumentos
    lee_argumentos ( argc, argv );

    if ( ( fp = fopen ( GRDFILEP, "r" ) ) == NULL )
    {
        printf ( "ecmwf_plocales: No se puede abrir el fichero de gridprofiles %s\n", GRDFILEP );
        exit ( EXIT_FAILURE );
    }

    /* conectar a la base de datos */
    if (!mysql_real_connect(conn, server, user, password, database, 0, NULL, 0))
    { /* definir los parámetros de la conexión antes establecidos */
        fprintf(stderr, "%s\n", mysql_error(conn)); /* si hay un error definir cual fue dicho error */
        exit(1);
    }

    // Primero vemos el numero de estaciones que hay
    if ( ( last_pgeo = get_last_cod_pgeo() ) <= 0 )
    {
        // no sabemos cuál es el cod_pgeo mayor
        printf ( "plocales_sql: No podemos saber el cod_pgeo más alto disponible\n" );
        exit ( EXIT_FAILURE );
    }

    /******* GRAN BUCLE, CADA iteracion se leen hasta PLOCALES_BLOCK estaciones *******/
    codini = 1;

    while ( codini <= ( size_t ) last_pgeo ) {
        codfin = codini + PLOCALES_BLOCK - 1; // cod_pgeo ultimo a buscar
        //codfin = ( size_t ) last_pgeo -1;
        printf("limite loop %zu codini %zu\n",nlv, codini);

        // lee las localidades
        if ( ( nlv = read_locali_interval_sql ( LOCQ, POINTS, ZONAH, COD_PGEO, NLOC, codini, codfin ) ) == 0 )
        {

#ifdef FILTER_ID_TIEMPO
            // puede suceder que no haya ningun dato
          goto fin_while;
#else
            // no hay base de datos disponible
            printf ( "plocales_sql: Opción sin base de datos de localidades no disponible\n" );
            exit ( EXIT_FAILURE );
#endif
        }
        // ordena los indices para leer
        // SRT contiene el indice de los puntos segun el orden en que hay que leerlos
        // SRT[0] es el indice del primer punto a leer, SRT[1] el segundo ....

        // Suponemos que el orden adecuado para GRID tambien lo es para GRIDG ya que tiene menor resolución
        sort_points_for_grid_access ( &SRT[0], &POINTS[0], nlv, &GRID );

        //fprintf(fwrite2,"POS\tSRT\tLAT\tLON\tNombre\tfila\tcolumna\n");
        for ( j = 0; j < nlv ; j++ )
        {
            i = SRT[j];
            LATS[j] = POINTS[i].lat * GRA2RAD;
            LONS[j] = POINTS[i].lon * GRA2RAD;
            ALTS[j] = LOCQ[i].alt;

            fila = grd_get_row ( LATS[j], &GRID );
            columna = grd_get_col ( LONS[j], &GRID );
            pos = grd_position_data_float(0, fila, columna, &GRID);
            fprintf(fwrite2,"%zu\t%zu\t%f\t%f\t%i\t%i\t%s\t%s \n", pos, i, POINTS[i].lat, POINTS[i].lon, fila, columna,  LOCQ[i].nombre, LOCQ[i].pais);
            //fprintf(fwrite2, "%zu \n", pos);
        }
        codini = codfin + 1;
    } // end while


    /* enviar consulta SQL */
    if (mysql_query(conn, "SELECT cod_pgeo,latitud,longitud from puntos where cod_pgeo >= 1 and cod_pgeo <= 100 order by cod_pgeo asc"))
    { /* definicion de la consulta y el origen de la conexion */
        fprintf(stderr, "%s\n", mysql_error(conn));
        exit(1);
    }

    res = mysql_use_result(conn);
    fprintf(fwrite,"ID\tlatitud\t\tlongitud\n");
    /* while ((row = mysql_fetch_row(res)) != NULL)  recorrer la variable res con todos los registros obtenidos para su uso */
    /*    printf("%s\t%s\t%s \n", row[0],row[1],row[2]); la variable row se convierte en un arreglo por el numero de campos que hay en la tabla */

    /* se libera la variable res y se cierra la conexión */
    while ((row = mysql_fetch_row(res)) != NULL) /* recorrer la variable res con todos los registros obtenidos para su uso */
       fprintf(fwrite,"%s\t%s\t%s \n", row[0],row[1],row[2]);

    mysql_free_result(res);
    mysql_close(conn);

    /*fprintf(fwrite,"%s\n", mysql_get_client_info());*/

    fclose(fwrite);
    fclose(fwrite2);

    return 0;
}

/*icc -DHAVE_CONFIG_H -I. -I../..  -I../../src/plocgfs -I../../src_ecmwf/tools -I/usr/include/mysql     -O2 -xHOST -Wall -g  -MT read_write_mysql.o -MD -MP -MF .deps/ecmwf_plocales.Tpo -c -o read_write_mysql.o  read_write_mysql.c
icc  -O2 -xHOST -Wall -g -o  read_write_mysql  read_write_mysql.o ecmwf_plocales_io.o ../../src/plocgfs/libprediloc.la -lcartograf -lgramet -lm -lmysqlclient ../../src_ecmwf/tools/libcep.la
icc -O2 -xHOST -Wall -g -o read_write_mysql  read_write_mysql.o ecmwf_plocales_io.o  ../../src/plocgfs/.libs/libprediloc.so -lcartograf -lgramet -lm -lmysqlclient ../../src_ecmwf/tools/.libs/libcep.so */