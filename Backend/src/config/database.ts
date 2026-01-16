import { Pool, PoolClient, QueryResult } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// Database configuration
const dbConfig = {
  host: process.env.DATABASE_HOST || 'localhost',
  port: parseInt(process.env.DATABASE_PORT || '5435'),
  database: process.env.DATABASE_NAME || 'triplanai',
  user: process.env.DATABASE_USER || 'triplanai_user',
  password: process.env.DATABASE_PASSWORD || '',
  max: 20, // Maximum number of connections in the pool
  idleTimeoutMillis: 30000, // Close idle connections after 30 seconds
  connectionTimeoutMillis: 2000, // Return an error after 2 seconds if connection not established
};

// Create connection pool
const pool = new Pool(dbConfig);

// Log connection events
pool.on('connect', () => {
  console.log('📦 New client connected to PostgreSQL');
});

pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle client', err);
  process.exit(-1);
});

/**
 * Execute a query with optional parameters
 */
export async function query<T extends Record<string, any> = any>(text: string, params?: any[]): Promise<QueryResult<T>> {
  const start = Date.now();
  const result = await pool.query(text, params) as QueryResult<T>;
  const duration = Date.now() - start;
  
  if (process.env.NODE_ENV === 'development') {
    console.log('🔍 Query executed', { text: text.substring(0, 50), duration: `${duration}ms`, rows: result.rowCount });
  }
  
  return result;
}

/**
 * Get a client from the pool for transactions
 */
export async function getClient(): Promise<PoolClient> {
  return await pool.connect();
}

/**
 * Execute a transaction with automatic commit/rollback
 */
export async function transaction<T>(callback: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Test database connection
 */
export async function testConnection(): Promise<boolean> {
  try {
    const result = await query('SELECT NOW()');
    console.log('✅ Database connected successfully at', result.rows[0].now);
    return true;
  } catch (error) {
    console.error('❌ Database connection failed:', error);
    return false;
  }
}

/**
 * Close all connections in the pool
 */
export async function closePool(): Promise<void> {
  await pool.end();
  console.log('📦 Database pool closed');
}

// Export pool for direct access if needed
export { pool };

export default {
  query,
  getClient,
  transaction,
  testConnection,
  closePool,
  pool,
};
