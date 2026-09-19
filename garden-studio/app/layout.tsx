/*
THESIS: A calm publishing ledger for tending a private digital garden.
OWN-WORLD: Warm paper, navy ink, rust actions, leaf-green state; inherited from the public garden.
STORY: Check the connection, scan collections, inspect an item, then follow its publishing history.
FIRST VIEWPORT: Source health and collection state lead; recent activity stays visible at the edge.
FORM: Operate / publishing ledger / concept seed 0cd5468b, candidate 5.
*/
import type { Metadata } from "next"
import type { ReactNode } from "react"

import "./globals.css"
import "./editor.css"
import "./authoring.css"
import "./revisions.css"
import "./publish.css"

export const metadata: Metadata = {
  title: { default: "Garden Studio", template: "%s · Garden Studio" },
  description: "A private publishing desk for the personal garden.",
  robots: { index: false, follow: false },
}

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
