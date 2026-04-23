import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { workerName, workerPhone, workerCedula, amount } = await req.json()

    const n8nBaseUrl = Deno.env.get('N8N_BASE_URL') ?? ''
    const n8nWebhookPath = Deno.env.get('N8N_WITHDRAWAL_WEBHOOK') ?? '/webhook/inchamba-withdrawal-request'
    const webhookUrl = `${n8nBaseUrl}${n8nWebhookPath}`

    const payload = {
      workerName: workerName ?? 'Sin nombre',
      workerPhone: workerPhone ?? 'Sin teléfono',
      workerCedula: workerCedula ?? 'Sin cédula',
      amount: amount ?? 0,
      amountFormatted: new Intl.NumberFormat('es-CO', {
        style: 'currency',
        currency: 'COP',
        minimumFractionDigits: 0,
      }).format(amount ?? 0),
      timestamp: new Date().toISOString(),
      platform: 'Inchamba',
    }

    const res = await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })

    if (!res.ok) {
      throw new Error(`n8n webhook responded with ${res.status}`)
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('notify-withdrawal error:', err)
    // Best-effort — don't fail the user flow
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
