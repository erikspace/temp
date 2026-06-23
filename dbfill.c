#include <mysql.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define ROWS 5000

static int rnd_int(int min, int max)
{
    return min + rand() % (max - min + 1);
}

static float rnd_float(float min, float max)
{
    return min + ((float)rand() / RAND_MAX) * (max - min);
}

static void make_desc(char *buf, size_t sz, int n)
{
    snprintf(buf, sz,
             "Description %d category %d",
             n,
             rnd_int(1, 20));
}

static void make_comment(char *buf, size_t sz, int n)
{
    snprintf(buf, sz,
             "Generated test row %d",
             n);
}

int main(void)
{
    MYSQL *conn;
    MYSQL_STMT *stmt;

    MYSQL_BIND bind[15];

    int kx;
    float rv;
    float pv;

    char desc1[256];
    char desc2[256];
    char comment[256];

    unsigned long desc1_len;
    unsigned long desc2_len;
    unsigned long comment_len;

    int i1, i2, i3, i4, i5, i6, i7, i8, i9;

    srand((unsigned int)time(NULL));

    conn = mysql_init(NULL);

    if (!mysql_real_connect(
            conn,
            "localhost",
            "user",
            "password",
            "database",
            0,
            NULL,
            0))
    {
        fprintf(stderr,
                "connect failed: %s\n",
                mysql_error(conn));
        return 1;
    }

    mysql_query(conn, "START TRANSACTION");

    stmt = mysql_stmt_init(conn);

    const char *sql =
        "INSERT INTO testable "
        "(kx, rv, pv, desc1, desc2, "
        "i1, i2, i3, i4, i5, i6, i7, i8, i9, comment) "
        "VALUES "
        "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    if (mysql_stmt_prepare(stmt, sql, strlen(sql)))
    {
        fprintf(stderr,
                "prepare failed: %s\n",
                mysql_stmt_error(stmt));
        return 1;
    }

    memset(bind, 0, sizeof(bind));

    bind[0].buffer_type = MYSQL_TYPE_LONG;
    bind[0].buffer = &kx;

    bind[1].buffer_type = MYSQL_TYPE_FLOAT;
    bind[1].buffer = &rv;

    bind[2].buffer_type = MYSQL_TYPE_FLOAT;
    bind[2].buffer = &pv;

    bind[3].buffer_type = MYSQL_TYPE_STRING;
    bind[3].buffer = desc1;
    bind[3].buffer_length = sizeof(desc1);
    bind[3].length = &desc1_len;

    bind[4].buffer_type = MYSQL_TYPE_STRING;
    bind[4].buffer = desc2;
    bind[4].buffer_length = sizeof(desc2);
    bind[4].length = &desc2_len;

    bind[5].buffer_type = MYSQL_TYPE_LONG;
    bind[5].buffer = &i1;

    bind[6].buffer_type = MYSQL_TYPE_LONG;
    bind[6].buffer = &i2;

    bind[7].buffer_type = MYSQL_TYPE_LONG;
    bind[7].buffer = &i3;

    bind[8].buffer_type = MYSQL_TYPE_LONG;
    bind[8].buffer = &i4;

    bind[9].buffer_type = MYSQL_TYPE_LONG;
    bind[9].buffer = &i5;

    bind[10].buffer_type = MYSQL_TYPE_LONG;
    bind[10].buffer = &i6;

    bind[11].buffer_type = MYSQL_TYPE_LONG;
    bind[11].buffer = &i7;

    bind[12].buffer_type = MYSQL_TYPE_LONG;
    bind[12].buffer = &i8;

    bind[13].buffer_type = MYSQL_TYPE_LONG;
    bind[13].buffer = &i9;

    bind[14].buffer_type = MYSQL_TYPE_STRING;
    bind[14].buffer = comment;
    bind[14].buffer_length = sizeof(comment);
    bind[14].length = &comment_len;

    if (mysql_stmt_bind_param(stmt, bind))
    {
        fprintf(stderr,
                "bind failed: %s\n",
                mysql_stmt_error(stmt));
        return 1;
    }

    for (int row = 1; row <= ROWS; row++)
    {
        kx = row;

        rv = rnd_float(0.0f, 1000.0f);
        pv = rnd_float(0.0f, 1000.0f);

        make_desc(desc1, sizeof(desc1), row);
        make_desc(desc2, sizeof(desc2), row + 100000);

        desc1_len = strlen(desc1);
        desc2_len = strlen(desc2);

        i1 = rnd_int(0, 1000);
        i2 = rnd_int(0, 1000);
        i3 = rnd_int(0, 1000);
        i4 = rnd_int(0, 1000);
        i5 = rnd_int(0, 1000);
        i6 = rnd_int(0, 1000);
        i7 = rnd_int(0, 1000);
        i8 = rnd_int(0, 1000);
        i9 = rnd_int(0, 1000);

        make_comment(comment, sizeof(comment), row);
        comment_len = strlen(comment);

        if (mysql_stmt_execute(stmt))
        {
            fprintf(stderr,
                    "insert failed row %d: %s\n",
                    row,
                    mysql_stmt_error(stmt));
            break;
        }
    }

    mysql_query(conn, "COMMIT");

    mysql_stmt_close(stmt);
    mysql_close(conn);

    return 0;
}
