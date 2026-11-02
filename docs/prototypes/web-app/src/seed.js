// Fictional data only. Names, phones and plates were invented for this prototype.
import { addBusinessDays, at, NOW, today } from './format.js'

const when = (spec) => (spec ? at(addBusinessDays(spec[0]), spec[1] || '09:00').toISOString() : null)

function catalogMap(list) {
  return Object.fromEntries(list.map(([key, kind, name, price]) => [key, { key, kind, name, price }]))
}

// Older paid orders behind the Financeiro months. They are not full orders, so they stay out of every other screen.
function makeHistory(cfg, catalog, orders) {
  const all = Object.values(catalog)
  const svc = all.filter((c) => c.kind === 'service'); const prt = all.filter((c) => c.kind === 'part')
  const ids = cfg.customers.map((c) => c[0])
  const methods = ['pix', 'pix', 'card', 'cash', 'pix', 'transfer']
  const rows = []
  cfg.volume.forEach((count, m) => {
    for (let i = 0; i < count; i++) {
      const at = new Date(NOW.getFullYear(), NOW.getMonth() - m, 1 + (i * 7 + m * 3) % 27, 8, 40)
      if (at.getDay() === 0) at.setDate(at.getDate() + 1)
      const paidAt = new Date(at); paidAt.setDate(at.getDate() + i % 4)
      if (paidAt >= today()) continue
      const s = svc[(i * 3 + m) % svc.length]; const p = i % 3 === 2 ? null : prt[(i * 5 + m) % prt.length]
      const items = [{ name: s.name, value: s.price }, ...(p ? [{ name: p.name, value: p.price }] : [])]
      rows.push({
        id: `h${m}-${i}`, at: at.toISOString(), paidAt: paidAt.toISOString(), customerId: ids[(i * 2 + i % 5 + m) % ids.length], method: methods[(i + m) % methods.length],
        items, services: s.price, parts: p?.price || 0, total: s.price + (p?.price || 0),
      })
    }
  })
  rows.sort((a, b) => new Date(b.at) - new Date(a.at))
  let number = Math.min(...orders.map((o) => o.number))
  rows.forEach((r) => { r.number = --number })
  return rows
}

function build(cfg) {
  const catalog = catalogMap(cfg.catalog)
  const customers = cfg.customers.map(([id, name, phone, address, devices, kind]) => ({
    id, name, phone, address, kind: kind || 'person',
    devices: devices.map(([did, label, tag]) => ({ id: did, label, tag })),
  }))
  let seq = 1
  const orders = cfg.orders.map((s) => {
    const items = (s.it || []).map(([key, qty = 1, price]) => {
      const c = catalog[key]
      return { id: 'i' + seq++, kind: c.kind, name: c.name, qty, price: price ?? c.price, ai: false }
    })
    return {
      id: s.n, number: s.n, status: s.st, customerId: s.c, deviceId: s.d || null,
      request: s.req || '', items, discount: s.disc || 0,
      payments: (s.pay || []).map(([amount, method, day]) => ({
        id: 'p' + seq++, amount, method, at: when([day, '11:20']),
      })),
      photos: (s.ph || []).map((label) => ({ id: 'f' + seq++, label, src: null })),
      comments: (s.cm || []).map(([author, text, day]) => ({ id: 'c' + seq++, author, text, at: when([day, '10:05']) })),
      assignee: s.who || null,
      scheduledAt: when(s.sched), duration: s.dur || 60, dueAt: when(s.due),
      hold: s.hold ? { reason: s.hold[0], since: when([s.hold[1]]) } : null,
      createdAt: when([s.made ?? -1, '08:40']), sentAt: s.sent != null ? when([s.sent, '16:10']) : null,
      chargedAt: null, address: s.addr || null,
    }
  })
  customers.forEach((c, i) => {
    if (!c.address && i % 4 !== 2) c.address = `Rua das Palmeiras, ${120 + i * 7}`
    c.email = i % 5 === 3 ? '' : `${c.name.normalize('NFD').replace(/[^a-zA-Z ]/g, '').trim().toLowerCase().replace(/ +/g, '.')}@exemplo.com.br`
    c.zip = c.address && i % 6 !== 4 ? `89${String(100 + i).padStart(3, '0')}-000` : ''
  })
  orders.forEach((o, i) => { o.openedAt = o.sentAt && i % 2 ? o.sentAt : null; o.approvedAt = null })
  const owing = (o) => o.items.reduce((s, x) => s + x.qty * x.price, 0) - o.discount - o.payments.reduce((s, p) => s + p.amount, 0)
  const charges = orders.filter((o) => o.status === 'done' && owing(o) > 0).flatMap((o, j) => (j % 3 === 2 ? [] : [{
    id: 'ch' + o.id, customerId: o.customerId, orderIds: [o.id], value: owing(o), status: 'open',
    createdAt: when([-2, '09:30']), openedAt: j % 3 === 0 ? when([-1, '18:15']) : null,
  }]))
  const servicesValue = (o) => o.items.filter((x) => x.kind === 'service').reduce((s, x) => s + x.qty * x.price, 0)
  const partsValue = (o) => o.items.filter((x) => x.kind === 'part').reduce((s, x) => s + x.qty * x.price, 0)
  const invoices = orders.filter((o) => o.status === 'done' && servicesValue(o) > 0).flatMap((o, k) => {
    if (k % 3 === 2 || k % 3 === 1 && k > 1) return []
    const s = servicesValue(o)
    const value = Math.round((s - o.discount * s / (s + partsValue(o))) * 100) / 100
    const failed = k === 1
    return [{
      id: 'nf' + o.id, number: failed ? null : 2041 + k, orderIds: [o.id], customerId: o.customerId, value,
      status: failed ? 'error' : 'issued', at: o.createdAt,
      error: failed ? 'A prefeitura recusou: o código do serviço não vale para esta cidade.' : null,
    }]
  })
  return { ...cfg.meta, catalog: Object.values(catalog), customers, orders, charges, invoices, history: makeHistory(cfg, catalog, orders), nextNumber: cfg.nextNumber }
}

