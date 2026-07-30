/// Reads Google Maps links for a place. Google does not permit programmatic
/// review submission — the returned URI hands the user off to Google Maps,
/// where they compose and submit the review themselves.
export interface PlacesClient {
  writeAReviewUri(placeId: string): Promise<string | null>;
}

interface PlaceDetailsResponse {
  readonly googleMapsLinks?: { readonly writeAReviewUri?: string };
}

export class GooglePlacesClient implements PlacesClient {

  public constructor(private readonly apiKey: string) {}

  public async writeAReviewUri(placeId: string): Promise<string | null> {
    if (!this.apiKey) return null;
    // Place Details (New) takes an unprefixed field mask. The `places.`-prefixed
    // form belongs to Text/Nearby Search responses and is rejected here.
    const url = `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`;
    const res = await fetch(url, {
      headers: {
        "X-Goog-Api-Key": this.apiKey,
        "X-Goog-FieldMask": "googleMapsLinks.writeAReviewUri",
      },
    });
    if (!res.ok) return null;
    const body = (await res.json()) as PlaceDetailsResponse;
    return body.googleMapsLinks?.writeAReviewUri ?? null;
  }
}

/// Used when no API key is configured, so local and test environments simply
/// omit the Google hand-off instead of failing.
export class NullPlacesClient implements PlacesClient {

  public async writeAReviewUri(): Promise<string | null> {
    return null;
  }
}
