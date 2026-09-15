# Linked D2 examples

Open the SVG files directly in a browser that allows external URL schemes. Click a node's link badge to open its implementation in Source Link. An SVG displayed as an image (including many Markdown previews) loses link interactivity.

| Diagram | What it demonstrates |
| --- | --- |
| [Call stack](stack-trace.svg) · [PNG](stack-trace.png) · [D2](stack-trace.d2) | Compact IDE-style stack with Swift symbol links. |
| [Source Link](source-link.svg) · [D2](source-link.d2) | Seven linked nodes, checkout setup branch, URL-to-editor flow. |
| [Click dispatch](click-dispatch.svg) · [D2](click-dispatch.d2) | Thirteen linked nodes, two containers, single versus chained subcommands, shared result handling. |
| [Click parameters](click-parameters.svg) · [D2](click-parameters.d2) | Seven linked nodes in a separate detail view used by context creation. |

## Source mappings

Configure these repository names in Source Link:

- `source-link`: this repository's root.
- `click`: a checkout of [pallets/click](https://github.com/pallets/click), version **8.1.8**, commit `934813e4d421071a1b3db3973c02fe2721359a6e`.

The prototype downloaded Click into `.build/diagram-sources/click` under this repository. That ignored directory is a local convenience; it is not included with these example files. To obtain the same revision elsewhere:

```sh
git clone --depth 1 --branch 8.1.8 https://github.com/pallets/click.git
```

The SVG links contain repository aliases and relative paths only. They do not pin a revision; the selected local checkout determines which code opens.

## Scope and interpretation

Source Link shows the successful modern `source-link:` path. It omits cancellation and error alerts. Resolution is performed inside `SourceSettings.command(for:)`; the separate resolution node expands that operation conceptually. First-link setup also validates the chosen file before saving.

Click dispatch shows `Group`/`MultiCommand` with subcommands present. It omits completion, help, error handling, and `invoke_without_command`. In chain mode, resolution and context creation repeat together until all child contexts have been collected, then invocation runs in order. The result callback receives a scalar in single-command mode or a list in chain mode. `main` returns the result in non-standalone mode or exits in standalone mode.

The parameter diagram expands `make_context` → `Command.parse_args`. Tokenization runs once; consumption, conversion, validation, callbacks, and storage repeat per parameter. `Option.consume_value` additionally handles prompts; this detail view links to the base `Parameter` implementation. Arrows express conceptual processing order, not an exhaustive call graph.

## Render again

Requires D2 **0.9.0** ([official installation instructions](https://d2lang.com/tour/install/)).

```sh
bash examples/diagrams/render.sh
# Or use an explicit executable:
D2=/path/to/d2 bash examples/diagrams/render.sh
```

The script selects ELK and tighter layer spacing. It preserves the authored D2 structure and regenerates all four SVGs. It does **not** refresh source line numbers.

`source-map.json` records the source anchors and line numbers used for this snapshot. Swift anchors use unique declaration text; Click anchors use class-qualified method names. A future refresh tool can resolve these anchors, fail on missing or ambiguous declarations, update only links, and then invoke the renderer. The map is currently a review aid, not an implemented refresh system.

## Review performed

- Rendered all diagrams and inspected offline SVG thumbnails.
- Compared ELK and Dagre for Click dispatch; selected ELK for its compact parallel columns and orthogonal edges.
- Fixed arrows crossing container headings by shortening headings and placing them at the upper left.
- Checked final labels, link badges, arrow routing, and clipping.
- Extracted the generated SVG links and validated them against local files and declaration lines using the actual Swift `SourceLink` parser and resolver.

The browser tool blocked local-file navigation, so browser-to-editor clicking remains a manual check. Offline image inspection does not prove external URL handoff. Open an SVG in your browser and click a badge after configuring the mappings above.

The required `make check` passed on an isolated PR checkout based on `545ea4d` (Swift Testing, strict SwiftLint, and the Xcode build). No application or package files are changed for these examples.

## Call stack example

The call stack models a pause inside `SourceLink.resolve(root:)`, called synchronously
by `SourceSettings.command(for:symbol:)`, called by `AppDelegate.open(_:settings:symbol:)`.
Frame 0 is at the top. Task closures and framework frames are omitted. It is illustrative,
not a captured debugger stack. The implementation was inspected at main `6f2e94b`.

Each row links to its declaration using a URL-encoded symbol. Shared row styling lives
in the `frame` class. Regenerate the SVG with `d2 --pad 24 stack-trace.d2 stack-trace.svg`
from this directory. The PNG is a static raster preview of that SVG.
