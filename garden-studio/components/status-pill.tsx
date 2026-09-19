import type { ItemStatus } from "@/lib/types"

export function StatusPill({
  status,
}: {
  status: ItemStatus | "connected" | "demo" | "attention"
}) {
  return <span className={`status-pill status-${status}`}>{status}</span>
}
