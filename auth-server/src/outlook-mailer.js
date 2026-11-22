import { MailDeliveryError } from "./mail-delivery-error.js";

export const OUTLOOK_AUTHORITY = "https://login.microsoftonline.com/consumers/oauth2/v2.0";
export const OUTLOOK_SCOPE = "https://graph.microsoft.com/Mail.Send offline_access";
const SEND_URL = "https://graph.microsoft.com/v1.0/me/sendMail";
const GRAPH_REJECTIONS = new Set([400, 401, 403, 404, 405, 413, 415, 422, 429]);

export function createOutlookMailer(env, fetcher = globalThis.fetch) {
  const address = (env.OUTLOOK_SENDER_EMAIL || "").trim();
  const clientId = (env.OUTLOOK_CLIENT_ID || "").trim();
  let refreshToken = (env.OUTLOOK_REFRESH_TOKEN || "").trim();
  const configured = Boolean(address && clientId && refreshToken);
  let cachedToken, pendingRefresh;

  async function refreshAccessToken() {
    const signal = AbortSignal.timeout(8000);
    try {
      const response = await fetcher(`${OUTLOOK_AUTHORITY}/token`, {
        method: "POST",
        redirect: "error",
        signal,
        body: new URLSearchParams({
          client_id: clientId,
          grant_type: "refresh_token",
          refresh_token: refreshToken,
          scope: OUTLOOK_SCOPE,
        }),
      });
      if (!response.ok) {
        void response.body?.cancel().catch(() => {});
        throw new MailDeliveryError(response.status >= 500 ? "unavailable" : "authorization",
          true, "token", response.status);
      }
      const token = await response.json();
      if (typeof token.access_token !== "string" || !token.access_token ||
          !Number.isFinite(token.expires_in) || token.expires_in <= 0) {
        throw new MailDeliveryError("authorization", true, "token");
      }
      if (typeof token.refresh_token === "string" && token.refresh_token) refreshToken = token.refresh_token;
      cachedToken = {
        value: token.access_token,
        expiresAt: Date.now() + token.expires_in * 1000 - 60000,
      };
      return cachedToken;
    } catch (error) {
      if (error instanceof MailDeliveryError) throw error;
      // No Graph send request has been made.
      throw new MailDeliveryError(signal.aborted ? "timeout" : "connection", true, "token");
    }
  }

  function accessToken() {
    if (cachedToken?.expiresAt > Date.now()) return cachedToken;
    pendingRefresh ??= refreshAccessToken().finally(() => { pendingRefresh = undefined; });
    return pendingRefresh;
  }

  return {
    configured,
    async send({ to, subject, text }) {
      if (!configured) throw new MailDeliveryError("configuration", true, "token");
      const token = await accessToken();
      const signal = AbortSignal.timeout(8000);
      let response;
      try {
        response = await fetcher(SEND_URL, {
          method: "POST",
          redirect: "error",
          signal,
          headers: { Authorization: `Bearer ${token.value}`, "Content-Type": "application/json" },
          body: JSON.stringify({
            message: {
              from: { emailAddress: { address } },
              toRecipients: [{ emailAddress: { address: to } }],
              subject,
              body: { contentType: "Text", content: text },
            },
          }),
        });
      } catch {
        throw new MailDeliveryError(signal.aborted ? "timeout" : "connection", false, "send");
      }
      // The HTTP status determines the outcome. Discard any provider error body.
      void response.body?.cancel().catch(() => {});
      if (response.status === 202) return 202;
      if (response.status === 401 && cachedToken === token) cachedToken = undefined;
      if (GRAPH_REJECTIONS.has(response.status)) {
        const category = response.status === 429 ? "rate_limit" : "rejected";
        throw new MailDeliveryError(category, true, "send", response.status);
      }
      // A gateway/server error can occur after Graph has queued the message.
      throw new MailDeliveryError("unknown", false, "send", response.status);
    },
  };
}
