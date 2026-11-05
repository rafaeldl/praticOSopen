/**
 * Descriptions printed in the DANFSe for the coded fields, as listed in
 * Anexo I of the NFS-e layout (leiaute DPS/NFS-e 1.01). NT 008/2026 says to
 * print the description, not the code.
 */

export const TP_AMB: Record<string, string> = { '1': 'Produção', '2': 'Homologação' };

export const AMB_GER: Record<string, string> = {
  '1': 'Sistema Próprio do Município',
  '2': 'Sefin Nacional NFS-e',
};

export const TP_EMIT: Record<string, string> = { '1': 'Prestador', '2': 'Tomador', '3': 'Intermediário' };

export const C_STAT: Record<string, string> = {
  '100': 'NFS-e Gerada',
  '101': 'NFS-e de Substituição Gerada',
  '102': 'NFS-e de Decisão Judicial ou Administrativa',
  '103': 'NFS-e Avulsa',
  '107': 'NFS-e MEI',
};

export const FIN_NFSE: Record<string, string> = {
  '0': 'NFS-e regular',
  '1': 'NFS-e de crédito',
  '2': 'NFS-e de débito',
};

export const OP_SIMP_NAC: Record<string, string> = {
  '1': 'Não Optante',
  '2': 'Optante - Microempreendedor Individual (MEI)',
  '3': 'Optante - Microempresa ou Empresa de Pequeno Porte (ME/EPP)',
};

export const REG_AP_TRIB_SN: Record<string, string> = {
  '1': 'Regime de apuração dos tributos federais e municipal pelo Simples Nacional',
  '2': 'Regime de apuração dos tributos federais pelo SN e o ISSQN pela NFS-e conforme respectiva legislação municipal do tributo',
  '3': 'Regime de apuração dos tributos federais e municipal pela NFS-e conforme respectivas legislações federal e municipal de cada tributo',
};

export const REG_ESP_TRIB: Record<string, string> = {
  '0': 'Nenhum',
  '1': 'Ato Cooperado (Cooperativa)',
  '2': 'Estimativa',
  '3': 'Microempresa Municipal',
  '4': 'Notário ou Registrador',
  '5': 'Profissional Autônomo',
  '6': 'Sociedade de Profissionais',
  '9': 'Outros',
};

export const TRIB_ISSQN: Record<string, string> = {
  '1': 'Operação Tributável',
  '2': 'Imunidade',
  '3': 'Exportação de Serviço',
  '4': 'Não Incidência',
};

export const TP_IMUNIDADE: Record<string, string> = {
  '0': 'Imunidade (tipo não informado na nota de origem)',
  '1': 'Patrimônio, renda ou serviços, uns dos outros',
  '2': 'Entidades religiosas e templos de qualquer culto',
  '3': 'Partidos políticos, entidades sindicais, educação e assistência social',
  '4': 'Livros, jornais, periódicos e o papel destinado a sua impressão',
  '5': 'Fonogramas e videofonogramas musicais produzidos no Brasil',
};

export const TP_SUSP: Record<string, string> = {
  '1': 'Exigibilidade Suspensa por Decisão Judicial',
  '2': 'Exigibilidade Suspensa por Processo Administrativo',
};

export const TP_BM: Record<string, string> = {
  '1': 'Isenção',
  '2': 'Redução da BC em percentual',
  '3': 'Redução da BC em valor',
  '4': 'Alíquota Diferenciada',
};

export const TP_RET_ISSQN: Record<string, string> = {
  '1': 'Não Retido',
  '2': 'Retido pelo Tomador',
  '3': 'Retido pelo Intermediário',
};

export const TP_RET_PIS_COFINS: Record<string, string> = {
  '0': 'PIS/COFINS/CSLL Não Retidos',
  '1': 'PIS/COFINS Retido',
  '2': 'PIS/COFINS Não Retido',
  '3': 'PIS/COFINS/CSLL Retidos',
  '4': 'PIS/COFINS Retidos, CSLL Não Retido',
  '5': 'PIS Retido, COFINS/CSLL Não Retido',
  '6': 'COFINS Retido, PIS/CSLL Não Retido',
  '7': 'PIS Não Retido, COFINS/CSLL Retidos',
  '8': 'PIS/COFINS Não Retidos, CSLL Retido',
  '9': 'COFINS Não Retido, PIS/CSLL Retidos',
};

/** UF by the first two digits of the IBGE city code. */
export const UF_BY_IBGE_PREFIX: Record<string, string> = {
  '11': 'RO', '12': 'AC', '13': 'AM', '14': 'RR', '15': 'PA', '16': 'AP', '17': 'TO',
  '21': 'MA', '22': 'PI', '23': 'CE', '24': 'RN', '25': 'PB', '26': 'PE', '27': 'AL', '28': 'SE', '29': 'BA',
  '31': 'MG', '32': 'ES', '33': 'RJ', '35': 'SP',
  '41': 'PR', '42': 'SC', '43': 'RS',
  '50': 'MS', '51': 'MT', '52': 'GO', '53': 'DF',
};

/** Description of a code, or the code itself when the table doesn't know it. */
export function describe(table: Record<string, string>, code: string | null): string | null {
  if (code == null || code === '') return null;
  return table[code] ?? code;
}
