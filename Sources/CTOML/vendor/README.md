# toml++

`toml.hpp` is the unmodified toml++ 3.4.0 amalgamated header, licensed under MIT
(the full license is included at the top of the file).

Upstream: https://github.com/marzer/tomlplusplus/tree/v3.4.0
Source: TOMLKit 0.6.0, commit ec6198d37d495efc6acd4dffbd262cdca7ff9b3f,
`Sources/CTOML/Sources/toml.hpp` (the upstream header, not the TOMLKit wrapper).

The parser implements TOML 1.0. Vendoring it keeps both SwiftPM/Xcode and the
standalone direct build self-contained. `Bridge.cpp` exposes only parsed scalar
values and Unicode source locations over a C ABI; it does not serialize edited
configuration documents.
