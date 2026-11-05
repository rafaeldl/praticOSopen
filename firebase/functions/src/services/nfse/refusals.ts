/**
 * Government refusal codes in plain words (spec §5.4). The group tells the
 * issue sheet what to open: the "Para" fields, the emitter, or the
 * certificate. Unknown codes fall in `other` and show the government's text.
 * The table grows with the pilot.
 */

import type { GovMessage } from './sefin-client';

export type RefusalGroup = 'customerData' | 'emitterSetup' | 'certificate' | 'other';

interface RefusalEntry {
  group: RefusalGroup;
  pt: string;
  en: string;
  es: string;
}

const T = (group: RefusalGroup, pt: string, en: string, es: string): RefusalEntry => ({ group, pt, en, es });

export const REFUSALS: Record<string, RefusalEntry> = {
  // Recipient (customer) data
  E0204: T('customerData', 'Falta o CPF ou CNPJ do cliente.', "The customer's CPF or CNPJ is missing.", 'Falta el CPF o CNPJ del cliente.'),
  E0237: T('customerData', 'Falta o endereço do cliente.', "The customer's address is missing.", 'Falta la dirección del cliente.'),
  E0240: T('customerData', 'O CEP do cliente não é da cidade dele. Confira o CEP da rua.', "The customer's CEP does not belong to their city. Check the street's CEP.", 'El CEP del cliente no es de su ciudad. Revise el CEP de la calle.'),
  // Emitter setup
  E0116: T('emitterSetup', 'Falta a inscrição municipal deste CNPJ.', 'This CNPJ needs its municipal registration.', 'Falta la inscripción municipal de este CNPJ.'),
  E0120: T('emitterSetup', 'Este CNPJ não usa inscrição municipal. Tire a inscrição do CNPJ.', 'This CNPJ has no municipal registration. Remove it.', 'Este CNPJ no usa inscripción municipal. Quítela.'),
  E0119: T('emitterSetup', 'Este CNPJ não está liberado para emitir nota na cidade.', 'This CNPJ is not enabled to issue notas in the city.', 'Este CNPJ no está habilitado para emitir notas en la ciudad.'),
  E0312: T('emitterSetup', 'A cidade não aceita este serviço. Escolha o serviço da nota de novo.', 'The city does not accept this service. Pick the service again.', 'La ciudad no acepta este servicio. Elija el servicio de nuevo.'),
  E0315: T('emitterSetup', 'A cidade não usa o código municipal do serviço. Tire o código.', 'The city does not use a municipal code for this service.', 'La ciudad no usa código municipal para este servicio.'),
  E0162: T('emitterSetup', 'O regime deste CNPJ está errado (MEI ou Simples).', "This CNPJ's regime is wrong (MEI or Simples).", 'El régimen de este CNPJ está mal (MEI o Simples).'),
  E0676: T('emitterSetup', 'Este CNPJ é MEI e foi tratado como Simples. Confira o regime.', 'This CNPJ is MEI but was treated as Simples. Check the regime.', 'Este CNPJ es MEI y se trató como Simples. Revise el régimen.'),
  E0712: T('emitterSetup', 'Este CNPJ é do Simples e foi tratado como MEI. Confira o regime.', 'This CNPJ is Simples but was treated as MEI. Check the regime.', 'Este CNPJ es Simples y se trató como MEI. Revise el régimen.'),
  E0316: T('emitterSetup', 'O código NBS do serviço não existe.', "The service's NBS code does not exist.", 'El código NBS del servicio no existe.'),
  // Certificate
  E0718: T('certificate', 'O certificado é de outro CNPJ. Envie o certificado deste CNPJ.', "The certificate belongs to another CNPJ. Send this CNPJ's certificate.", 'El certificado es de otro CNPJ. Envíe el de este CNPJ.'),
};

export interface Refusal {
  code: string | null;
  group: RefusalGroup;
  /** What the app shows (pt/en/es); for `other`, the government's own text. */
  message: { pt: string; en: string; es: string };
  /** Government text, at most 200 characters (log and detail; never the XML or customer data). */
  govText: string | null;
}

/** HTTP status that mean the certificate was refused in the TLS/auth step. */
const CERTIFICATE_STATUS = [401, 403, 495, 496];

/** The first refusal the app can act on, else the first one. */
export function explainRefusal(errors: GovMessage[], status?: number): Refusal {
  const known = errors.find((e) => e.code && REFUSALS[e.code]);
  const first = known ?? errors[0] ?? { code: null, text: null };
  const govText = first.text ? first.text.slice(0, 200) : null;
  const entry = first.code ? REFUSALS[first.code] : undefined;
  if (entry) return { code: first.code, group: entry.group, message: { pt: entry.pt, en: entry.en, es: entry.es }, govText };
  if (!first.code && status && CERTIFICATE_STATUS.includes(status)) {
    return {
      code: `HTTP${status}`,
      group: 'certificate',
      message: {
        pt: 'O governo recusou o certificado. Confira se ele é deste CNPJ e está na validade.',
        en: 'The government refused the certificate. Check it belongs to this CNPJ and is valid.',
        es: 'El gobierno rechazó el certificado. Revise que sea de este CNPJ y esté vigente.',
      },
      govText,
    };
  }
  const text = govText ?? 'sem detalhe';
  return {
    code: first.code,
    group: 'other',
    message: { pt: `O governo recusou a nota: ${text}`, en: `The government refused the nota: ${text}`, es: `El gobierno rechazó la nota: ${text}` },
    govText,
  };
}

/** One line for the log: codes and the government's text, cut. */
export function refusalLog(errors: GovMessage[]): string {
  return errors.map((e) => `${e.code ?? '?'}: ${(e.text ?? '').slice(0, 200)}`).join(' | ');
}