const auto = {
  meta: {
    company: 'Oficina Vale Verde', owner: 'Carla', trade: 'Oficina',
    labels: { device: 'Veículo', deviceQ: 'Qual veículo?', deviceNone: 'Nenhum veículo', deviceNew: 'placa', tagLabel: 'Placa', place: 'na oficina', visit: 'Quando chega' },
    team: ['Carla', 'Márcio', 'Júlio', 'Tainá'],
    sample: 'troca de óleo e filtro do Onix da Márcia',
  },
  volume: [46, 41, 52, 44, 38, 47],
  nextNumber: 1211,
  catalog: [
    ['oleo', 'service', 'Troca de óleo e filtro', 90], ['alinh', 'service', 'Alinhamento e balanceamento', 140],
    ['freio', 'service', 'Revisão de freios', 180], ['diag', 'service', 'Diagnóstico eletrônico', 120],
    ['correia', 'service', 'Troca de correia dentada', 380], ['amort', 'service', 'Troca de amortecedores', 260],
    ['arc', 'service', 'Higienização do ar-condicionado', 110], ['embr', 'service', 'Troca de embreagem', 450],
    ['rev', 'service', 'Revisão de 40 mil km', 320], ['bat', 'service', 'Teste de bateria e alternador', 60],
    ['l5w', 'part', 'Óleo 5W30, litro', 42], ['fol', 'part', 'Filtro de óleo', 38], ['pas', 'part', 'Pastilha de freio dianteira', 165],
    ['kit', 'part', 'Kit correia dentada', 410], ['amd', 'part', 'Amortecedor dianteiro', 290], ['bta', 'part', 'Bateria 60 Ah', 420],
    ['far', 'part', 'Filtro de ar', 56], ['flu', 'part', 'Fluido de freio DOT 4', 34], ['vel', 'part', 'Jogo de velas', 120],
    ['pal', 'part', 'Palheta do limpador', 48],
  ],
  customers: [
    ['a1', 'Márcia Teles', '(47) 90000-0118', 'Rua dos Ipês, 88', [['a1v1', 'Chevrolet Onix 2020', 'RTM4E51'], ['a1v2', 'Hyundai HB20 2017', 'QIJ7B20']]],
    ['a2', 'Joel Fagundes', '(47) 90000-0127', '', [['a2v1', 'Fiat Strada 2018', 'QHY2C44']]],
    ['a3', 'Bruna Caldeira', '(47) 90000-0133', '', [['a3v1', 'Renault Kwid 2022', 'SDE1F09']]],
    ['a4', 'Transportes Serra Azul', '(47) 90000-0141', 'Rod. BR-470, km 52', [['a4v1', 'Mercedes Sprinter 2019', 'QJK6A31'], ['a4v2', 'Renault Master 2021', 'RKL3D18'], ['a4v3', 'Fiat Ducato 2016', 'MLS9G72']], 'company'],
    ['a5', 'Otávio Lemes', '(47) 90000-0156', '', [['a5v1', 'Toyota Corolla 2016', 'MKT8H05']]],
    ['a6', 'Neide Prado', '(47) 90000-0162', '', [['a6v1', 'Volkswagen Gol 2013', 'MIB4J67']]],
    ['a7', 'Wesley Moura', '(47) 90000-0179', '', [['a7v1', 'Honda Civic 2015', 'MHZ5K33']]],
    ['a8', 'Padaria Pão Nosso', '(47) 90000-0184', 'Av. Brasil, 310', [['a8v1', 'Fiat Fiorino 2020', 'RAP0L26']], 'company'],
    ['a9', 'Silvana Rocha', '(47) 90000-0193', '', [['a9v1', 'Hyundai Creta 2021', 'RJD2M81']]],
    ['a10', 'Ivo Cardim', '(47) 90000-0205', '', [['a10v1', 'Chevrolet S10 2014', 'MGC7N14']]],
    ['a11', 'Lara Bittencourt', '(47) 90000-0212', '', [['a11v1', 'Volkswagen T-Cross 2023', 'SGF4P90']]],
    ['a12', 'Renato Viana', '(47) 90000-0226', '', [['a12v1', 'Fiat Uno 2012', 'MDF1Q52']]],
    ['a13', 'Cida Fontes', '(47) 90000-0238', '', [['a13v1', 'Fiat Palio 2011', 'MCA3R47']]],
    ['a14', 'Hélio Brandão', '(47) 90000-0241', '', [['a14v1', 'Jeep Renegade 2019', 'QNB8S63']]],
  ],
  orders: [
    { n: 1210, st: 'progress', c: 'a1', d: 'a1v1', who: 'Márcio', req: 'Barulho ao frear e está na hora de trocar o óleo.', it: [['freio'], ['pas'], ['oleo'], ['l5w', 4], ['fol']], due: [0, '17:00'], sched: [0, '08:00'], dur: 180, ph: ['Pastilhas gastas', 'Disco dianteiro'], cm: [['Márcio', 'Disco ainda aguenta, só pastilha mesmo.', 0]], sent: -1 },
    { n: 1209, st: 'approved', c: 'a2', d: 'a2v1', who: 'Júlio', req: 'Puxando para a direita na estrada.', it: [['alinh']], sched: [0, '10:00'], dur: 60, due: [0, '12:00'] },
    { n: 1208, st: 'quote', c: 'a3', d: 'a3v1', req: 'Revisão antes de viajar.', it: [['rev'], ['far'], ['pal', 2]], sent: -3, made: -3 },
    { n: 1207, st: 'progress', c: 'a4', d: 'a4v1', who: 'Márcio', req: 'Correia chegou na quilometragem de troca.', it: [['correia'], ['kit']], due: [-2, '17:00'], sched: [-2, '08:00'], dur: 240, made: -3, cm: [['Carla', 'Serra Azul paga no fim do mês, com as outras.', -2]] },
    { n: 1206, st: 'approved', c: 'a5', d: 'a5v1', who: 'Tainá', req: 'Ar-condicionado com cheiro ruim.', it: [['arc'], ['far']], sched: [0, '14:00'], dur: 60, due: [0, '16:00'] },
    { n: 1205, st: 'progress', c: 'a6', d: 'a6v1', who: 'Júlio', req: 'Bateria arriando de manhã.', it: [['bat'], ['bta']], hold: ['Esperando peça', -3], due: [-1, '12:00'], sched: [-3, '09:00'], dur: 60, made: -4, cm: [['Júlio', 'Fornecedor prometeu a bateria para hoje à tarde.', 0]] },
    { n: 1204, st: 'done', c: 'a7', d: 'a7v1', who: 'Márcio', req: 'Troca de óleo.', it: [['oleo'], ['l5w', 4], ['fol']], sent: 0, made: -2, sched: [-1, '09:00'] },
    { n: 1203, st: 'done', c: 'a8', d: 'a8v1', who: 'Júlio', req: 'Freio baixo.', it: [['freio'], ['pas'], ['flu']], pay: [[150, 'pix', -2]], sent: -2, made: -4, sched: [-3, '10:00'] },
    { n: 1202, st: 'quote', c: 'a9', d: 'a9v1', req: 'Amortecedor batendo em buraco.', it: [['amort'], ['amd', 2]], sent: -6, made: -6 },
    { n: 1201, st: 'done', c: 'a4', d: 'a4v2', who: 'Tainá', req: 'Revisão de rotina.', it: [['rev'], ['l5w', 6], ['fol'], ['far']], sent: -8, made: -10, sched: [-9, '08:00'] },
    { n: 1200, st: 'done', c: 'a10', d: 'a10v1', who: 'Márcio', req: 'Embreagem patinando.', it: [['embr']], sent: -11, made: -13, sched: [-12, '08:00'] },
    { n: 1199, st: 'approved', c: 'a11', d: 'a11v1', who: 'Márcio', req: 'Primeira revisão fora da concessionária.', it: [['rev']], sched: [1, '09:00'], dur: 120, due: [1, '17:00'] },
    { n: 1198, st: 'approved', c: 'a12', d: 'a12v1', who: null, req: 'Luz da injeção acesa.', it: [['diag']], made: -1 },
    { n: 1197, st: 'approved', c: 'a13', d: 'a13v1', who: null, req: 'Trocar velas e filtro.', it: [['vel'], ['far']], made: -2 },
    { n: 1196, st: 'progress', c: 'a14', d: 'a14v1', who: 'Tainá', req: 'Motor falhando na subida.', it: [['diag'], ['vel']], hold: ['Esperando o cliente aprovar', -1], due: [1, '12:00'], sched: [-1, '13:00'], dur: 90 },
    { n: 1195, st: 'done', c: 'a2', d: 'a2v1', who: 'Júlio', req: 'Troca de óleo.', it: [['oleo'], ['l5w', 4], ['fol']], pay: [[296, 'pix', -5]], sent: -5, made: -6 },
    { n: 1194, st: 'done', c: 'a3', d: 'a3v1', who: 'Tainá', req: 'Palhetas.', it: [['pal', 2]], pay: [[96, 'cash', 0]], made: -2 },
    { n: 1193, st: 'done', c: 'a5', d: 'a5v1', who: 'Márcio', req: 'Alinhamento.', it: [['alinh']], pay: [[140, 'card', 0]], made: -7 },
    { n: 1192, st: 'done', c: 'a1', d: 'a1v2', who: 'Júlio', req: 'Revisão de freios.', it: [['freio'], ['flu']], pay: [[214, 'pix', -12]], made: -14 },
    { n: 1191, st: 'canceled', c: 'a7', d: 'a7v1', req: 'Cliente desistiu do serviço.', it: [['arc']], made: -9 },
    { n: 1190, st: 'done', c: 'a4', d: 'a4v3', who: 'Márcio', req: 'Freios da Ducato.', it: [['freio'], ['pas', 2]], sent: -15, made: -17 },
    { n: 1189, st: 'approved', c: 'a8', d: 'a8v1', who: 'Tainá', req: 'Revisão de rotina da Fiorino.', it: [['rev']], sched: [2, '08:00'], dur: 180 },
    { n: 1188, st: 'approved', c: 'a6', d: 'a6v1', who: 'Márcio', req: 'Alinhamento depois da bateria.', it: [['alinh']], sched: [0, '13:00'], dur: 60 },
    { n: 1187, st: 'quote', c: 'a10', d: 'a10v1', req: 'Pastilhas na S10.', it: [['pas'], ['freio']], made: -1 },
  ],
}

