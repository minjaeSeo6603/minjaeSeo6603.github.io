# minjaeseo6603.github.io

Academic site for Minjae Seo — working papers, earlier research, experience, and CV.
Static HTML/CSS/JS, served by GitHub Pages from the `main` branch.

## Stack
- `index.html` — all content, one page, six sections
- `styles.css` — design tokens at the top of the file; light and dark palettes
- `script.js` — contents toggle, scroll-spy, section reveal (no dependencies)
- `.nojekyll` — tells GitHub Pages to serve files as-is (needed because some asset
  directories begin with an underscore, which Jekyll would otherwise skip)

## Where things live
| Path | Holds |
|---|---|
| `assets/papers/` | Working papers and full research papers |
| `assets/docs/` | Write-ups, reports, writing samples, CV |
| `assets/code/` | Do-files, scripts, and Quarto sources linked from entries |
| `assets/images/` | Portrait and favicons |

## Add a working paper
1. Drop the PDF in `assets/papers/`.
2. Copy an existing `<article class="paper">` block in `index.html` and edit it.
3. Update the `<span class="section-count">` word in the section heading.

The estimate strip is optional. It takes percentages along a domain you choose:

```html
<figure class="estimate">
  <figcaption>What the number is</figcaption>
  <!-- lo/hi = interval ends, pt = point estimate, zero = the zero reference -->
  <div class="estimate-track" style="--lo: 44.8%; --hi: 87.8%; --pt: 66.3%; --zero: 50%">
    <span class="track-line" aria-hidden="true"></span>
    <span class="track-zero" aria-hidden="true"></span>
    <span class="track-interval" aria-hidden="true"></span>
    <span class="track-point" aria-hidden="true"></span>
  </div>
  <p class="estimate-read">
    <span class="estimate-value">+0.065</span>
    <span class="estimate-note">95% CI [−0.021, +0.151] · p = 0.14</span>
  </p>
</figure>
```

Omit `track-point` and add `data-kind="set"` to the `<figure>` for a bounded
estimand with no point estimate.

## Add an earlier-research entry
Copy an `<li class="work">` block inside the right `<ol class="works">`. Each entry
carries a description, an optional `work-result` line for headline numbers, method
chips in `work-meta`, and links.

## Replace the CV
Overwrite `assets/docs/Seo_Minjae_CV.pdf`. The filename is referenced twice
(rail and contact list), so keeping the name means no HTML edits.

## Local preview
```bash
python3 -m http.server 8080
```
Then open `http://localhost:8080`.

## Deploy
GitHub Pages is set to branch `main`, folder `/ (root)`. Pushing to `main`
publishes; there is no build step.

Note: the `master` branch of this repository holds an unused Jekyll
(academicpages) site. It is not deployed. Edit `main`.
