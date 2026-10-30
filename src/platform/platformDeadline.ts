export type ReadOptions = { signal?: AbortSignal; timeoutMs?: number };
export class PlatformDeadlineError extends Error {
  readonly code: "REQUEST_TIMEOUT" | "REQUEST_CANCELLED";
  constructor(code: "REQUEST_TIMEOUT" | "REQUEST_CANCELLED") { super(code); this.code = code; }
}

// The outer deadline also bounds SDK session/refresh waits before fetch starts.
// AbortSignal alone cannot cancel an SDK promise that never reaches fetch.
export async function platformDeadline<T>(work: (signal: AbortSignal) => PromiseLike<T>, { signal, timeoutMs = 10000 }: ReadOptions = {}): Promise<T> {
  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  let cancel: (() => void) | undefined;
  const deadline = new Promise<never>((_, reject) => {
    cancel = () => { reject(new PlatformDeadlineError("REQUEST_CANCELLED")); controller.abort(); };
    if (signal?.aborted) { cancel(); return; }
    signal?.addEventListener("abort", cancel, { once: true });
    timer = setTimeout(() => { reject(new PlatformDeadlineError("REQUEST_TIMEOUT")); controller.abort(); }, timeoutMs);
  });
  try { return await Promise.race([deadline, Promise.resolve().then(() => {
    if (controller.signal.aborted) throw new PlatformDeadlineError("REQUEST_CANCELLED");
    return work(controller.signal);
  })]); }
  finally { clearTimeout(timer); if (cancel) signal?.removeEventListener("abort", cancel); }
}
