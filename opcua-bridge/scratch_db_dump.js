const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({ 
  host: process.env.DB_HOST, 
  user: process.env.DB_USER, 
  password: process.env.DB_PASSWORD, 
  database: process.env.DB_NAME, 
  port: process.env.DB_PORT || 5432, 
  ssl: { rejectUnauthorized: false } 
});

async function run() {
  try {
    const tablesRes = await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
    console.log('Tables in RDS:', tablesRes.rows.map(r => r.table_name).join(', '));
    
    for (const row of tablesRes.rows) {
      const name = row.table_name;
      console.log('\n================================================================================');
      console.log(`DATA FOR TABLE: ${name}`);
      console.log('================================================================================');
      
      const data = await pool.query(`SELECT * FROM ${name} ORDER BY 1 DESC LIMIT 20`);
      if (data.rows.length === 0) {
        console.log('(Table is empty)');
      } else {
        console.table(data.rows);
      }
    }
  } catch (e) { 
    console.error('Error fetching DB data:', e.message); 
  } finally { 
    await pool.end(); 
  }
}

run();
