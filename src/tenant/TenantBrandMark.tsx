import { useState } from "react";
import { useTenantSettings } from "./TenantSettingsContext";
import { HardHat } from "lucide-react";

export function TenantBrandMark({ logoUrl, className = "h-10 w-10" }: { logoUrl: string | null; className?: string }) {
  const settings = useTenantSettings();
  const alt = settings.phase === "READY" ? settings.settings.effectiveDisplayName : "";
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  if (logoUrl && failedUrl !== logoUrl) {
    return <img src={logoUrl} alt={alt} referrerPolicy="no-referrer" className={`${className} shrink-0 rounded-lg object-contain`} onError={() => setFailedUrl(logoUrl)} />;
  }
  return <span className={`flex ${className} items-center justify-center rounded-lg bg-[var(--tenant-primary)] text-white`}><HardHat size={19} /></span>;
}
