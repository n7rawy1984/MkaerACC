import { useState } from "react";
import { HardHat } from "lucide-react";

export function TenantBrandMark({ logoUrl, className = "h-10 w-10" }: { logoUrl: string | null; className?: string }) {
  const [failedUrl, setFailedUrl] = useState<string | null>(null);
  if (logoUrl && failedUrl !== logoUrl) {
    return <img src={logoUrl} alt="" referrerPolicy="no-referrer" className={`${className} rounded-lg object-contain`} onError={() => setFailedUrl(logoUrl)} />;
  }
  return <span className={`flex ${className} items-center justify-center rounded-lg bg-[var(--tenant-primary)] text-white`}><HardHat size={19} /></span>;
}
