# NA

## Plan: Clickable Workflow Diagrams for Landing Pages

**Status:** Both diagrams are implemented and deployed. The Quarto
flexbox pipeline diagram lives on `docs-site/index.qmd` and now wraps
the post-implementation landing-page rewrite (cross-links to QUANT use
absolute `https://slinghub.github.io/MRMhub/quant/` URLs). The QUANT
pkgdown SVG lives on `quant/pkgdown/index.md` and is reused unchanged by
the QUANT-only landing rewrite.

**TL;DR** — Add interactive, branded workflow diagrams to both
documentation landing pages. **Part 1 (INTEGRATOR):** HTML/CSS flexbox
diagram on the Quarto site — a single horizontal row of 5 clickable
boxes ending with “Post Processing (QUANT)” that links to the pkgdown
site. **Part 2 (QUANT):** Inline SVG on the pkgdown landing page — 4
clickable steps covering the R package workflow. Use the logo’s color
palette (steel blue `#5B8FA8`, warm orange `#D4914E`, muted green
`#6B9E5E`, dusty rose `#C27171`, dark navy text `#2C3E50`) at reduced
opacity for fills so the diagrams feel cohesive but not distracting.

------------------------------------------------------------------------

## Brand Colors (extracted from logo)

| Name        | Hex       | Usage                                      |
|-------------|-----------|--------------------------------------------|
| Steel Blue  | `#5B8FA8` | Import / quant steps / Post Processing box |
| Warm Orange | `#D4914E` | INTEGRATOR processing steps                |
| Muted Green | `#6B9E5E` | QC / validation / output steps             |
| Dusty Rose  | `#C27171` | Reporting / export steps                   |
| Navy        | `#2C3E50` | Text, borders, arrows                      |
| Light Gray  | `#F5F6F7` | Background of diagram container            |

Use fills at ~15–30% opacity for boxes, full-color for borders/icons,
navy for text and arrows.

------------------------------------------------------------------------

## Part 1: INTEGRATOR Landing Page — HTML/CSS Workflow Diagram

**Target file:** Future `docs-site/index.qmd` (Quarto website)\
**Approach:** Pure HTML/CSS flexbox — single horizontal row of 5
clickable boxes.

### Design

A single-row pipeline showing the INTEGRATOR workflow. The 5th box links
out to the QUANT pkgdown site:

    ┌────────────┐    ┌────────────┐    ┌────────────────┐    ┌──────────────┐    ┌──────────────────────┐
    │ Raw Data   │ →  │ msconvert  │ →  │  INTEGRATOR    │ →  │  long.csv    │ →  │ Post Processing      │
    │ (.raw/.d)  │    │ → mzML     │    │  (integrate)   │    │  output      │    │ (QUANT) →            │
    │ (navy)     │    │ (orange)   │    │ (orange)       │    │ (green)      │    │ (blue, links Part 2) │
    └────────────┘    └────────────┘    └────────────────┘    └──────────────┘    └──────────────────────┘
         ↓ link            ↓ link              ↓ link               ↓ link               ↓ link
      #raw-data       msconvert.qmd      running.qmd         output.qmd          → pkgdown site URL

### Implementation Steps

1.  **Create `docs-site/` directory structure** for the Quarto website:

    - `docs-site/_quarto.yml` — site config with brand colors as CSS
      variables
    - `docs-site/index.qmd` — landing page with workflow HTML block
    - `docs-site/styles.css` — defines `.workflow-container`,
      `.workflow-step`, `.workflow-arrow`

2.  **HTML/CSS component in `index.qmd`** — Raw HTML block using:

    - Flexbox single-row layout with `gap` for arrows (CSS `::after`
      pseudo-elements for `→`)
    - Each `.workflow-step` is an `<a>` tag with:
      - `background-color` from brand palette at 15–20% opacity
      - `border-left: 4px solid {brand-color}`
      - `border-radius: 8px`
      - Hover: subtle lift (`transform: translateY(-2px)`) + shadow
    - 5th box (“Post Processing (QUANT)”) uses steel blue `#5B8FA8`,
      links to the pkgdown site URL
    - Responsive: wraps to vertical on mobile via `flex-wrap`

