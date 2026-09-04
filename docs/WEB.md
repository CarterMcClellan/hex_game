# Play in a browser

The game exports to a static website with Godot 4.6.3. It uses the same classes, campaign, spell pool and combat rules as the native game. Desktop browsers retain the complete board, hand, scenery, and sidebar. Portrait phone screens use large, touch-friendly spell cards instead of showing the hand and rune board, with a visible Menu button replacing the need for Escape.

## GitHub Pages

The workflow in `.github/workflows/pages.yml` builds and tests every pull request. After it is merged into `main`, it publishes the browser game to GitHub Pages.

The repository owner must select **Settings → Pages → Build and deployment → Source → GitHub Actions** once. With the default repository domain, a successful deployment will serve:

`https://cartermcclellan.github.io/hex_game/`

This is the intended deployment URL, not a claim that the site is already live. The workflow also supports **Actions → Build and deploy the browser game → Run workflow** on `main`. Deployments are restricted to the original repository; fork pull requests only build and test.

The workflow downloads the pinned Godot 4.6.3 editor and export templates from the official release, caches the editor and single-threaded Web template, exports the game, runs rules and agent checks, and publishes the static artifact. It uses GitHub's Pages token; no personal access token is required. Compiled exports stay out of Git history.

## Build locally

1. Install the Godot 4.6.3 standard editor and download its **Export templates** archive from the [official release](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable).
2. From the repository root, run:

```sh
python3 tools/build_web.py --godot /path/to/godot --templates /path/to/Godot_v4.6.3-stable_export_templates.tpz
python3 -m http.server 8766 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8766/`. Subsequent builds can omit `--templates`. The helper extracts only the single-threaded Web template into the ignored `work/templates` directory; it does not install into your system's Godot configuration. An extracted `web_nothreads_release.zip` can also be passed to `--templates`.

Serve the whole output folder together. Opening `index.html` as a local file will not work. Paths are relative, so the game also works beneath GitHub Pages' `/hex_game/` subdirectory.

## Browser behavior

The web export uses WebGL 2 and WebAssembly, with threading disabled so custom cross-origin isolation headers are unnecessary. Music becomes audible after interacting with the game. Campaign progress is saved in this browser's site storage, separately from the native application's save. Clearing site data clears that browser campaign.

References: [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Local validation

The release export was tested in Chromium at `/hex_game/` with no cross-origin isolation headers. Class selection, touch spell selection and casting, the enemy response, Menu settings, class persistence after reload, and responsive layouts from 1440×900 down to a 390×844 phone viewport worked. The audio context was running and produced a nonzero measured signal after interaction. No browser console errors were recorded. The workflow YAML and its deployment conditions were validated locally; GitHub Actions has not run until the branch can be published.
