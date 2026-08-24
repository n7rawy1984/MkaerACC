// Storage driver abstraction. Swap this implementation (e.g. for a
// Supabase-backed driver) without touching repositories, the posting
// engine, or the UI.

export interface StorageDriver {
  load<T>(key: string): T[] | null;
  save<T>(key: string, value: T[]): void;
}

export class LocalStorageDriver implements StorageDriver {
  private readonly namespace: string;

  constructor(namespace: string) {
    this.namespace = namespace;
  }

  private fullKey(key: string): string {
    return `${this.namespace}:${key}`;
  }

  load<T>(key: string): T[] | null {
    const raw = window.localStorage.getItem(this.fullKey(key));
    if (!raw) return null;
    try {
      return JSON.parse(raw) as T[];
    } catch {
      return null;
    }
  }

  save<T>(key: string, value: T[]): void {
    window.localStorage.setItem(this.fullKey(key), JSON.stringify(value));
  }
}
