/**
 * Parse query parameters from a URL string.
 *
 * ArkTS does not type URLSearchParams (it's treated as `any`), so we
 * implement parsing manually with only typed constructs.
 *
 * Example:
 *   parseQuery('https://cl.drive/oauth?code=abc&state=xyz')
 *   → Map { 'code' → 'abc', 'state' → 'xyz' }
 */
export function parseQuery(url: string): Map<string, string> {
  const result = new Map<string, string>();

  const qIndex: number = url.indexOf('?');
  if (qIndex < 0) {
    return result;
  }

  // Strip any fragment identifier (#...) before splitting.
  let query: string = url.substring(qIndex + 1);
  const hashIndex: number = query.indexOf('#');
  if (hashIndex >= 0) {
    query = query.substring(0, hashIndex);
  }

  if (query.length === 0) {
    return result;
  }

  const pairs: string[] = query.split('&');
  for (let i = 0; i < pairs.length; i++) {
    const pair: string = pairs[i];
    if (pair.length === 0) {
      continue;
    }

    const eqIndex: number = pair.indexOf('=');
    if (eqIndex < 0) {
      // Key with no value — store as empty string.
      const keyOnly: string = decodeURIComponent(pair);
      result.set(keyOnly, '');
      continue;
    }

    const rawKey: string = pair.substring(0, eqIndex);
    const rawValue: string = pair.substring(eqIndex + 1);

    const key: string = decodeURIComponent(rawKey);
    const value: string = decodeURIComponent(rawValue);
    result.set(key, value);
  }

  return result;
}

/**
 * Build an application/x-www-form-urlencoded string from a Map.
 * The inverse of parseQuery; used for POST bodies.
 */
export function encodeForm(params: Map<string, string>): string {
  const parts: string[] = [];
  params.forEach((value: string, key: string): void => {
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
  });
  return parts.join('&');
}

/**
 * Build a query string (without the leading '?') from a Map.
 * Same encoding rules as encodeForm; provided for readability at call sites.
 */
export function buildQuery(params: Map<string, string>): string {
  return encodeForm(params);
}

/**
 * Return true if the string is null, undefined, or empty.
 * ArkTS-safe: no `any`/`unknown` used.
 */
export function isEmpty(value: string | undefined | null): boolean {
  return value === undefined || value === null || value.length === 0;
}

/**
 * Return true if the string is non-empty.
 */
export function isNotEmpty(value: string | undefined | null): boolean {
  return !isEmpty(value);
}