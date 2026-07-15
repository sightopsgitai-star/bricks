const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 5432,
  ssl: {
    rejectUnauthorized: false
  }
});

(async () => {
  const client = await pool.connect();
  try {
    const res = await client.query(
      "SELECT * FROM production_history WHERE client_id = 'bricks-001' ORDER BY date DESC LIMIT 20"
    );
    console.log('--- production_history rows (last 20) ---');
    res.rows.forEach(r => {
      console.log({
        id: r.id,
        date: r.date instanceof Date ? r.date.toISOString().split('T')[0] : r.date,
        production: r.production,
        cycles: r.cycles,
        block_count: r.block_count,
        cumulative_cycles: r.cumulative_cycles,
        cumulative_blocks: r.cumulative_blocks,
      });
    });
  } catch (err) {
    console.error('Error querying DB:', err.message);
  } finally {
    client.release();
    pool.end();
  }
})();
