export type SetupCheck = {
  label: string
  configured: boolean
  note: string
}

function value(name: string) {
  return process.env[name]?.trim() || ""
}

function present(name: string) {
  return Boolean(value(name))
}

export function studioSetupChecks(): SetupCheck[] {
  return [
    {
      label: "Session signing",
      configured: (process.env.GARDEN_STUDIO_SESSION_SECRET?.length || 0) >= 32,
      note: "A server-only secret of at least 32 characters",
    },
    {
      label: "Account allowlist",
      configured: present("GARDEN_STUDIO_ALLOWED_LOGIN"),
      note: "The only GitHub account allowed to sign in",
    },
    {
      label: "GitHub sign-in",
      configured: present("GITHUB_OAUTH_CLIENT_ID") && present("GITHUB_OAUTH_CLIENT_SECRET"),
      note: "OAuth client ID and client secret",
    },
    {
      label: "GitHub App access",
      configured:
        present("GITHUB_APP_ID") &&
        present("GITHUB_APP_INSTALLATION_ID") &&
        present("GITHUB_APP_PRIVATE_KEY"),
      note: "App ID, installation ID, and private key",
    },
    {
      label: "Private vault",
      configured: present("GARDEN_STUDIO_VAULT_REPOSITORY"),
      note: "Repository plus the main branch default",
    },
    {
      label: "Public garden",
      configured: present("GARDEN_STUDIO_PUBLIC_REPOSITORY"),
      note: "Public Quartz repository",
    },
    {
      label: "Review branch",
      configured:
        present("GARDEN_STUDIO_PUBLIC_PREVIEW_BRANCH") &&
        value("GARDEN_STUDIO_PUBLIC_PREVIEW_BRANCH") !== "main",
      note: "Must be an isolated branch, never main",
    },
    {
      label: "Obsidian handoff",
      configured: present("GARDEN_STUDIO_OBSIDIAN_VAULT_NAME"),
      note: "Local vault name for obsidian:// links",
    },
  ]
}
