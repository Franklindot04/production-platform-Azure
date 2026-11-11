# Documentation site

This page describes how the documentation site is built and how to change it.

## How it is built

GitHub Pages builds the `docs/` folder on `main` with Jekyll. The theme is custom and is kept in this folder. There is no remote theme and no build step outside Pages. The Pages setting is turned on by the maintainer in the repository settings.

## Files

| File | What it does |
|---|---|
| `_config.yml` | Site settings, plugins, the default layout and the site address (`url` and `baseurl`) |
| `_layouts/default.html` | The page: head, stage lookup, skip link, header, navigation, breadcrumb, content, previous and next links, footer and the "On this page" column |
| `_layouts/home.html` | The home page: the hero with the title, the lead and the ring. It uses the default layout |
| `_includes/header.html` | The header: menu button, mark and project name, search, colour mode button and repository link |
| `_includes/nav.html` | The navigation: the fixed groups from `_data/navigation.yml`, then one collapsible group for each folder listed there |
| `_includes/breadcrumb.html` | The breadcrumb above the title and the name of the stage of the page |
| `_includes/prev-next.html` | The previous and next links of the pages in a folder group, in the order of the sidebar |
| `_includes/footer.html` | The maintainer line, then the footer items: Repository, Licensed under MIT, Version and Back to top |
| `_includes/logo.html` | The ring of five arcs in the stage colours, drawn inline. It takes a `size` |
| `_data/navigation.yml` | The fixed groups and pages of the navigation, with their stage, and the folders that become groups |
| `_data/stages.yml` | Which stage of the loop each page belongs to |
| `_data/maintainer.yml` | The name and links in the maintainer block and the footer |
| `assets/css/site.css` | All styles, with the colours and fonts as custom properties at the top |
| `assets/js/site.js` | Colour mode, menu, "On this page" with the heading in view, heading anchors, search, code bars with copy buttons, table wrapper, status chips, and the rows of the home page |
| `assets/search.json` | The search index: title, address and a short excerpt of every Markdown page |
| `assets/logo.svg`, `assets/favicon.svg` | The logo: the ring of five arcs on a transparent background, in mid-tone colours that read on a light and a dark tab |
| `assets/favicon-32.png`, `assets/icon-512.png` | The same ring as PNG files with a transparent background |
| `assets/apple-touch-icon.png` | The ring in the dark mode stage colours on an opaque dark square. iOS rounds the corners |
| `404.md` | The page shown for an address that does not exist. It is not in the navigation or in the search index |
| `Gemfile` | Used only to preview the site on a local machine. Pages does not read it |

## Stages

The project is a loop: build, deploy, measure, break and fix. Each stage has a colour, and a page takes the colour of its stage. The stage name is written next to the colour: in the breadcrumb ("Stage: fix") and in the sidebar group labels.

`_data/stages.yml` maps a page to a stage. A key is a file path or a folder prefix, such as `adr/`. The first key that the start of the page path matches wins. A page with the value `none` uses the build blue. A page that is not in the file also uses the build blue.

The layout writes the stage on the `body` element as `data-stage`. The stage colour is used for the band at the top of the page, the bar beside each second level heading, the dot and the current page in the sidebar, the last item of the breadcrumb, the current item in "On this page", the border of block quotes, and the hover border of the previous and next links. On the home page the ring and the five steps use all five colours.

The fixed groups in `_data/navigation.yml` take their stage from a `stage` key. The folder groups take the stage of their folder from `stages.yml`.

## Maintainer block and logo

The name and the links in the maintainer block (the bottom of the sidebar) and in the footer are in `_data/maintainer.yml`. Change `name`, `github`, `profile` or `repo` there. The file holds no email address, and none goes in Git.

The logo is a ring of five arcs, each 40 degrees long, with round caps, on a transparent background. The files are `assets/logo.svg` and `assets/favicon.svg`, and the PNG versions are `assets/favicon-32.png`, `assets/icon-512.png` and `assets/apple-touch-icon.png`. The ring in the header and the footer is drawn inline by `_includes/logo.html`, with the stage colours of the current mode.

