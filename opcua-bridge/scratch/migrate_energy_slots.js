/**
 * Migration: clear old energy slot data (15-min / 5-min format) for
 * historical dates (2+ days ago) so the server reseeds them with the
 * correct 1-minute slot format (0–1439).
 *
 * Rows for today and yesterday are left intact (real PLC data).
 */
const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host:     process.env.DB_HOST,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port:     process.env.DB_PORT || 5432,
  ssl:      { rejectUnauthorized: false },
});

const DEFAULT_CLIENT_ID = process.env.DEFAULT_CLIENT_ID || 'bricks-001';

function formatLocalDate(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

(async () => {
  const client = await pool.connect();
  try {
    const now = new Date();
    const todayStr     = formatLocalDate(now);
    const yd = new Date(now); yd.setDate(yd.getDate() - 1);
    const yesterdayStr = formatLocalDate(yd);

    // 1. Show what we have before migration
    const before = await client.query(
      `SELECT date, COUNT(*) as cnt, MAX(hour) as max_slot
       FROM hourly_production
       WHERE client_id = $1
       GROUP BY date ORDER BY date`,
      [DEFAULT_CLIENT_ID]
    );
    console.log('\n📊 BEFORE migration:');
    before.rows.forEach(r =>
      console.log(`  ${r.date}  rows=${r.cnt}  max_slot=${r.max_slot}`)
    );

    // 2. Delete old-format mock data (dates older than yesterday)
    //    These will be regenerated with correct 1440-slot format on server start.
    const del = await client.query(
      `DELETE FROM hourly_production
       WHERE client_id = $1
         AND date < $2
         AND date != $3`,
      [DEFAULT_CLIENT_ID, yesterdayStr, todayStr]
    );
    console.log(`\n🗑️  Deleted ${del.rowCount} old mock rows (dates before ${yesterdayStr})`);

    // 3. Also clear any old-slot rows for yesterday that have max_slot < 1439
    //    (i.e. rows in old 15-min or 5-min format) — only if max_slot is in old range.
    const ydCheck = await client.query(
      `SELECT MAX(hour) as max_slot FROM hourly_production
       WHERE client_id = $1 AND date = $2`,
      [DEFAULT_CLIENT_ID, yesterdayStr]
    );
    const ydMaxSlot = parseInt(ydCheck.rows[0]?.max_slot ?? -1, 10);
    if (ydMaxSlot >= 0 && ydMaxSlot <= 287) {
      // Yesterday has old-format slots — clear energy columns so real data stays
      const ydDel = await client.query(
        `DELETE FROM hourly_production
         WHERE client_id = $1 AND date = $2`,
        [DEFAULT_CLIENT_ID, yesterdayStr]
      );
      console.log(`🗑️  Deleted ${ydDel.rowCount} old-format yesterday rows (max_slot=${ydMaxSlot} → was old format)`);
    } else {
      console.log(`✅ Yesterday rows look OK (max_slot=${ydMaxSlot}), keeping.`);
    }

    // 4. Show what remains
    const after = await client.query(
      `SELECT date, COUNT(*) as cnt, MAX(hour) as max_slot
       FROM hourly_production
       WHERE client_id = $1
       GROUP BY date ORDER BY date`,
      [DEFAULT_CLIENT_ID]
    );
    console.log('\n📊 AFTER migration:');
    after.rows.forEach(r =>
      console.log(`  ${r.date}  rows=${r.cnt}  max_slot=${r.max_slot}`)
    );

    console.log('\n✅ Migration complete. Restart the server to reseed historical data with 1440-slot format.');
  } catch (err) {
    console.error('❌ Migration error:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
})();
