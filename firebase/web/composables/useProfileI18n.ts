type Lang = 'pt' | 'en' | 'es'

const segmentLabels: Record<Lang, Record<string, string>> = {
  pt: {
    hvac: 'Ar Condicionado',
    automotive: 'Automotivo',
    electronics: 'Eletrônica',
    appliances: 'Eletrodomésticos',
    computing: 'Informática',
    mobile: 'Celulares',
    general: 'Serviços Gerais',
    plumbing: 'Hidráulica',
    electrical: 'Elétrica',
    construction: 'Construção',
    cleaning: 'Limpeza',
    beauty: 'Beleza',
    health: 'Saúde',
    veterinary: 'Veterinária',
    photography: 'Fotografia',
    design: 'Design',
    consulting: 'Consultoria',
    education: 'Educação',
    fitness: 'Fitness',
    food: 'Alimentação',
    landscaping: 'Jardinagem',
    locksmith: 'Chaveiro',
    moving: 'Mudanças',
    painting: 'Pintura',
    pest_control: 'Controle de Pragas',
    roofing: 'Telhados',
    security: 'Segurança',
    solar: 'Energia Solar',
    telecom: 'Telecomunicações',
    welding: 'Soldagem',
  },
  en: {
    hvac: 'HVAC',
    automotive: 'Automotive',
    electronics: 'Electronics',
    appliances: 'Appliances',
    computing: 'IT Services',
    mobile: 'Mobile Repair',
    general: 'General Services',
    plumbing: 'Plumbing',
    electrical: 'Electrical',
    construction: 'Construction',
    cleaning: 'Cleaning',
    beauty: 'Beauty',
    health: 'Healthcare',
    veterinary: 'Veterinary',
    photography: 'Photography',
    design: 'Design',
    consulting: 'Consulting',
    education: 'Education',
    fitness: 'Fitness',
    food: 'Food',
    landscaping: 'Landscaping',
    locksmith: 'Locksmith',
    moving: 'Moving',
    painting: 'Painting',
    pest_control: 'Pest Control',
    roofing: 'Roofing',
    security: 'Security',
    solar: 'Solar Energy',
    telecom: 'Telecom',
    welding: 'Welding',
  },
  es: {
    hvac: 'Aire Acondicionado',
    automotive: 'Automotriz',
    electronics: 'Electrónica',
    appliances: 'Electrodomésticos',
    computing: 'Informática',
    mobile: 'Celulares',
    general: 'Servicios Generales',
    plumbing: 'Plomería',
    electrical: 'Eléctrica',
    construction: 'Construcción',
    cleaning: 'Limpieza',
    beauty: 'Belleza',
    health: 'Salud',
    veterinary: 'Veterinaria',
    photography: 'Fotografía',
    design: 'Diseño',
    consulting: 'Consultoría',
    education: 'Educación',
    fitness: 'Fitness',
    food: 'Alimentación',
    landscaping: 'Jardinería',
    locksmith: 'Cerrajería',
    moving: 'Mudanzas',
    painting: 'Pintura',
    pest_control: 'Control de Plagas',
    roofing: 'Techos',
    security: 'Seguridad',
    solar: 'Energía Solar',
    telecom: 'Telecomunicaciones',
    welding: 'Soldadura',
  },
}

