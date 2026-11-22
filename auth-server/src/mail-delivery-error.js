// Only controlled categories and numeric protocol statuses are safe to log.
export class MailDeliveryError extends Error {
  constructor(category, definitive, phase, status) {
    super("Password reset email submission failed.");
    this.category = category;
    this.definitive = definitive;
    this.phase = phase;
    this.status = status;
  }
}
