/**
 * netlify-globals.d.ts — ambient types for the Netlify Edge Functions runtime
 * FOR THE COMMONS GOOD — reusable pattern, candidate for shared WSP001 library
 *
 * WHY THIS FILE EXISTS:
 * The `Netlify` global is injected by the Deno edge runtime at execution time,
 * so it has no declaration in source. Without one, `deno check` reports
 * "Cannot find name 'Netlify'" on every env var read — three errors per file.
 * Those unavoidable errors are why `just backend-typecheck` was written to
 * discard its own output, which meant the gate could not fail and no real type
 * error would ever be caught. Declaring the global makes the gate real.
 *
 * DELIBERATELY OUTSIDE netlify/edge-functions/: every .ts file in that
 * directory is treated as a deployable function. A stray .d.ts there would be
 * bundled as one and fail for having no default export.
 *
 * Reference it from an edge function with:
 *   /// <reference path="../types/netlify-globals.d.ts" />
 *
 * Runtime reference: https://docs.netlify.com/build/edge-functions/api/
 */

declare namespace Netlify {
  /** Environment variables configured in the Netlify UI or netlify.toml. */
  const env: {
    /** Returns the value, or undefined when the variable is not set. */
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    has(key: string): boolean;
    delete(key: string): void;
    toObject(): Record<string, string>;
  };

  /** Geolocation and connection context for the current request. */
  const context: {
    geo?: {
      city?: string;
      country?: { code?: string; name?: string };
      subdivision?: { code?: string; name?: string };
      timezone?: string;
      latitude?: number;
      longitude?: number;
    };
    ip?: string;
    requestId?: string;
  };
}
