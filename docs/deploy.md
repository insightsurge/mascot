# Deploying mascot (Firebase Hosting, keyless)

The `pkgdown` workflow builds the site on pushes to `main`, or when started by hand
on `main`. It never builds or deploys pull requests or other branches (#127).
It keeps the downloadable `pkgdown-site` artifact and also deploys once all four
repository variables below exist. Without them, the build and artifact still run.

Why Firebase for now: GitHub Pages on the free plan needs a public repository.
mascot is private, so it uses a separate Hosting site in `insightsurge-dev` until
the repository becomes public and GitHub Pages takes over (#195, #115).

**Visibility:** the website is public but unlisted (founder's decision,
2026-10-07). Anyone with its URL can read and share it; unlisted does not mean
access-controlled.

## Why keyless

GitHub proves the workflow's identity to Google with a short-lived OIDC token
(**Workload Identity Federation**). The provider trusts mascot's numeric repository
and owner IDs, which survive renames. A separate deploy-only service account has
the same two roles as the sister site: Hosting Admin and API Keys Viewer.
No JSON service-account keys are created or stored; repository variables are
identifiers, not secrets.

## One-time setup (founder)

Use your personal Google account and the existing Firebase project
`insightsurge-dev`. The `github` identity pool already exists; do not recreate it
or change the sister site's `playbook` provider or service account.

1. In the [Firebase console](https://console.firebase.google.com), select
   `insightsurge-dev`, then **Hosting → Add another site**. Choose an available
   site ID (suggested: `mascot-pkg`). Its URL will be
   `https://<site-id>.web.app`. This must be a separate site from the sister site.
2. Open **Cloud Shell** in the [Google Cloud console](https://console.cloud.google.com)
   with the same project selected. Run the script below after setting `SITE_ID`
   to the ID you created. This is a one-time script for new `mascot` and
   `gh-mascot-deploy` resources; if a command fails, stop and inspect the error
   before continuing. Nothing needs installing on the Mac.

   ```bash
   set -euo pipefail
   PROJECT_ID=insightsurge-dev
   SITE_ID=mascot-pkg
   PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
   SA="gh-mascot-deploy@$PROJECT_ID.iam.gserviceaccount.com"

   gcloud services enable iamcredentials.googleapis.com sts.googleapis.com \
     --project="$PROJECT_ID"

   # A new provider in the existing pool, trusting only mascot's repository and owner.
   gcloud iam workload-identity-pools providers create-oidc mascot \
     --project="$PROJECT_ID" --location=global --workload-identity-pool=github \
     --display-name="mascot" \
     --issuer-uri="https://token.actions.githubusercontent.com" \
     --attribute-mapping="google.subject=assertion.sub,attribute.repository_id=assertion.repository_id,attribute.repository_owner_id=assertion.repository_owner_id" \
     --attribute-condition="assertion.repository_owner_id=='125121920' && assertion.repository_id=='1395083932'"

   # A separate deploy-only account, with the two roles used by the sister site.
   gcloud iam service-accounts create gh-mascot-deploy --project="$PROJECT_ID" \
     --display-name="GitHub deploy: mascot"
   gcloud projects add-iam-policy-binding "$PROJECT_ID" \
     --member="serviceAccount:$SA" --role=roles/firebasehosting.admin
   gcloud projects add-iam-policy-binding "$PROJECT_ID" \
     --member="serviceAccount:$SA" --role=roles/serviceusage.apiKeysViewer

   # Only this repository may act as the account through the identity pool.
   gcloud iam service-accounts add-iam-policy-binding "$SA" --project="$PROJECT_ID" \
     --role=roles/iam.workloadIdentityUser \
     --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository_id/1395083932"

   echo "GCP_WORKLOAD_IDENTITY_PROVIDER=projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/mascot"
   echo "GCP_SERVICE_ACCOUNT=$SA"
   echo "FIREBASE_PROJECT_ID=$PROJECT_ID"
   echo "FIREBASE_SITE_ID=$SITE_ID"
   ```

3. On the Mac, select the personal GitHub configuration and check the account.
   Continue only if the command prints `insightsurge`:

   ```bash
   export GH_CONFIG_DIR="$HOME/Documents/Projects/InsightSurge/.config/gh"
   gh api user --jq .login
   ```

   Set the four variables, replacing each placeholder with its printed value:

   ```bash
   gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER -R insightsurge/mascot --body "<printed provider value>"
   gh variable set GCP_SERVICE_ACCOUNT -R insightsurge/mascot --body "<printed service account value>"
   gh variable set FIREBASE_PROJECT_ID -R insightsurge/mascot --body "insightsurge-dev"
   gh variable set FIREBASE_SITE_ID -R insightsurge/mascot --body "<chosen site ID>"
   ```

4. Once the workflow change is on `main`, start `pkgdown` by hand on `main`,
   or let the next push to `main` run it.

## Configuration and checking a deploy

`firebase.json` publishes `site/`, ignoring dotfiles, `firebase.json` and
`node_modules`. `cleanUrls` is deliberately `false`: pkgdown links use `.html`,
so Hosting serves those paths without redirecting them to extensionless URLs.

Immediately before deployment, the workflow writes `FIREBASE_SITE_ID` into the
config's `hosting.site` field using Node. This selects the separate site directly,
without a deploy target or `.firebaserc`; the tracked config contains no fixed site
ID. The CLI receives `FIREBASE_PROJECT_ID` explicitly. The service account's two
roles apply across the project, as in the sister site; site selection comes from
the workflow configuration.

In GitHub Actions, check that the build, artifact upload, keyless authentication
and **Deploy to Firebase Hosting** steps succeed. The job summary then prints
`https://<site-id>.web.app`. Open it and check the home page, a reference page,
an article and their navigation links, including `.html` links and assets.
In Firebase Hosting, confirm the new release is on the chosen mascot site and
the sister site's release is unchanged. If deployment steps are skipped, check
that all four repository variables have non-empty values.

The setup script and deployment have not been run as part of writing these files.
The first live deploy is the check of Cloud permissions and Hosting behaviour.

## Switching to GitHub Pages (#115)

When the repository becomes public, enable GitHub Pages with **GitHub Actions**
as its source. Replace the Firebase authentication, Node setup and deployment
steps with Pages artifact upload and deployment, still from `main` only. Give
the Pages deployment job `pages: write` and `id-token: write`, and configure its
`github-pages` environment. Keep the site build and downloadable artifact.

Set `_pkgdown.yml`'s site URL to the final Pages URL and check navigation and
assets there before retiring the Firebase site. Remove `firebase.json`, its
`.Rbuildignore` entry, the four repository variables and the Firebase-only
workflow environment values. Delete only the `mascot` identity provider,
`gh-mascot-deploy` service account and mascot Hosting site; retain the shared
`github` pool and the sister site's resources. Update this guide and `AGENTS.md`
to record the switch.
