import {useId} from 'react';
/** Industry-neutral NARVO identity, separate from Company branding. */
export function NarvoMark(){const id=useId();return <svg className="narvo-mark" width="32" height="32" viewBox="0 0 32 32" fill="none" aria-hidden="true"><defs><linearGradient id={id} x1="5" y1="6" x2="27" y2="25" gradientUnits="userSpaceOnUse"><stop stopColor="var(--erp-brand-blue)"/><stop offset="1" stopColor="var(--erp-brand-cyan)"/></linearGradient></defs><path d="M6 26V7a1 1 0 0 1 1.7-.7L25 24V6" stroke={`url(#${id})`} strokeWidth="6" strokeLinecap="round" strokeLinejoin="round"/></svg>;}
