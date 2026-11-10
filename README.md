# cerebrai-app.github.io

Marketing site for **Cerebr.AI** — a second brain powered by agentic AI.

Built with [Astro](https://astro.build), TypeScript, and Vue. Deployed to GitHub Pages at
<https://cerebrai-app.github.io>.

## Development

Requires Node.js 22.23 or newer and [pnpm](https://pnpm.io) (the version is pinned in
`package.json`; `corepack enable` will pick it up).

| Command           | Action                                               |
| :---------------- | :--------------------------------------------------- |
| `pnpm install`    | Install dependencies                                 |
| `pnpm dev`        | Start the dev server at `localhost:4321`             |
| `pnpm build`      | Type-check and build the site to `./dist/`           |
| `pnpm preview`    | Preview the production build locally                 |
| `pnpm check`      | Type-check Astro, Vue, and TypeScript files          |
| `pnpm lint`       | Lint with ESLint (`pnpm lint:fix` to auto-fix)       |
| `pnpm format`     | Format with Prettier (`pnpm format:check` to verify) |
| `pnpm verify`     | Run type-check, ESLint, and the Prettier check       |
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
- **CI** (`ci.yml`) runs the type-check, ESLint, and Prettier on pull requests and on `main`.
- **PR screenshot** (`pr-screenshot.yml`) builds each pull request, captures the home page at
  desktop and mobile sizes, and posts them in a new PR comment on every push, replacing the previous
  one. The images are uploaded as comment attachments with `gh pr comment --attach`, which needs a
  GitHub App: set the `SCREENSHOT_APP_CLIENT_ID` and `SCREENSHOT_APP_PRIVATE_KEY` secrets as
  described at the top of the workflow file.
