#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

struct Copyout {
  /**
   * csv string or error message
   */
  const int8_t *body;
  /**
   * length of body without \0
   */
  uint32_t len;
  /**
   * 0 means success and body is csv string, >0 means failed and body is error message
   */
  uint32_t err;
};

const void *pq_conn(const int8_t *url);

/**
 * Executes a statement, returning the number of rows modified.
 *
 * Returns -1 if client is null
 * Returns -2 if execute failed
 * Returns -3 if invalid sql
 */
int64_t pq_execute(const void *c, const int8_t *sql);

/**
 * copy out query result to csv string
 */
struct Copyout pq_copyout_native(const void *c, const int8_t *sql, char delim, uint8_t header);

void pq_show_copyout(struct Copyout s);

void pq_free_copyout(struct Copyout s);

void pq_disconn(void *c);
