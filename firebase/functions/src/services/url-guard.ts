/**
 * URL Guard
 * SSRF protection for server-side fetches of user-supplied URLs.
 * Rejects loopback, private, link-local, CGNAT, multicast, reserved and
 * cloud metadata targets (IPv4 and IPv6), including after DNS resolution.
 */

import { promises as dns } from 'dns';
import { BlockList, isIP } from 'net';

// ============================================================================
// Configuration
// ============================================================================

const BLOCKED_HOSTNAMES = new Set([
  'localhost',
  'metadata',
  'metadata.google.internal',
  'metadata.goog',
]);

const BLOCKED_HOSTNAME_SUFFIXES = ['.localhost', '.internal', '.local'];

const blockList = new BlockList();

// IPv4
blockList.addSubnet('0.0.0.0', 8, 'ipv4'); // "this" network
blockList.addSubnet('10.0.0.0', 8, 'ipv4'); // private
blockList.addSubnet('100.64.0.0', 10, 'ipv4'); // CGNAT
blockList.addSubnet('127.0.0.0', 8, 'ipv4'); // loopback
blockList.addSubnet('169.254.0.0', 16, 'ipv4'); // link-local (incl. 169.254.169.254 metadata)
blockList.addSubnet('172.16.0.0', 12, 'ipv4'); // private
blockList.addSubnet('192.0.0.0', 24, 'ipv4'); // IETF protocol assignments
blockList.addSubnet('192.0.2.0', 24, 'ipv4'); // TEST-NET-1
blockList.addSubnet('192.88.99.0', 24, 'ipv4'); // 6to4 relay anycast
blockList.addSubnet('192.168.0.0', 16, 'ipv4'); // private
blockList.addSubnet('198.18.0.0', 15, 'ipv4'); // benchmarking
blockList.addSubnet('198.51.100.0', 24, 'ipv4'); // TEST-NET-2
blockList.addSubnet('203.0.113.0', 24, 'ipv4'); // TEST-NET-3
blockList.addSubnet('224.0.0.0', 4, 'ipv4'); // multicast
blockList.addSubnet('240.0.0.0', 4, 'ipv4'); // reserved + broadcast

// IPv6
blockList.addAddress('::', 'ipv6'); // unspecified
blockList.addAddress('::1', 'ipv6'); // loopback
blockList.addSubnet('64:ff9b::', 96, 'ipv6'); // NAT64 (embeds IPv4)
blockList.addSubnet('64:ff9b:1::', 48, 'ipv6'); // local-use NAT64
blockList.addSubnet('100::', 64, 'ipv6'); // discard-only
blockList.addSubnet('2001::', 23, 'ipv6'); // IETF protocol assignments (incl. Teredo)
blockList.addSubnet('2001:db8::', 32, 'ipv6'); // documentation
blockList.addSubnet('2002::', 16, 'ipv6'); // 6to4 (embeds IPv4)
blockList.addSubnet('fc00::', 7, 'ipv6'); // unique local (incl. fd00:ec2::254 metadata)
blockList.addSubnet('fe80::', 10, 'ipv6'); // link-local
blockList.addSubnet('fec0::', 10, 'ipv6'); // site-local (deprecated)
blockList.addSubnet('ff00::', 8, 'ipv6'); // multicast

// ============================================================================
// Public API
// ============================================================================

export class BlockedUrlError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BlockedUrlError';
  }
}

/**
 * Returns true when the IP literal must not be reached from the server.
 * Unparseable input is treated as blocked.
 */
export function isBlockedIp(ip: string): boolean {
  const address = stripBrackets(ip);
  const version = isIP(address);
  if (version === 4) {
    return blockList.check(address, 'ipv4');
  }
  if (version === 6) {
    const embeddedV4 = extractIPv4FromMappedIPv6(address);
    if (embeddedV4) {
      return isBlockedIp(embeddedV4);
    }
    return blockList.check(address, 'ipv6');
  }
  return true;
}

/**
 * Validates that a URL is http(s) and that its host (and every address it
 * resolves to) is public. Throws BlockedUrlError otherwise.
 */
export async function assertPublicHttpUrl(rawUrl: string | URL): Promise<URL> {
  let url: URL;
  try {
    url = rawUrl instanceof URL ? rawUrl : new URL(rawUrl);
  } catch {
    throw new Error(`Invalid URL: ${rawUrl}`);
  }

  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error(`Invalid protocol: ${url.protocol}. Only http: and https: are supported.`);
  }

  if (url.username || url.password) {
    throw new BlockedUrlError('URLs with embedded credentials are not allowed');
  }

  const hostname = stripBrackets(url.hostname).toLowerCase().replace(/\.$/, '');
  if (!hostname) {
    throw new BlockedUrlError('URL host is empty');
  }

  if (
    BLOCKED_HOSTNAMES.has(hostname) ||
    BLOCKED_HOSTNAME_SUFFIXES.some((suffix) => hostname.endsWith(suffix))
  ) {
    throw new BlockedUrlError(`URL host is not allowed: ${hostname}`);
  }

  if (isIP(hostname)) {
    if (isBlockedIp(hostname)) {
      throw new BlockedUrlError(`URL points to a non-public address: ${hostname}`);
    }
    return url;
  }

  let addresses: { address: string }[];
  try {
    addresses = await dns.lookup(hostname, { all: true, verbatim: true });
  } catch {
    throw new Error(`Could not resolve host: ${hostname}`);
  }

  if (addresses.length === 0) {
    throw new Error(`Could not resolve host: ${hostname}`);
  }

  const blocked = addresses.find((entry) => isBlockedIp(entry.address));
  if (blocked) {
    throw new BlockedUrlError(`URL host resolves to a non-public address: ${hostname}`);
  }

  return url;
}

// ============================================================================
// Helper Functions
// ============================================================================

function stripBrackets(host: string): string {
  return host.startsWith('[') && host.endsWith(']') ? host.slice(1, -1) : host;
}

/**
 * Extracts the IPv4 address from IPv4-mapped (::ffff:a.b.c.d / ::ffff:xxxx:xxxx)
 * and IPv4-compatible (::a.b.c.d) IPv6 addresses.
 */
function extractIPv4FromMappedIPv6(address: string): string | null {
  const lower = address.toLowerCase();

  const dotted = lower.match(/^(?:::ffff:|::ffff:0:|::)(\d{1,3}(?:\.\d{1,3}){3})$/);
  if (dotted) {
    return dotted[1];
  }

  const hex = lower.match(/^(?:::ffff:|::ffff:0:|::)([0-9a-f]{1,4}):([0-9a-f]{1,4})$/);
  if (hex) {
    const high = parseInt(hex[1], 16);
    const low = parseInt(hex[2], 16);
    return [high >> 8, high & 0xff, low >> 8, low & 0xff].join('.');
  }

  return null;
}
