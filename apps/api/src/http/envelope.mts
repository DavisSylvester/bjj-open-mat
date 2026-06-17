import type { ListMeta } from "@bjj/contract";

export function data<T>(value: T): { data: T } {
  return { data: value };
}

export function list<T>(items: T[], meta: ListMeta): { data: T[]; meta: ListMeta } {
  return { data: items, meta };
}
