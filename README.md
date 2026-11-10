# cerebrai-app.github.io

Marketing site for **Cerebr.AI** — a second brain powered by agentic AI.

Built with [Astro](https://astro.build), TypeScript, and Vue. Deployed to GitHub Pages at
<https://cerebrai-app.github.io>.

## Development

Requires Node.js 22.23.4 or newer and [pnpm](https://pnpm.io) (the version is pinned in
`package.json`; `corepack enable` will pick it up).

| Command           | Action                                               |
| :---------------- | :--------------------------------------------------- |
| `pnpm install`    | Install dependencies                                 |
| `pnpm dev`        | Start the dev server at `localhost:4321`             |
| `pnpm build`      | Build the site to `./dist/`                          |
| `pnpm preview`    | Preview the production build locally                 |
| `pnpm check`      | Type-check Astro, Vue, and TypeScript files          |
| `pnpm lint`       | Lint with ESLint (`pnpm lint:fix` to auto-fix)       |
| `pnpm format`     | Format with Prettier (`pnpm format:check` to verify) |
| `pnpm test`       | Test the screenshot upload script                    |
| `pnpm verify`     | Run type-check, ESLint, Prettier, and the tests      |
| `pnpm screenshot` | Capture the built home page into `./screenshots/`    |

## Project structure

```text
src/
├── components/   # Astro and Vue components
├── layouts/      # Page shells
├── pages/        # File-based routes
└── styles/       # Global CSS
public/           # Static assets copied as-is
scripts/          # Tooling (home page screenshots)
```

## Workflows

- **Deploy** (`deploy.yml`) builds and publishes the site to GitHub Pages on every push to `main`,
  following the [Astro GitHub Pages guide](https://docs.astro.build/en/guides/deploy/github/). In
  the repository's **Settings → Pages**, the **Source** must be set to **GitHub Actions**.
- **CI** (`ci.yml`) runs the type-check, ESLint, Prettier, and the script tests on pull requests and
  on `main`.
- **PR screenshot** (`pr-screenshot.yml`) posts a desktop and a mobile screenshot of the home page
  as a comment on every pull request, replacing the previous one. The setup (a GitHub App and two
  secrets) is described at the top of the workflow file. The images are stored in a public
  repository, so do not open a pull request that shows anything unreleased or private.
- **PR screenshot cleanup** (`pr-screenshot-cleanup.yml`) removes a closed pull request's
  screenshots from that repository. See the top of the workflow file for what that does and does
  not do.
