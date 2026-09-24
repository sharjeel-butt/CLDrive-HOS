export class Endpoints {
  // ---------------------------------------------------------------------------
  // Microsoft identity platform (v2.0 endpoint)
  // ---------------------------------------------------------------------------
  static readonly MS_AUTH_BASE: string =
    'https://login.microsoftonline.com/common/oauth2/v2.0';
  static readonly MS_AUTHORIZE: string = `${Endpoints.MS_AUTH_BASE}/authorize`;
  static readonly MS_TOKEN: string = `${Endpoints.MS_AUTH_BASE}/token`;

  // ---------------------------------------------------------------------------
  // Microsoft Graph API
  // ---------------------------------------------------------------------------
  static readonly GRAPH_BASE: string = 'https://graph.microsoft.com/v1.0';
  static readonly GRAPH_ME: string = `${Endpoints.GRAPH_BASE}/me`;
  static readonly GRAPH_DRIVE: string = `${Endpoints.GRAPH_BASE}/me/drive`;
  static readonly GRAPH_ROOT_CHILDREN: string = `${Endpoints.GRAPH_DRIVE}/root/children`;

  // ---------------------------------------------------------------------------
  // OneDrive OAuth redirect (intercepted in the WebView)
  // ---------------------------------------------------------------------------
  static readonly TOKEN_EXCHANGE_REDIRECT: string = 'https://cl.drive/oauth';

  // ---------------------------------------------------------------------------
  // Google identity platform
  // ---------------------------------------------------------------------------
  static readonly GOOGLE_AUTH_URL: string =
    'https://accounts.google.com/o/oauth2/v2/auth';
  static readonly GOOGLE_TOKEN_URL: string =
    'https://oauth2.googleapis.com/token';

  // ---------------------------------------------------------------------------
  // Google Drive API v3
  // ---------------------------------------------------------------------------
  static readonly GOOGLE_DRIVE_API: string =
    'https://www.googleapis.com/drive/v3';
  static readonly GOOGLE_DRIVE_UPLOAD_API: string =
    'https://www.googleapis.com/upload/drive/v3';

  // ---------------------------------------------------------------------------
  // Google Drive OAuth redirect (loopback; intercepted in the WebView)
  // ---------------------------------------------------------------------------
  static readonly GOOGLE_REDIRECT_URI: string =
    'http://127.0.0.1:8080/oauth2redirect';
}