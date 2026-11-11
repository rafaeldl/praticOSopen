import {
  AirVent,
  ArrowUpDown,
  Bike,
  Building2,
  Car,
  Cctv,
  Factory,
  House,
  Laptop,
  MapPin,
  Printer,
  Server,
  Smartphone,
  Sofa,
  SunMedium,
  Tv,
  WashingMachine,
  Zap,
} from 'lucide-react'

// The icon on the order's second row (vehicle, device, equipment, site),
// one per trade. The data names it (`deviceIcon` in the scene copy); a
// missing or unknown name keeps the car the home uses.
const ICONS = {
  car: Car,
  bike: Bike,
  phone: Smartphone,
  laptop: Laptop,
  tv: Tv,
  printer: Printer,
  washer: WashingMachine,
  ac: AirVent,
  cctv: Cctv,
  solar: SunMedium,
  elevator: ArrowUpDown,
  sofa: Sofa,
  server: Server,
  factory: Factory,
  building: Building2,
  house: House,
  power: Zap,
  place: MapPin,
} as const

export type DeviceIconName = keyof typeof ICONS

export function DeviceIcon({ name }: { name?: string }) {
  const Icon = (name && ICONS[name as DeviceIconName]) || Car
  return <Icon size={18} strokeWidth={2} />
}
