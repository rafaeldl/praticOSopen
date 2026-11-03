/**
 * Visit and delivery dates without a zone (the app's format, accepted since
 * #521): an impossible date is a 400, never saved as it came.
 */
import {
  createFullOrderSchema,
  createOrderSchema,
  isValidOrderDate,
  updateBotOrderSchema,
  updateOrderSchema,
  validateInput,
} from '../validation.utils';
import { storedOrderDate } from '../../services/order.service';
import { OrderRuleError } from '../../services/order-errors';

const IMPOSSIBLE = [
  '2031-13-45T99:99',
  '2031-00-10T10:00',
  '2031-02-29T10:00:00.000', // 2031 is not a leap year
  '2031-04-31T10:00',
  '2031-03-10T24:00',
  '2031-03-10T10:60',
  '2031-03-10T10:00:60',
];
const VALID = ['2031-03-10T09:30', '2031-03-10T09:30:00.000', '2032-02-29T23:59:59.123456', '2031-03-11T17:00:00.000Z', '2031-03-11T14:00:00-03:00'];

describe('data sem fuso', () => {
  it.each(IMPOSSIBLE)('%s é recusada', (value) => {
    expect(isValidOrderDate(value)).toBe(false);
    expect(validateInput(updateOrderSchema, { scheduledDate: value }).success).toBe(false);
    expect(validateInput(updateOrderSchema, { dueDate: value }).success).toBe(false);
    expect(validateInput(createOrderSchema, { customerId: 'c1', scheduledDate: value }).success).toBe(false);
    expect(validateInput(updateBotOrderSchema, { scheduledDate: value }).success).toBe(false);
    expect(validateInput(updateBotOrderSchema, { dueDate: value }).success).toBe(false);
    expect(validateInput(createFullOrderSchema, { customerId: 'c1', dueDate: value }).success).toBe(false);
    expect(() => storedOrderDate(value)).toThrow(OrderRuleError);
  });

  it.each(VALID)('%s passa', (value) => {
    expect(isValidOrderDate(value)).toBe(true);
    expect(validateInput(updateOrderSchema, { scheduledDate: value }).success).toBe(true);
    expect(validateInput(updateBotOrderSchema, { scheduledDate: value }).success).toBe(true);
  });

  it('o erro é 400 VALIDATION_ERROR', () => {
    try {
      storedOrderDate('2031-13-45T99:99');
      throw new Error('não recusou');
    } catch (error) {
      expect(error).toBeInstanceOf(OrderRuleError);
      expect((error as OrderRuleError).httpStatus).toBe(400);
      expect((error as OrderRuleError).code).toBe('VALIDATION_ERROR');
    }
  });

  it('o bot continua aceitando o que o Date entende (só a data)', () => {
    expect(validateInput(updateBotOrderSchema, { dueDate: '2031-03-10' }).success).toBe(true);
    expect(validateInput(updateBotOrderSchema, { dueDate: 'amanhã' }).success).toBe(false);
  });
});
