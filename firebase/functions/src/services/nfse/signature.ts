/**
 * XMLDSig enveloped signature (RSA-SHA1, C14N), as the national system asks
 * for the DPS and the events. Same settings that issued a real nota in the spike.
 */

import { SignedXml } from 'xml-crypto';

const C14N = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315';

/** Signs [node] (infDPS, infPedReg) and appends the Signature to [root]. */
export function signXml(xml: string, keyPem: string, certPem: string, node: string, root: string): string {
  const sig = new SignedXml({
    privateKey: keyPem,
    publicCert: certPem,
    canonicalizationAlgorithm: C14N,
    signatureAlgorithm: 'http://www.w3.org/2000/09/xmldsig#rsa-sha1',
  });
  sig.addReference({
    xpath: `//*[local-name(.)='${node}']`,
    transforms: ['http://www.w3.org/2000/09/xmldsig#enveloped-signature', C14N],
    digestAlgorithm: 'http://www.w3.org/2000/09/xmldsig#sha1',
  });
  sig.computeSignature(xml, { location: { reference: `//*[local-name(.)='${root}']`, action: 'append' } });
  return `<?xml version="1.0" encoding="UTF-8"?>${sig.getSignedXml()}`;
}

/** Checks a signature made by [certPem] (tests and self-check before sending). */
export function verifyXmlSignature(signedXml: string, certPem: string): boolean {
  const match = signedXml.match(/<Signature[\s\S]*<\/Signature>/);
  if (!match) return false;
  const verifier = new SignedXml({ publicCert: certPem });
  verifier.loadSignature(match[0]);
  try {
    return verifier.checkSignature(signedXml);
  } catch {
    return false;
  }
}

/** The holder certificate (first PEM block of the chain). */
export function leafOf(chainPem: string): string {
  const match = chainPem.match(/-----BEGIN CERTIFICATE-----[\s\S]+?-----END CERTIFICATE-----/);
  if (!match) throw new Error('No certificate in the chain');
  return `${match[0]}\n`;
}
