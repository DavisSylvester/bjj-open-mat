import { describe, expect, it } from 'bun:test';
import { ZipcodesGeocoder } from '../src/services/geocoder.mts';

describe('ZipcodesGeocoder', () => {
  const geo = new ZipcodesGeocoder();

  it('resolves a known US zip to coordinates', () => {
    const p = geo.lookupZip('75495');
    expect(p).not.toBeNull();
    expect(p!.lat).toBeGreaterThan(32);
    expect(p!.lat).toBeLessThan(34);
    expect(p!.lng).toBeLessThan(-95);
    expect(p!.lng).toBeGreaterThan(-98);
  });

  it('returns null for an unknown zip', () => {
    expect(geo.lookupZip('00000')).toBeNull();
    expect(geo.lookupZip('nonsense')).toBeNull();
  });
});
