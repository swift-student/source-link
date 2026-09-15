# Source Link explainer

Plain HTML and CSS, with D2 SVGs embedded inline so their links stay active.
No JavaScript, npm packages, or static-site framework are required.

Build with `python3 site/build.py`, then serve `.build/site` with any static HTTP server.
Edit `site/index.html` and `site/style.css`. Diagram sources and rendered SVGs live in
`examples/diagrams`; run `examples/diagrams/render.sh` after editing D2, then rebuild.
The build copies downloadable D2/SVG assets and expands the template's diagram markers.

The `Publish explainer` workflow publishes `.build/site` on changes merged to main.
In repository Settings → Pages, select **GitHub Actions** as the source before the
first deployment. The expected project URL is https://swiftstudent.com/source-link/.
Relative asset URLs support the project subpath and local previews.

Examples use the `source-link` repository alias, mapped to the reader's checkout.
The stack shows the synchronous command-preparation path; the flow summarizes a
successful, unique Swift symbol lookup. Source was inspected at main `6f2e94b`.
