// The device's reading (docs/DEVICE_READING.md): the same cases as the app's
// test/utils/device_reading_test.dart, for a vehicle (km), a machine (hours)
// and a phone repair (no reading).
import { describe, expect, it } from 'vitest'
import { deviceReading, formatReading, parseReading, readingAdvances, readingFieldOf, readingsOf, withReading, type ReadingField } from '@/lib/device-reading'
import { normalizeOrder } from '@/lib/orders/model'

const mileage: ReadingField = { key: 'device.mileage', type: 'number', suffix: 'km', reading: true }
const hours: ReadingField = { key: 'device.operatingHours', type: 'number', suffix: 'h' }
const year: ReadingField = { key: 'device.year', type: 'number' }
const battery: ReadingField = { key: 'device.batteryHealth', type: 'number', suffix: '%' }

describe('readingFieldOf', () => {
  it('vehicle: the field marked as reading', () => expect(readingFieldOf([year, mileage])?.key).toBe('device.mileage'))
  it('machine: an old segment without the flag still has hours', () => expect(readingFieldOf([year, hours])?.key).toBe('device.operatingHours'))
  it('phone repair: none', () => {
    expect(readingFieldOf([battery])).toBeNull()
    expect(readingFieldOf([])).toBeNull()
  })
})

describe('format and parse', () => {
  it('unit from the segment, grouped by the company country', () => {
    expect(formatReading(mileage, 98000, 'BR')).toBe('98.000 km')
    expect(formatReading(hours, '1250', 'BR')).toBe('1.250 h')
    expect(formatReading(mileage, null, 'BR')).toBe('')
  })
  it('old values typed as text still read', () => {
    expect(parseReading('98.000')).toBe(98000)
    expect(parseReading(12.5)).toBeNull()
    expect(parseReading(-1)).toBeNull()
    expect(deviceReading({ 'device.mileage': '45000' }, mileage)).toBe(45000)
    expect(deviceReading({ mileage: 45000 }, mileage)).toBe(45000)
  })
})

describe('order readings', () => {
  it('sets and removes one device, keeping the others', () => {
    expect(withReading({ d1: 10 }, 'd2', 20)).toEqual({ d1: 10, d2: 20 })
    expect(withReading({ d1: 10 }, 'd1', null)).toBeNull()
  })
  it('the device keeps the bigger reading', () => {
    expect(readingAdvances(null, 1)).toBe(true)
    expect(readingAdvances(98000, 50000)).toBe(false)
    expect(readingAdvances(98000, 99000)).toBe(true)
  })
  it('the order reads them from the document, numbers only', () => {
    expect(readingsOf({ d1: 98000, d2: 'x' })).toEqual({ d1: 98000 })
    expect(normalizeOrder('o1', { status: 'progress', deviceReadings: { d1: 1250 } }, false).deviceReadings).toEqual({ d1: 1250 })
    expect(normalizeOrder('o1', { status: 'progress' }, false).deviceReadings).toBeUndefined()
  })
})
