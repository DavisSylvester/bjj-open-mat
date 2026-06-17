import { type Static, Type as t } from "@sinclair/typebox";

// 0–5 score per category collected by the review screen.
export const CategoryRatings = t.Object(
  {
    instruction: t.Number({ minimum: 0, maximum: 5 }),
    cleanliness: t.Number({ minimum: 0, maximum: 5 }),
    variety: t.Number({ minimum: 0, maximum: 5 }),
    worth_returning: t.Number({ minimum: 0, maximum: 5 }),
    overall: t.Number({ minimum: 0, maximum: 5 }),
  },
  { $id: "CategoryRatings" },
);
export type CategoryRatings = Static<typeof CategoryRatings>;
