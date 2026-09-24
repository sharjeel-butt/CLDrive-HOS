/**
 * The information needed to start a download.
 *
 * Different providers authenticate downloads differently:
 *   - OneDrive hands back a short-lived pre-authenticated URL with no headers.
 *   - Google Drive hands back an API URL that requires an Authorization header.
 *
 * Bundling url + headers together keeps the ViewModel provider-agnostic.
 */
export interface DownloadInfo {
  url: string;
  headers: Map<string, string>;
}