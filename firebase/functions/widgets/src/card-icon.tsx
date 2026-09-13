import React from 'react';

const paths = {
  link: 'M10 13a5 5 0 0 0 7 .1l3-3a5 5 0 0 0-7-7l-2 2M14 11a5 5 0 0 0-7-.1l-3 3a5 5 0 0 0 7 7l2-2',
  check: 'm5 12 4 4L19 6',
  person: 'M20 21v-2a7 7 0 0 0-14 0v2M17 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  whatsapp: 'M20.5 11.7a8.6 8.6 0 0 1-12.8 7.5L3 20.5l1.3-4.6a8.6 8.6 0 1 1 16.2-4.2ZM8.2 7.7c-.6.5-.8 1.2-.4 2.3.7 2.3 2.7 4.4 5.2 5.2 1 .3 1.8.1 2.3-.5l.6-1.1-2.4-1.2-.8 1c-1.6-.6-2.6-1.6-3.2-3.1l.9-.9-1.1-2.3Z',
  share: 'M18 8a3 3 0 1 0-2.8-4A3 3 0 0 0 18 8ZM6 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm12 6a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM8.6 10.5l6.8-3.1M8.6 13.5l6.8 3.1',
} as const;
export function CardIcon({ name }: { readonly name: keyof typeof paths }) {
  return <svg className="card-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d={paths[name]} />
  </svg>;
}
