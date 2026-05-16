# Bird Watcher Web App

React + Vite frontend for connecting a wallet and deploying a Bird Watcher contract.

## Local Setup

Create a local env file:

```sh
cp .env.example .env.local
```

Then set:

```sh
VITE_WALLETCONNECT_PROJECT_ID=your_walletconnect_project_id
```

Run the app:

```sh
npm install
npm run dev
```

## Vercel Deployment

The Vercel project should use `web-app` as its root directory. With that root,
the default commands are:

```sh
npm run build
```

and:

```sh
dist
```

This app reads the WalletConnect project ID from `VITE_WALLETCONNECT_PROJECT_ID`.
Because this is a Vite client-side app, the variable must:

- Start with `VITE_`
- Be configured in the Vercel project, not only in `.env.local`
- Be available to the Vercel environment you are deploying, such as Production, Preview, or Development
- Be present before the deployment build starts

After adding or changing the variable in Vercel, redeploy the app. Vite bakes
`VITE_*` variables into the static JavaScript bundle at build time, so changing
the variable after a deployment does not update the already-built app.

If the variable is missing, `npm run build` now fails with a clear error before
Vercel publishes a broken build.

## Scripts

```sh
npm run dev
npm run build
npm run lint
npm run preview
```
