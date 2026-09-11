# Diagram style guide

Use this as the default for new diagrams and requested visual redesigns. When only
refreshing source anchors, preserve the existing design instead.

## Choose the view before drawing

| Reader's question | View | Edges mean |
| --- | --- | --- |
| Where does a request go? | Architecture / flow | Routing, calls, or data movement |
| What happens first, especially across awaits? | Sequence or ordered flow | Time / execution order |
| Who stores what? | Ownership graph with typed cards | Ownership, retention, or ID association |
| What are the exact fields and inheritance relationships? | UML-style class diagram | Explicit structural relationships |

Do not force every question into a flowchart. For Swift actors and structs, a
simplified ownership graph is often clearer than exhaustive UML: distinguish
shared actor instances from stored value types and ID associations. A domain
container's name does not prove it stores its children; inspect the fields.

## Typography: three levels, not one bold paragraph

Use Markdown labels inside explicit rectangular cards:

1. `### TypeName` or a short action heading: larger and bold.
2. Optional `*Actor · authoritative state*`: regular-sized italic type/role subtitle.
3. Two to four short, regular-weight detail lines. Use inline code for important
   field names or signatures, not for entire prose paragraphs.

Left-align text through Markdown rendering. Separate the heading, subtitle, and
body with blank lines. Use Markdown hard breaks (two trailing spaces) within a
paragraph. Set `shape: rectangle` explicitly: a Markdown label alone may render
as text rather than a card. A base `style.font-size: 16` works well with D2's
Markdown heading hierarchy; verify the rendered size rather than assuming it.

Avoid centered, uniformly bold field dumps. Do not make every field name a heading.
Keep full signatures and exhaustive field lists in source code, reachable by link.
Prefer one readable sans-serif family plus inline monospace over decorative fonts.

## Color and reusable classes

Use restrained fills, dark readable text, rounded corners of 8, and thin borders.
Define shared card properties in D2 `classes` rather than repeating node styles.

| Role | Fill | Stroke |
| --- | --- | --- |
| Flow step / runtime actor | `#eaf2ff` | `#48658c` |
| Stored domain/state value | `#edf7f1` | `#537d65` |
| Stored collection / supporting storage | `#f5f5f7` | `#7c8491` |
| Race, failure, or explanatory note | `#fff5db` | `#b78b35` |

Use only categories relevant to the view. State what colors mean in a legend or
accompanying README; pair colors with type/role text so color is not the only cue.
A flow diagram may use only blue steps and yellow hazards. Do not imply blue means
"actor" in a diagram that also uses it for client or validation steps.

## Ownership and layout

- Solid arrows: owns / retains. Dashed arrows: shared reference or ID association.
  Label the relationship; these are simplified conventions, not strict UML notation.
- Show multiplicity where it helps (`1`, `0..*`, `1..*`). Never imply an ID owns
  the object it identifies, or that a struct is an independently shared instance.
- Prefer flat typed cards to enormous nested containers. Use nesting only when
  containment itself explains the structure without wasting most of the canvas.
- Keep ownership and execution order in separate diagrams. Label the ownership
  view explicitly so downward arrows are not mistaken for a request sequence.
- Start with one question and roughly 5–9 cards. Split runtime ownership from
  detailed domain storage if the overview requires unreadably small text.
- Keep edge labels short. Move long explanations into cards or the README.
  Watch for labels colliding with adjacent edges or source-link badges.
- Minimize crossing edges and long bypass arrows. An ID relationship can be
  explained in a card instead of drawing every possible association.

## Render-and-review checklist

Render editable D2 to SVG using `d2 --layout elk --pad 30`. Inspect a raster preview
or browser screenshot of the actual SVG; successful compilation is not visual review.

- Can the reader scan headings without reading the details?
- Are type/role subtitles and regular-weight descriptions clearly subordinate?
- Is body text readable at the intended browser size, not only at extreme zoom?
- Are source-link badges visible and clear of labels and adjacent cards?
- Are arrows, edge labels, and boundaries free of collisions?
- Is the canvas mostly useful content rather than empty nested containers?
- Are colors and arrow styles explained, with no dependence on color alone?
- Do the relationships still match the code after layout simplification?

Fix problems in D2, re-render, and inspect again. SVGs scale, but that is not an
excuse for an unreadable overview. Never modify generated SVG geometry by hand.
Open the SVG as a document for clickable use; Markdown images and HTML `<img>`
embeddings disable links.

## Working example

[Ownership cards](examples/ownership-cards.d2) and its
[rendered SVG](examples/ownership-cards.svg) demonstrate heading/subtitle/body
hierarchy, code identifiers, semantic colors, and stored-value containment.
See [the example README](examples/README.md) for mapping and rendering details.
