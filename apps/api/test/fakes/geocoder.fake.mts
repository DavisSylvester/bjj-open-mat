import type { Geocoder } from "../../src/services/geocoder.mts";

export const nullGeocoder: Pick<Geocoder, "lookupZip"> = {
  lookupZip: () => null,
};

export const fakeGeocoder: Pick<Geocoder, "lookupZip"> = {
  lookupZip: (z: string) => (z === "75495" ? { lat: 33.42, lng: -96.58 } : null),
};