const hvac = {
  meta: {
    company: 'Clima Sul Refrigeração', owner: 'Davi', trade: 'Refrigeração',
    labels: { device: 'Equipamento', deviceQ: 'Qual equipamento?', deviceNone: 'Nenhum equipamento', deviceNew: 'série', tagLabel: 'Série', place: 'no cliente', visit: 'Visita' },
    team: ['Davi', 'Edson', 'Renan', 'Lívia'],
    sample: 'higienização do split da Clínica Bem Cuidar',
  },
  volume: [24, 22, 27, 25, 20, 23],
  nextNumber: 643,
  catalog: [
    ['hig', 'service', 'Higienização de split', 180], ['gas', 'service', 'Carga de gás', 240], ['vis', 'service', 'Visita técnica', 90],
    ['ins', 'service', 'Instalação de split', 520], ['com', 'service', 'Troca de compressor', 650], ['pre', 'service', 'Manutenção preventiva', 280],
    ['cam', 'service', 'Revisão de câmara fria', 480], ['r41', 'part', 'Gás R-410A, kg', 95], ['r13', 'part', 'Gás R-134a, kg', 88],
    ['cap', 'part', 'Capacitor', 45], ['cmp', 'part', 'Compressor 12.000 BTUs', 980], ['ter', 'part', 'Termostato', 130],
    ['pla', 'part', 'Placa eletrônica', 410], ['mot', 'part', 'Motor do ventilador', 360],
  ],
  customers: [
    ['h1', 'Clínica Bem Cuidar', '(48) 90000-0311', 'Rua das Acácias, 120, Centro', [['h1e1', 'Split Midea 12.000 BTUs, recepção', 'MD12-4471'], ['h1e2', 'Split Elgin 18.000 BTUs, sala 2', 'EL18-2093']], 'company'],
    ['h2', 'Mercado Boa Compra', '(48) 90000-0324', 'Av. Beira-Mar, 900', [['h2e1', 'Câmara fria de laticínios', 'CF-0192'], ['h2e2', 'Balcão expositor 3 portas', 'BE-3381']], 'company'],
    ['h3', 'Restaurante Sabor da Terra', '(48) 90000-0335', 'Rua XV de Novembro, 45', [['h3e1', 'Freezer horizontal Metalfrio', 'FZ-7720']], 'company'],
    ['h4', 'Ana Beatriz Lobo', '(48) 90000-0347', 'Rua do Sol, 18, ap. 302', [['h4e1', 'Split LG 9.000 BTUs', 'LG09-5540']]],
    ['h5', 'Hotel Recanto do Lago', '(48) 90000-0352', 'Estrada do Lago, 2000', [['h5e1', 'Split Gree 24.000 BTUs, salão', 'GR24-1187'], ['h5e2', 'Cortina de ar da entrada', 'CA-0451']], 'company'],
    ['h6', 'Academia Movimento', '(48) 90000-0368', 'Rua Pará, 77', [['h6e1', 'Cassete Carrier 36.000 BTUs', 'CR36-0912']], 'company'],
    ['h7', 'Sebastião Dias', '(48) 90000-0379', 'Rua das Gaivotas, 233', [['h7e1', 'Geladeira Consul duplex', 'CN-44018']]],
    ['h8', 'Escritório Nexo Contábil', '(48) 90000-0383', 'Rua Tiradentes, 501, sala 4', [['h8e1', 'Split Samsung 12.000 BTUs', 'SM12-6630']], 'company'],
    ['h9', 'Paula Sarmento', '(48) 90000-0397', 'Rua Marquês, 62', [['h9e1', 'Split Fujitsu 9.000 BTUs', 'FJ09-2284']]],
  ],
  orders: [
    { n: 642, st: 'progress', c: 'h2', d: 'h2e1', who: 'Edson', req: 'Câmara não chega em 2 graus desde ontem.', it: [['cam'], ['ter'], ['r13', 3]], due: [0, '12:00'], sched: [0, '08:00'], dur: 180, addr: 'Av. Beira-Mar, 900', ph: ['Painel da câmara', 'Evaporador com gelo'], cm: [['Edson', 'Evaporador congelado, vou trocar o termostato.', 0]] },
    { n: 641, st: 'approved', c: 'h1', d: 'h1e1', who: 'Renan', req: 'Higienização semestral.', it: [['hig']], sched: [0, '09:00'], dur: 90, addr: 'Rua das Acácias, 120, Centro', due: [0, '11:00'] },
    { n: 640, st: 'approved', c: 'h1', d: 'h1e2', who: 'Renan', req: 'Higienização semestral.', it: [['hig']], sched: [0, '11:00'], dur: 90, addr: 'Rua das Acácias, 120, Centro' },
    { n: 639, st: 'approved', c: 'h4', d: 'h4e1', who: 'Lívia', req: 'Não está gelando.', it: [['vis'], ['gas']], sched: [0, '14:00'], dur: 90, addr: 'Rua do Sol, 18, ap. 302', due: [0, '17:00'] },
    { n: 638, st: 'progress', c: 'h3', d: 'h3e1', who: 'Edson', req: 'Freezer desarmando a tomada.', it: [['vis'], ['com'], ['cmp']], hold: ['Esperando peça', -2], due: [-2, '17:00'], sched: [-3, '10:00'], dur: 120, addr: 'Rua XV de Novembro, 45', made: -4 },
    { n: 637, st: 'quote', c: 'h5', d: 'h5e1', req: 'Orçamento para a preventiva do salão.', it: [['pre', 3]], sent: -5, made: -5, addr: 'Estrada do Lago, 2000' },
    { n: 636, st: 'quote', c: 'h6', d: 'h6e1', req: 'Vazando água na recepção.', it: [['vis'], ['pre']], made: -1, addr: 'Rua Pará, 77' },
    { n: 635, st: 'done', c: 'h8', d: 'h8e1', who: 'Lívia', req: 'Higienização.', it: [['hig']], sent: -1, made: -3, addr: 'Rua Tiradentes, 501, sala 4' },
    { n: 634, st: 'done', c: 'h2', d: 'h2e2', who: 'Renan', req: 'Balcão sem frio na porta do meio.', it: [['vis'], ['mot']], pay: [[200, 'pix', -3]], sent: -3, made: -5, addr: 'Av. Beira-Mar, 900' },
    { n: 633, st: 'done', c: 'h5', d: 'h5e2', who: 'Edson', req: 'Cortina de ar parada.', it: [['vis'], ['pla']], sent: -9, made: -11, addr: 'Estrada do Lago, 2000' },
    { n: 632, st: 'done', c: 'h7', d: 'h7e1', who: 'Lívia', req: 'Geladeira não gela embaixo.', it: [['vis'], ['r13', 2]], sent: -12, made: -14, addr: 'Rua das Gaivotas, 233' },
    { n: 631, st: 'done', c: 'h9', d: 'h9e1', who: 'Renan', req: 'Instalação do split do quarto.', it: [['ins']], pay: [[520, 'pix', 0]], made: -4, addr: 'Rua Marquês, 62' },
    { n: 630, st: 'approved', c: 'h3', d: 'h3e1', who: 'Lívia', req: 'Preventiva do freezer.', it: [['pre']], sched: [1, '09:00'], dur: 90, addr: 'Rua XV de Novembro, 45' },
    { n: 629, st: 'approved', c: 'h7', d: 'h7e1', who: null, req: 'Barulho no compressor.', it: [['vis']], made: -1, addr: 'Rua das Gaivotas, 233' },
    { n: 628, st: 'approved', c: 'h9', d: 'h9e1', who: null, req: 'Higienização depois da obra.', it: [['hig']], made: -2, addr: 'Rua Marquês, 62' },
    { n: 627, st: 'done', c: 'h4', d: 'h4e1', who: 'Edson', req: 'Limpeza.', it: [['hig']], pay: [[180, 'cash', -6]], made: -8, addr: 'Rua do Sol, 18, ap. 302' },
    { n: 626, st: 'canceled', c: 'h6', d: 'h6e1', req: 'Cliente trocou o aparelho.', it: [['com']], made: -10, addr: 'Rua Pará, 77' },
  ],
}

export function makeDatabases() {
  const a = build(auto)
  const h = build(hvac)
  return {
    auto: a, hvac: h,
    auto_empty: { ...structuredClone(a), orders: [], customers: [], charges: [], invoices: [], history: [], nextNumber: 1 },
    hvac_empty: { ...structuredClone(h), orders: [], customers: [], charges: [], invoices: [], history: [], nextNumber: 1 },
  }
}
