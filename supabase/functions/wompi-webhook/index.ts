import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await req.text();
    const payload = JSON.parse(body);

    // Verificar firma de Wompi
    // Wompi firma: SHA256(timestamp + body + events_secret)
    const wompiEventsSecret = Deno.env.get('WOMPI_EVENTS_SECRET');
    if (wompiEventsSecret) {
      const timestamp = req.headers.get('x-timestamp') ?? '';
      const signature = req.headers.get('x-signature') ?? '';
      const raw = `${timestamp}${body}${wompiEventsSecret}`;
      const encoder = new TextEncoder();
      const keyData = encoder.encode(wompiEventsSecret);
      const msgData = encoder.encode(raw);
      const cryptoKey = await crypto.subtle.importKey(
        'raw', keyData, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
      );
      const sigBuffer = await crypto.subtle.sign('HMAC', cryptoKey, msgData);
      const computed = Array.from(new Uint8Array(sigBuffer))
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
      if (computed !== signature) {
        console.error('Firma Wompi inválida');
        return new Response(JSON.stringify({ error: 'Invalid signature' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    const event = payload?.event;
    const tx = payload?.data?.transaction;

    // Solo procesar pagos aprobados
    if (event !== 'transaction.updated' || tx?.status !== 'APPROVED') {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const reference = tx.reference as string;
    const amountCents = tx.amount_in_cents as number;

    if (!reference?.startsWith('TOPUP_')) {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Buscar la transacción pendiente
    const { data: walletTx, error: fetchErr } = await supabase
      .from('wallet_transactions')
      .select('id, user_id, amount, status')
      .eq('reference', reference)
      .single();

    if (fetchErr || !walletTx) {
      console.error('Transacción no encontrada:', reference, fetchErr);
      return new Response(JSON.stringify({ error: 'Transaction not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Evitar duplicados: ya fue procesada
    if (walletTx.status === 'completed') {
      return new Response(JSON.stringify({ ok: true, already_processed: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Marcar transacción como completada
    const { error: updateTxErr } = await supabase
      .from('wallet_transactions')
      .update({ status: 'completed', wompi_transaction_id: tx.id })
      .eq('id', walletTx.id);

    if (updateTxErr) throw updateTxErr;

    // Acreditar saldo al usuario (solo el amount sin la tarifa)
    const { error: walletErr } = await supabase.rpc('credit_wallet', {
      p_user_id: walletTx.user_id,
      p_amount: walletTx.amount,
    });

    if (walletErr) throw walletErr;

    console.log(`Wallet acreditado: user=${walletTx.user_id} amount=${walletTx.amount} ref=${reference}`);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('Error en wompi-webhook:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
