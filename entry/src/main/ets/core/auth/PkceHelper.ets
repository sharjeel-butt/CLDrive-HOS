import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../../utils/Logger';

/**
 * PKCE (Proof Key for Code Exchange) helper for OAuth 2.0 public clients.
 *
 * Replaces the client secret with a one-time cryptographic challenge:
 *   1. Generate a random code_verifier (43–128 chars, unreserved charset).
 *   2. Derive code_challenge = BASE64URL(SHA256(code_verifier)).
 *   3. Send code_challenge + code_challenge_method=S256 in the authorize URL.
 *   4. Send the original code_verifier in the token exchange.
 *
 * Microsoft's identity platform supports both `plain` and `S256`. We always
 * use S256 because `plain` provides no cryptographic protection.
 */
export class PkceHelper {
  private static readonly TAG = 'PkceHelper';
  /**
   * RFC 7636 §4.1: verifier must be 43–128 characters from the
   * unreserved set [A-Z a-z 0-9 - . _ ~].
   */
  private static readonly VERIFIER_LENGTH: number = 64;
  private static readonly UNRESERVED: string =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /**
   * Generate a cryptographically secure code_verifier.
   * Uses the system CSPRNG via cryptoFramework.createRandom().
   */
  static async generateCodeVerifier(): Promise<string> {
    const rand = cryptoFramework.createRandom();
    const bytes = await rand.generateRandom(PkceHelper.VERIFIER_LENGTH);

    let verifier = '';
    for (let i = 0; i < bytes.data.length; i++) {
      const idx: number = bytes.data[i] % PkceHelper.UNRESERVED.length;
      verifier += PkceHelper.UNRESERVED.charAt(idx);
    }
    Logger.info(PkceHelper.TAG, `Generated code_verifier (${verifier.length} chars)`);
    return verifier;
  }

  /**
   * Derive code_challenge = BASE64URL-NOPADDING(SHA256(ASCII(code_verifier))).
   */
  static async generateCodeChallenge(codeVerifier: string): Promise<string> {
    const md = cryptoFramework.createMd('SHA256');
    const encoder = new util.TextEncoder();
    const verifierBytes: Uint8Array = encoder.encodeInto(codeVerifier);

    await md.update({ data: verifierBytes });
    const digest = await md.digest();

    // Base64url-encode the raw SHA-256 digest (32 bytes → 43 chars).
    const b64 = new util.Base64Helper();
    const standard: string = b64.encodeToStringSync(digest.data);

    // Convert standard Base64 → Base64url: + → -, / → _, strip '=' padding.
    let urlSafe: string = '';
    for (let i = 0; i < standard.length; i++) {
      const ch: string = standard.charAt(i);
      if (ch === '+') {
        urlSafe += '-';
      } else if (ch === '/') {
        urlSafe += '_';
      } else if (ch === '=') {
        // Padding is not allowed in PKCE code_challenge.
      } else {
        urlSafe += ch;
      }
    }
    Logger.info(PkceHelper.TAG, `Generated code_challenge (${urlSafe.length} chars)`);
    return urlSafe;
  }
}