3.  **CSS variables in `styles.css`**:

    ``` css
    :root {
      --mrm-blue: #5B8FA8;
      --mrm-orange: #D4914E;
      --mrm-green: #6B9E5E;
      --mrm-rose: #C27171;
      --mrm-navy: #2C3E50;
      --mrm-bg: #F5F6F7;
    }
    ```

4.  **Add “Which tool do I need?” routing below the diagram** — short
    bullets linking to relevant INTEGRATOR guide pages.

------------------------------------------------------------------------

## Part 2: QUANT R Package Landing Page — SVG Workflow Diagram

**Target file:**
[`quant/pkgdown/index.md`](https://slinghub.github.io/MRMhub/quant/quant/pkgdown/index.md)
(replace current image-map placeholder)\
**Asset:** `quant/man/figures/workflow-overview.svg`

### Design

A horizontal 4-step pipeline showing the QUANT R package workflow:

    ┌─────────────┐    ┌─────────────────┐    ┌──────────────┐    ┌──────────────┐
    │  📥 Import  │ →  │ ⚙️ Process &    │ →  │ ✓ Quality    │ →  │ 📊 Report &  │
    │    Data     │    │    Correct      │    │   Control    │    │    Export    │
    │  (blue)     │    │  (orange)       │    │  (green)     │    │  (rose)     │
    └─────────────┘    └─────────────────┘    └──────────────┘    └──────────────┘
         ↓ link              ↓ link                ↓ link               ↓ link
     04_dataimport    07_driftbatchcorr      02_QualityControl      R01_quantms

### Implementation Steps

1.  **Create `quant/man/figures/workflow-overview.svg`** — Hand-coded
    SVG with:

    - Rounded rectangles with branded fill colors (20–30% opacity)
    - Arrow connectors between steps (navy `#2C3E50`)
    - Embedded `<a xlink:href="...">` links wrapping each box for
      clickability
    - Brief label + small descriptive subtitle in each box
    - Responsive: `viewBox` based, no fixed pixel width
    - Accessible: `<title>` and `aria-label` on each link

2.  **Update `quant/pkgdown/index.md`** — Replace the current `<img>` +
    `<map>` block with inline SVG so links work. Remove the dead
    `workflow-map` image map.

3.  **Add hover effect via CSS** — Create/update
    `quant/pkgdown/extra.css`:

    - `.workflow-step:hover { opacity: 0.85; filter: brightness(1.05); }`
    - Register in `_pkgdown.yml` under `template: css`

------------------------------------------------------------------------

## Verification

- **Part 1:** Run `quarto preview docs-site/` → confirm HTML/CSS diagram
  renders with 5 boxes, last box links to pkgdown site, hover effects
  smooth, responsive on narrow viewport
- **Part 2:** Run
  [`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
  → confirm SVG renders with working links on the home page; test hover;
  check mobile layout
- **Accessibility:** All links have descriptive text; color is not the
  only differentiator (borders + labels)

------------------------------------------------------------------------

## Decisions

| Decision | Rationale |
|----|----|
| HTML/CSS for INTEGRATOR (Part 1), SVG for QUANT (Part 2) | HTML/CSS is more maintainable in Quarto; SVG works well as a static asset in pkgdown |
| Single row (not two rows) for INTEGRATOR | Simpler mental model — one linear pipeline with a handoff to QUANT at the end |
| 5th box links to external site | Explicit handoff point shows users where INTEGRATOR ends and QUANT begins |
| Colors at low opacity fills | Keeps diagrams subtle / not distracting while maintaining brand identity |
| No JavaScript required | Both diagrams work with pure CSS hover — simpler, no build dependencies |
| Responsive via viewBox (SVG) and flexbox (HTML) | Works on mobile without media query complexity |
