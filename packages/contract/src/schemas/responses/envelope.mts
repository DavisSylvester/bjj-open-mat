import { type Static, type TSchema, Type as t } from "@sinclair/typebox";

export const ListMeta = t.Object(
  { page: t.Integer({ minimum: 1 }), limit: t.Integer({ minimum: 1 }), total: t.Integer({ minimum: 0 }) },
  { $id: "ListMeta" },
);
export type ListMeta = Static<typeof ListMeta>;

// Generic envelope builders for OpenAPI composition.
export const DataResponse = <T extends TSchema>(data: T): ReturnType<typeof t.Object> =>
  t.Object({ data });
export const ListResponse = <T extends TSchema>(item: T): ReturnType<typeof t.Object> =>
  t.Object({ data: t.Array(item), meta: ListMeta });

export const ErrorResponse = t.Object(
  {
    error: t.Object({
      code: t.String(),
      message: t.String(),
      details: t.Optional(t.Unknown()),
    }),
  },
  { $id: "ErrorResponse" },
);
export type ErrorResponse = Static<typeof ErrorResponse>;
