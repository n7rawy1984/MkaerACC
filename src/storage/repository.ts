import type { StorageDriver } from "./storageDriver";

// Generic CRUD repository over a StorageDriver. This is the only place
// that knows how a collection of entities is persisted; business logic and
// UI code interact with repositories, never with the driver directly.
export class Repository<T extends { id: string }> {
  private cache: T[] | null = null;
  private readonly driver: StorageDriver;
  private readonly key: string;

  constructor(driver: StorageDriver, key: string) {
    this.driver = driver;
    this.key = key;
  }

  private read(): T[] {
    if (this.cache) return this.cache;
    this.cache = this.driver.load<T>(this.key) ?? [];
    return this.cache;
  }

  private write(items: T[]): void {
    this.cache = items;
    this.driver.save(this.key, items);
  }

  getAll(): T[] {
    return [...this.read()];
  }

  getById(id: string): T | undefined {
    return this.read().find((item) => item.id === id);
  }

  create(item: T): T {
    const items = this.read();
    this.write([...items, item]);
    return item;
  }

  update(id: string, patch: Partial<T>): T | undefined {
    const items = this.read();
    let updated: T | undefined;
    const next = items.map((item) => {
      if (item.id !== id) return item;
      updated = { ...item, ...patch };
      return updated;
    });
    if (updated) this.write(next);
    return updated;
  }

  remove(id: string): void {
    this.write(this.read().filter((item) => item.id !== id));
  }

  replaceAll(items: T[]): void {
    this.write(items);
  }

  isEmpty(): boolean {
    return this.read().length === 0;
  }
}