const uiStrings: Record<Lang, Record<string, string>> = {
  pt: {
    // SEO
    seoTitle: '{name} - Perfil Profissional | PraticOS',
    seoDescription: '{name} - {segment} em {city}. Veja serviços, avaliações e portfólio.',

    // Header
    verified: 'Verificado',

    // Stats
    completedOrders: 'serviços realizados',
    avgRating: 'nota média',
    reviewCount: 'avaliações',

    // Sections
    about: 'Sobre',
    readMore: 'Ler mais',
    readLess: 'Ler menos',
    servicesTitle: 'Serviços',
    noServices: 'Nenhum serviço cadastrado',
    portfolioTitle: 'Portfólio',
    reviewsTitle: 'Avaliações',
    noReviews: 'Nenhuma avaliação ainda',
    showMore: 'Ver mais avaliações',
    showLess: 'Ver menos',

    // CTA
    whatsapp: 'WhatsApp',
    call: 'Ligar',
    schedule: 'Agendar',

    // Error
    notFoundTitle: 'Perfil não encontrado',
    notFoundDesc: 'O perfil que você procura não existe ou foi desativado.',
    backHome: 'Ir para PraticOS',

    // Loading
    loading: 'Carregando perfil...',

    // Footer
    poweredBy: 'Powered by',

    // Relative date
    justNow: 'agora mesmo',
    minutesAgo: 'há {n} min',
    hoursAgo: 'há {n}h',
    daysAgo: 'há {n} dias',
    weeksAgo: 'há {n} semanas',
    monthsAgo: 'há {n} meses',
    yearsAgo: 'há {n} anos',
  },
  en: {
    seoTitle: '{name} - Professional Profile | PraticOS',
    seoDescription: '{name} - {segment} in {city}. View services, reviews and portfolio.',

    verified: 'Verified',

    completedOrders: 'services completed',
    avgRating: 'average rating',
    reviewCount: 'reviews',

    about: 'About',
    readMore: 'Read more',
    readLess: 'Read less',
    servicesTitle: 'Services',
    noServices: 'No services listed',
    portfolioTitle: 'Portfolio',
    reviewsTitle: 'Reviews',
    noReviews: 'No reviews yet',
    showMore: 'Show more reviews',
    showLess: 'Show less',

    whatsapp: 'WhatsApp',
    call: 'Call',
    schedule: 'Schedule',

    notFoundTitle: 'Profile not found',
    notFoundDesc: 'The profile you\'re looking for doesn\'t exist or has been deactivated.',
    backHome: 'Go to PraticOS',

    loading: 'Loading profile...',

    poweredBy: 'Powered by',

    justNow: 'just now',
    minutesAgo: '{n}m ago',
    hoursAgo: '{n}h ago',
    daysAgo: '{n}d ago',
    weeksAgo: '{n}w ago',
    monthsAgo: '{n}mo ago',
    yearsAgo: '{n}y ago',
  },
  es: {
    seoTitle: '{name} - Perfil Profesional | PraticOS',
    seoDescription: '{name} - {segment} en {city}. Vea servicios, calificaciones y portafolio.',

    verified: 'Verificado',

    completedOrders: 'servicios realizados',
    avgRating: 'nota promedio',
    reviewCount: 'calificaciones',

    about: 'Acerca de',
    readMore: 'Leer más',
    readLess: 'Leer menos',
    servicesTitle: 'Servicios',
    noServices: 'Ningún servicio registrado',
    portfolioTitle: 'Portafolio',
    reviewsTitle: 'Calificaciones',
    noReviews: 'Sin calificaciones todavía',
    showMore: 'Ver más calificaciones',
    showLess: 'Ver menos',

    whatsapp: 'WhatsApp',
    call: 'Llamar',
    schedule: 'Agendar',

    notFoundTitle: 'Perfil no encontrado',
    notFoundDesc: 'El perfil que buscas no existe o fue desactivado.',
    backHome: 'Ir a PraticOS',

    loading: 'Cargando perfil...',

    poweredBy: 'Powered by',

    justNow: 'ahora mismo',
    minutesAgo: 'hace {n} min',
    hoursAgo: 'hace {n}h',
    daysAgo: 'hace {n} días',
    weeksAgo: 'hace {n} semanas',
    monthsAgo: 'hace {n} meses',
    yearsAgo: 'hace {n} años',
  },
}

export function useProfileI18n() {
  const lang = ref<Lang>('pt')

  if (import.meta.client) {
    onMounted(() => {
      const params = new URLSearchParams(window.location.search)
      const paramLang = params.get('lang')
      if (paramLang && ['pt', 'en', 'es'].includes(paramLang)) {
        lang.value = paramLang as Lang
        return
      }
      const navLang = (navigator.language || 'pt').split('-')[0]
      if (['pt', 'en', 'es'].includes(navLang)) {
        lang.value = navLang as Lang
      }
    })
  }

  const t = computed(() => uiStrings[lang.value] || uiStrings.pt)

  function setLang(newLang: Lang) {
    lang.value = newLang
    if (import.meta.client) {
      const url = new URL(window.location.href)
      url.searchParams.set('lang', newLang)
      window.location.href = url.toString()
    }
  }

  function getSegmentLabel(segmentId?: string): string {
    if (!segmentId) return ''
    return segmentLabels[lang.value]?.[segmentId] || segmentId
  }

  function formatRelativeDate(isoDate?: string): string {
    if (!isoDate) return ''
    const now = Date.now()
    const date = new Date(isoDate).getTime()
    const diffMs = now - date
    const diffMin = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)
    const diffWeeks = Math.floor(diffDays / 7)
    const diffMonths = Math.floor(diffDays / 30)
    const diffYears = Math.floor(diffDays / 365)

    const strings = t.value
    if (diffMin < 1) return strings.justNow
    if (diffMin < 60) return strings.minutesAgo.replace('{n}', String(diffMin))
    if (diffHours < 24) return strings.hoursAgo.replace('{n}', String(diffHours))
    if (diffDays < 7) return strings.daysAgo.replace('{n}', String(diffDays))
    if (diffWeeks < 5) return strings.weeksAgo.replace('{n}', String(diffWeeks))
    if (diffMonths < 12) return strings.monthsAgo.replace('{n}', String(diffMonths))
    return strings.yearsAgo.replace('{n}', String(diffYears))
  }

  return { lang, t, setLang, getSegmentLabel, formatRelativeDate }
}
