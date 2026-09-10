#ifndef SOURCE_LINK_CTOML_H
#define SOURCE_LINK_CTOML_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
// Caller owns the returned UTF-8 JSON string and releases it with sl_toml_free.
char *sl_toml_parse(const char *text, size_t length);
void sl_toml_free(char *result);
#ifdef __cplusplus
}
#endif
#endif
