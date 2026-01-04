const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * Recebe logs de eventos do carro e salva no Firestore.
 *
 * Estrutura esperada do body:
 * {
 *   "sessionId": "1715623456789",      // ID unico da sessao (partida do carro)
 *   "batchTimestamp": 1715623500000,   // Hora do envio desse lote (ms)
 *   "events": [
 *     {
 *       "key": "car.basic.vehicle_speed",
 *       "value": "45.0",
 *       "timestamp": 1715623498123
 *     }
 *   ]
 * }
 *
 * Salva em: /carSessions/{sessionId}/events/{autoId}
 */
exports.receiveCarEventLogs = functions
  .region('southamerica-east1')
  .https.onRequest(async (req, res) => {
    // Apenas POST e permitido
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed. Use POST.' });
      return;
    }

    // Valida Content-Type
    const contentType = req.get('Content-Type') || '';
    if (!contentType.includes('application/json')) {
      res.status(400).json({ error: 'Content-Type must be application/json' });
      return;
    }

    const { sessionId, batchTimestamp, events } = req.body;

    // Validacoes
    if (!sessionId || typeof sessionId !== 'string') {
      res.status(400).json({ error: 'sessionId is required and must be a string' });
      return;
    }

    if (!batchTimestamp || typeof batchTimestamp !== 'number') {
      res.status(400).json({ error: 'batchTimestamp is required and must be a number' });
      return;
    }

    if (!events || !Array.isArray(events) || events.length === 0) {
      res.status(400).json({ error: 'events is required and must be a non-empty array' });
      return;
    }

    // Valida cada evento
    for (let i = 0; i < events.length; i++) {
      const event = events[i];
      if (!event.key || typeof event.key !== 'string') {
        res.status(400).json({ error: `events[${i}].key is required and must be a string` });
        return;
      }
      if (event.value === undefined || event.value === null) {
        res.status(400).json({ error: `events[${i}].value is required` });
        return;
      }
      if (!event.timestamp || typeof event.timestamp !== 'number') {
        res.status(400).json({ error: `events[${i}].timestamp is required and must be a number` });
        return;
      }
    }

    try {
      const sessionRef = db.collection('carSessions').doc(sessionId);
      const eventsRef = sessionRef.collection('events');

      // Usa batch para escrita atomica
      const batch = db.batch();

      // Atualiza/cria documento da sessao com metadados
      batch.set(sessionRef, {
        lastBatchTimestamp: batchTimestamp,
        lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        eventCount: admin.firestore.FieldValue.increment(events.length),
      }, { merge: true });

      // Adiciona cada evento como documento na subcollection
      events.forEach(event => {
        const eventDoc = eventsRef.doc();
        batch.set(eventDoc, {
          key: event.key,
          value: String(event.value), // Garante que seja string
          timestamp: event.timestamp,
          batchTimestamp: batchTimestamp,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      console.log(`[CarEventLogs] Session ${sessionId}: ${events.length} events saved`);

      res.status(200).json({
        success: true,
        sessionId: sessionId,
        eventsReceived: events.length,
      });
    } catch (error) {
      console.error(`[CarEventLogs] Error saving events for session ${sessionId}:`, error);
      res.status(500).json({ error: 'Internal server error' });
    }
  });
