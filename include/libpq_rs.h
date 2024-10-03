#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <ostream>
#include <new>

extern "C" {

const void *conn(const int8_t *url);

int64_t execute(const void *c, const int8_t *sql);

const int8_t *copyout(const void *c, const int8_t *copyout_sql);

void free_str(const int8_t *s);

void disconnect(void *c);

}  // extern "C"
