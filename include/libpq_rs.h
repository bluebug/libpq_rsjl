#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <ostream>
#include <new>

/// string for csv ffi
struct CsvString {
  const int8_t *ptr;
  uint32_t len;
  const int8_t *error;
};

extern "C" {

const void *conn(const int8_t *url);

int64_t execute(const void *c, const int8_t *sql);

CsvString copyout(const void *c, const int8_t *copyout_sql);

void free_csvstring(CsvString s);

void disconnect(void *c);

}  // extern "C"
