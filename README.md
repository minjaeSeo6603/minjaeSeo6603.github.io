# minjaeseo.github.io

Custom static portfolio website for GitHub Pages.

## Stack
- HTML (`index.html`)
- CSS (`styles.css`)
- Vanilla JavaScript (`script.js`)
- Static documents under `assets/docs/`

## Why static (no PHP)
GitHub Pages serves static files and does not execute PHP. This site is built to run correctly on GitHub Pages without extra build steps.

## Add or replace documents
1. Put your PDF into `assets/docs/`.
2. Update the corresponding link in `index.html`.

Example:
```html
<a class="document-card" href="assets/docs/my_new_report.pdf">
  <span class="doc-title">My New Report</span>
  <span class="doc-meta">Short description</span>
</a>
```

## Local preview
Open `index.html` in a browser, or run:

```bash
cd /Users/seominjae/minjaeseo.github.io
python3 -m http.server 8080
```

Then open `http://localhost:8080`.

## Deploy on GitHub Pages
### Option A: username repo (recommended)
1. Create repository named `minjaeseo.github.io`.
2. Push all files in this folder to the repository root.
3. In GitHub Settings -> Pages, choose branch `main` and folder `/ (root)`.

### Option B: project repo
1. Push this folder to any repository.
2. In Pages settings choose source branch and `/ (root)`.
3. Site URL will be `https://<username>.github.io/<repo-name>/`.

## Current setup
- Profile photo is loaded from `assets/images/profile.jpg`
- UChicago logo is loaded from `assets/images/uchicago_logo.svg`
- No CV section
- Documents can be replaced anytime in `assets/docs/`
