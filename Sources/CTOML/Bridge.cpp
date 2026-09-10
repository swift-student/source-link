#include "CTOML.h"
#include "vendor/toml.hpp"
#include <cstdlib>
#include <cstring>
#include <sstream>

namespace {
void quote(std::ostream &out, std::string_view value) {
    out << toml::json_formatter{toml::value<std::string>{value}};
}
void position(std::ostream &out, const toml::source_position &pos) {
    out << '[' << pos.line << ',' << pos.column << ']';
}
void visit(std::ostream &out, const toml::node &node, const std::string &path,
           const toml::source_region *key, bool &first) {
    if (!first) out << ',';
    first = false;
    out << "{\"path\":";
    quote(out, path);
    out << ",\"begin\":"; position(out, node.source().begin);
    out << ",\"end\":"; position(out, node.source().end);
    if (key) {
        out << ",\"keyBegin\":"; position(out, key->begin);
        out << ",\"keyEnd\":"; position(out, key->end);
    }
    out << ",\"kind\":";
    if (node.is_table()) quote(out, "table");
    else if (node.is_array()) quote(out, "array");
    else if (node.is_string()) {
        quote(out, "string"); out << ",\"string\":" << toml::json_formatter{node};
    } else if (node.is_integer()) {
        quote(out, "integer"); out << ",\"integer\":" << toml::json_formatter{node};
    } else if (node.is_boolean()) {
        quote(out, "boolean"); out << ",\"boolean\":" << toml::json_formatter{node};
    } else quote(out, "unsupported");
    out << '}';
    if (auto table = node.as_table()) {
        for (const auto &[childKey, child] : *table) {
            // JSON Pointer escaping keeps arbitrary TOML keys unambiguous.
            std::string escaped;
            for (char character : childKey.str()) {
                if (character == '~') escaped += "~0";
                else if (character == '/') escaped += "~1";
                else escaped += character;
            }
            visit(out, child, path + "/" + escaped, &childKey.source(), first);
        }
    } else if (auto array = node.as_array()) {
        for (size_t index = 0; index < array->size(); ++index)
            visit(out, (*array)[index], path + "/" + std::to_string(index), nullptr, first);
    }
}
}
char *sl_toml_parse(const char *text, size_t length) {
    std::ostringstream out;
    try {
        auto table = toml::parse(std::string_view{text, length});
        out << "{\"nodes\":[";
        bool first = true;
        visit(out, table, "", nullptr, first);
        out << "]}";
    } catch (const toml::parse_error &error) {
        out.str(""); out.clear();
        out << "{\"error\":"; quote(out, error.description());
        out << ",\"position\":"; position(out, error.source().begin); out << '}';
    } catch (const std::exception &error) {
        out.str(""); out.clear();
        out << "{\"error\":"; quote(out, error.what()); out << '}';
    }
    auto result = out.str();
    auto buffer = static_cast<char *>(std::malloc(result.size() + 1));
    if (buffer) std::memcpy(buffer, result.c_str(), result.size() + 1);
    return buffer;
}
void sl_toml_free(char *result) { std::free(result); }
