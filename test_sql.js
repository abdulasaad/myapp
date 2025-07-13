const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jnuzpixgfskjcoqmgkxb.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpudXpwaXhnZnNramNvcW1na3hiIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0OTI4Mjg1OSwiZXhwIjoyMDY0ODU4ODU5fQ.0LZcT2iqYvn1mRB-ZGoH4tWp0jlaTlQETRJAxDvXT7o';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testCurrentFunction() {
  console.log('Testing current function...');
  
  const { data, error } = await supabase
    .rpc('get_agents_in_manager_groups', {
      manager_user_id: '38e6aae3-efab-4668-b1f1-adbc1b513800'
    });
  
  if (error) {
    console.error('Error:', error);
  } else {
    console.log('Current function result fields:', Object.keys(data[0] || {}));
    console.log('Sample data:', data[0]);
  }
}

testCurrentFunction();