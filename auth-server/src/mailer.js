import nodemailer from "nodemailer";
import { MailDeliveryError } from "./mail-delivery-error.js";
import { createOutlookMailer } from "./outlook-mailer.js";

const REPLY_COMMANDS = new Set(["EHLO", "HELO", "LHLO", "MAIL FROM", "RCPT TO", "DATA"]);

function smtpFailure(error) {
  const status = Number.isInteger(error?.responseCode) && error.responseCode >= 400 &&
    error.responseCode <= 599 ? error.responseCode : undefined;
  if (error?.code === "EAUTH") return new MailDeliveryError("authorization", true, "smtp", status);
  if (status && REPLY_COMMANDS.has(error.command)) {
    return new MailDeliveryError("rejected", true, "smtp", status);
  }
  // Nodemailer can report CONN for socket errors after DATA. Only a proven
  // connection/setup failure is safe to retry via the other provider.
  const beforeSubmission = error?.syscall === "connect" || ["EDNS", "ETLS"].includes(error?.code);
  if (error?.code === "ETIMEDOUT") return new MailDeliveryError("timeout", beforeSubmission, "smtp");
  if (beforeSubmission || ["ECONNECTION", "ESOCKET", "ECONNRESET"].includes(error?.code)) {
    return new MailDeliveryError("connection", beforeSubmission, "smtp");
  }
  return new MailDeliveryError("unknown", false, "smtp");
}

export function createMailer(env = process.env, transportFactory = nodemailer.createTransport,
  { fetcher = globalThis.fetch, logger = console } = {}) {
  const user = (env.SMTP_USER || "").trim();
  const password = env.SMTP_PASS || "";
  const transport = user && password ? transportFactory({
    host: env.SMTP_HOST || "smtp.qq.com",
    port: Number(env.SMTP_PORT || 465),
    secure: (env.SMTP_SECURE || "true") === "true",
    requireTLS: true,
    auth: { user, pass: password },
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 15000,
    dnsTimeout: 10000,
    tls: { minVersion: "TLSv1.2" },
    disableFileAccess: true,
    disableUrlAccess: true,
  }) : null;
  const outlook = createOutlookMailer(env, fetcher);
  const qq = {
    name: "qq",
    configured: Boolean(transport),
    async send({ to, subject, text }) {
      let result;
      try {
        result = await transport.sendMail({
          from: { name: "Global Village", address: user },
          to: { address: to, name: "" },
          subject,
          text,
        });
      } catch (error) {
        throw smtpFailure(error);
      }
      if (result?.accepted?.length) return;
      if (result?.rejected?.length) throw new MailDeliveryError("rejected", true, "smtp");
      throw new MailDeliveryError("unknown", false, "smtp");
    },
  };
  const graph = { name: "outlook", ...outlook };
  const providers = (env.MAIL_PRIMARY_PROVIDER?.trim().toLowerCase() === "outlook" ?
    [graph, qq] : [qq, graph]).filter((provider) => provider.configured);

  async function send(mail, requestId, logLabel) {
    let failure = new MailDeliveryError("configuration", true, "configuration");
    for (const provider of providers) {
      try {
        const status = await provider.send(mail);
        logger.info(logLabel, { requestId, provider: provider.name, outcome: "accepted", status });
        return;
      } catch (error) {
        failure = error instanceof MailDeliveryError ? error : new MailDeliveryError("unknown", false, "send");
        logger.warn(logLabel, {
          requestId, provider: provider.name, outcome: failure.definitive ? "failed" : "unknown",
          category: failure.category, phase: failure.phase, status: failure.status,
        });
        if (!failure.definitive) break;
      }
    }
    throw failure;
  }

  return {
    configured: providers.length > 0,
    async verify() {
      if (!transport) throw new Error("Configure SMTP_USER and SMTP_PASS first.");
      await transport.verify();
    },
    async sendCode(email, code, requestId) {
      const mail = {
        to: email,
        subject: "Global Village - Password reset code / 密码重置验证码",
        text: `Your Global Village password reset code is: ${code}\n\n` +
          "This code expires in 10 minutes and can only be used once. " +
          "Do not share it with anyone. If you did not request a password reset, ignore this email.\n\n" +
          `你的密码重置验证码是：${code}\n有效期 10 分钟，仅可使用一次。请勿向他人透露；如非本人操作，请忽略此邮件。`,
      };
      await send(mail, requestId, "Password reset email");
    },
    async sendRegistrationCode(email, code, requestId) {
      await send({
        to: email,
        subject: "Global Village - Registration verification code / 注册邮箱验证码",
        text: `Your Global Village registration verification code is: ${code}\n\n` +
          "This code expires in 10 minutes and can only be used once. " +
          "Do not share it. If you did not request registration, ignore this email.\n\n" +
          `你的 Global Village 注册邮箱验证码是：${code}\n有效期 10 分钟，仅可使用一次。请勿分享。如非本人操作，请忽略此邮件。`,
      }, requestId, "Registration verification email");
    },
  };
}
