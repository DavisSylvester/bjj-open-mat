import { type Static, Type as t } from "@sinclair/typebox";

export const ChannelReadState = t.Object(
  {
    id: t.String(),
    channelId: t.String(),
    userId: t.String(),
    lastReadAt: t.Optional(t.String()),
    muted: t.Boolean({ default: false }),
  },
  { $id: "ChannelReadState" },
);
export type ChannelReadState = Static<typeof ChannelReadState>;
