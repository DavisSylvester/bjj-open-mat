import { Elysia, t } from 'elysia';
import type { Container } from '../container.mts';
import { data } from '../http/envelope.mts';

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export function geoRoutes(container: Container) {
  const { geocoder } = container;

  return new Elysia({ prefix: '/api/v1/geo' }).get(
    '/reverse',
    ({ query }) => {
      const r = geocoder.reverse(query.lat, query.lng);
      if (!r) return data({ city: '', state: '', label: '' });
      return data({ city: r.city, state: r.state, label: `${r.city}, ${r.state}` });
    },
    { query: t.Object({ lat: t.Number(), lng: t.Number() }) },
  );
}
