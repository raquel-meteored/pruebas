#include <stdio.h>
#include <stdlib.h>
#include <mysql/mysql.h>

int main() {
    FILE *fwrite;
    MYSQL *conn; /* variable de conexión para MySQL */
    MYSQL_RES *res; /* variable que contendra el resultado de la consuta */
    MYSQL_ROW row; /* variable que contendra los campos por cada registro consultado */
    char *server = "localhost"; /*direccion del servidor 127.0.0.1, localhost o direccion ip */
    char *user = "ogimet"; /*usuario para consultar la base de datos */
    char *password = NULL; /* contraseña para el usuario en cuestion */
    char *database = "plocales"; /*nombre de la base de datos a consultar */
    conn = mysql_init(NULL); /*inicializacion a nula la conexión */

    fwrite = fopen("./write_mysql.txt", "w+");

    /* conectar a la base de datos */
    if (!mysql_real_connect(conn, server, user, password, database, 0, NULL, 0))
    { /* definir los parámetros de la conexión antes establecidos */
        fprintf(stderr, "%s\n", mysql_error(conn)); /* si hay un error definir cual fue dicho error */
        exit(1);
    }

    /* enviar consulta SQL */
    if (mysql_query(conn, "SELECT cod_pgeo,latitud,longitud from puntos where cod_pgeo >= 1 and cod_pgeo <= 100 order by cod_pgeo asc"))
    { /* definicion de la consulta y el origen de la conexion */
        fprintf(stderr, "%s\n", mysql_error(conn));
        exit(1);
    }

    res = mysql_use_result(conn);
    fprintf(fwrite,"ID\tlatitud\t\tlongitud\n");
    /* while ((row = mysql_fetch_row(res)) != NULL)  recorrer la variable res con todos los registros obtenidos para su uso */
    /*    printf("%s\t%s\t%s \n", row[0],row[1],row[2]); /* la variable row se convierte en un arreglo por el numero de campos que hay en la tabla */

    /* se libera la variable res y se cierra la conexión */
    while ((row = mysql_fetch_row(res)) != NULL) /* recorrer la variable res con todos los registros obtenidos para su uso */
       fprintf(fwrite,"%s\t%s\t%s \n", row[0],row[1],row[2]);

    mysql_free_result(res);
    mysql_close(conn);

    /*fprintf(fwrite,"%s\n", mysql_get_client_info());*/

    fclose(fwrite);

    return 0;
}
