import { getAuth } from 'firebase-admin/auth'
import type { H3Event } from 'h3'
import { getAdminDb } from './firebase'

const ADMIN_EMAIL = 'rafaeldll@gmail.com'

function getAdminAuth() {
  // Ensure firebase app is initialized via getAdminDb singleton
  getAdminDb()
  return getAuth()
}

export async function verifyAdminToken(event: H3Event): Promise<{ email: string; uid: string }> {
  const authorization = getHeader(event, 'authorization')

  if (!authorization?.startsWith('Bearer ')) {
    throw createError({ statusCode: 401, message: 'Missing or invalid authorization header' })
  }

  const token = authorization.slice(7)

  try {
    const decoded = await getAdminAuth().verifyIdToken(token)

    if (decoded.email !== ADMIN_EMAIL) {
      throw createError({ statusCode: 403, message: 'Access denied' })
    }

    return { email: decoded.email, uid: decoded.uid }
  } catch (error: any) {
    if (error.statusCode) throw error
    throw createError({ statusCode: 401, message: 'Invalid token' })
  }
}
