// A social/SSO login's Auth0 subject is "<connection>|<id>" where the
// connection is not the email-password database ("auth0"). Dev-bypass ids
// have no "|" and are treated as non-social (full edit).
export function isSocial(sub: string): boolean {
  return sub.includes("|") && !sub.startsWith("auth0|");
}
