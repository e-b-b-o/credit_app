import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Initialize Supabase client with the user's authorization header to verify they are an authenticated owner
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    
    // 2. Verify the requesting user
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) throw new Error('Unauthorized')

    // 3. Parse request body
    const { email, password, customer_id } = await req.json()

    if (!email || !password || !customer_id) {
        throw new Error('Missing required fields')
    }

    // 4. Initialize Supabase Admin client using the Service Role Key
    // This safely bypasses auth restrictions without logging out the current user,
    // and correctly populates all internal auth tables (including provider_id in auth.identities).
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 5. Create the new customer auth account
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: true,
      user_metadata: { role: 'customer' }
    })

    if (authError) throw authError

    // 6. Link the newly created auth_user_id to the customer record
    // This is done using the owner's client to ensure RLS policies are respected 
    // (i.e. the owner can only update their own customer).
    const { error: dbError } = await supabaseClient
      .from('customers')
      .update({ auth_user_id: authData.user.id })
      .eq('id', customer_id)
      .eq('owner_id', user.id)

    if (dbError) {
        // If DB link fails, optionally delete the orphaned auth user
        await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
        throw dbError
    }

    return new Response(JSON.stringify({ success: true, user_id: authData.user.id }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
