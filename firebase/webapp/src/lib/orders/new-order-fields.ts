// The segment's order fields on the Nova OS (order.new.custom-fields): those the
// screen does not already have (status, dates, total, payment, place, request).
import { namespaceFields, type FormField } from '@/lib/segment-fields'

export const NEW_ORDER_BUILT_IN = ['service_order.status', 'service_order.scheduledDate', 'service_order.dueDate', 'service_order.total', 'service_order.payment', 'service_order.address', 'service_order.observation']

export const newOrderFields = (): FormField[] => namespaceFields('service_order', NEW_ORDER_BUILT_IN).filter((field) => field.type !== 'label')