The GitHub mark in the maintainer block is the `mark-github` icon of Primer Octicons, under the MIT licence.

## Diagrams

Diagrams written as `mermaid` code blocks are drawn on the site by the Mermaid library. The library is loaded from a public content delivery network, and only on a page that has such a block. The same blocks render on GitHub. The diagram fits the width of the page. The "View full size" button opens it at its natural size in a dialog that scrolls in both directions. The code block stays in the page, inside a "Diagram source" disclosure. If the library cannot be loaded or a diagram cannot be drawn, the code block is shown with a plain note. The Mermaid version is the constant `MERMAID_VERSION` at the top of `assets/js/site.js`.

## Footer

The footer lists four items in this order: Repository, Licensed under MIT, Version and Back to top. The repository and license links are built from the `repo` value in `_data/maintainer.yml`. The license link points to the `LICENSE` file of the repository.

The Version item shows the tag of the latest release of the repository. No file holds the version. The browser reads it from the releases of the repository, so a new release shows up with no edit. The item stays hidden until a tag has loaded, and stays hidden when the request fails. The answer is kept for the browser tab.

## Screen sizes

From 1280px the page has three columns: the sidebar, the content and "On this page". From 1024px to 1279px the right column is replaced by a closed "On this page" disclosure at the top of the content. Under 1024px the sidebar is a drawer that the menu button opens, and the search field is a panel that the search button opens. Tables scroll inside their own block, so the page does not scroll sideways.

## Change the colours and fonts

The colours of both modes and the two font families are custom properties at the top of `assets/css/site.css`. The light values are in `:root`. The dark values are in two places: the `prefers-color-scheme` block, which follows the system setting, and the `:root[data-theme="dark"]` block, which is used when the visitor chooses a mode. Change both dark blocks together.

The stage colours are `--build`, `--deploy`, `--measure`, `--break` and `--fix`, each with a `-tint`. Change the light and both dark blocks together.

There are three type faces. Atkinson Hyperlegible Next is used for text. Atkinson Hyperlegible Mono is used for code. Bricolage Grotesque is used only for the first and second level headings and the step numbers on the home page. The fonts load from Google Fonts in `_layouts/default.html`. The system fonts in the same properties are the fallback.

## Add a page

1. Create a Markdown file in `docs/`. Start it with a `#` heading. The heading becomes the page title.
2. If the file is in a folder listed under `folders` in `_data/navigation.yml` (`adr/`, `runbooks/`, `postmortems/`, `sessions/` or `plans/`), it appears in the navigation by itself.
3. Otherwise add it to the fixed list in `_data/navigation.yml`.
4. Add its path or its folder to `_data/stages.yml` if it belongs to a stage.
5. Link it from `index.md` or from the README of its folder.

Use relative links to `.md` files between pages.

Each group in the sidebar is a row with a chevron button, a dot, a label and the stage word. The chevron opens and closes the group. The label is a link when the group or folder has a `url` key in `_data/navigation.yml` (a path such as `/runbooks/`, or a section of the home page such as `/#reliability`). A folder without a `url` and without a README has a label that toggles the group. The fixed groups start open, the folder groups start closed, and the group that holds the current page is always open. The open state is saved in the browser.

## Move the site to its own domain

Change `url` and `baseurl` in `_config.yml`. Every internal link and asset uses the `relative_url` filter, so nothing else holds the address. With a domain of its own, set `baseurl` to an empty string.

## Preview on a local machine

From the repository root, with Docker installed:

```bash
docker run --rm -v "$PWD/docs":/site -w /site -p 4000:4000 -e PAGES_REPO_NWO=Franklindot04/production-platform-Azure ruby:3.3 sh -c "bundle install && bundle exec jekyll serve --host 0.0.0.0 --livereload"
```

Then open `http://localhost:4000/production-platform-Azure/`.
