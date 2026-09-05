// Clinton-OS wordmark. Text based so a rebrand touches brand.ts only.
// Poppins display, cyan signal dot after the name, orange on hover via CSS.
import { BRAND_NAME } from "../lib/brand";

export function Wordmark({ className }: { className?: string }) {
  return (
    <span className={`wordmark wordmark-text ${className ?? ""}`} aria-label={BRAND_NAME}>
      <span className="wordmark-name">{BRAND_NAME}</span>
      <span className="wordmark-dot" aria-hidden="true" />
    </span>
  );
}
