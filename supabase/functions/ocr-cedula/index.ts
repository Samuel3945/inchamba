import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json()
    const imageBase64: string = body.imageBase64
    const mimeType: string = body.mimeType ?? 'image/jpeg'
    const side: string = body.side ?? 'front'

    if (!imageBase64) {
      return new Response(JSON.stringify({ success: false, error: 'imageBase64 is required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    if (!openaiKey) throw new Error('OPENAI_API_KEY not configured')

    // Prompt con validación del lado correcto
    const prompt = side === 'back'
      ? `Analiza esta imagen. PRIMERO determina si es el REVERSO de una Cédula de Ciudadanía colombiana.

El REVERSO se identifica porque:
- Tiene huella dactilar y/o firma
- Tiene código de barras o QR
- Tiene texto 'COLOMBIA' de fondo
- NO tiene foto de rostro como elemento principal
- Puede tener datos como tipo de sangre y estatura

El FRENTE tiene foto de rostro prominente, nombre completo, y número de cédula grande.

Responde SOLO con JSON válido. Si la imagen es claramente el FRENTE (no el reverso), responde:
{ "wrong_side": true, "message": "Debes fotografiar el REVERSO de la cédula, no el frente" }

Si es el reverso, responde:
{
  "wrong_side": false,
  "cedulaNumber": null,
  "fullName": null,
  "dateOfBirth": null,
  "placeOfBirth": null,
  "bloodType": "tipo de sangre con RH si aparece (ej: O+)",
  "sex": null,
  "height": "estatura en cm si aparece (ej: 170)",
  "confidence": "high|medium|low"
}
Usa null para campos que no aparezcan. NO inventes datos.`
      : `Analiza esta imagen. PRIMERO determina si es el FRENTE de una Cédula de Ciudadanía colombiana.

El FRENTE se identifica porque:
- Tiene foto de rostro prominente de la persona
- Tiene número de cédula (NUIP) visible
- Tiene nombre completo de la persona
- Tiene fechas de nacimiento y expedición

El REVERSO tiene huella dactilar, firma, códigos de barras, y NO tiene foto de rostro.

Responde SOLO con JSON válido. Si la imagen es claramente el REVERSO (no el frente), responde:
{ "wrong_side": true, "message": "Debes fotografiar el FRENTE de la cédula, no el reverso" }

Si no es una cédula colombiana, responde:
{ "wrong_side": true, "message": "No se detectó una cédula de ciudadanía colombiana" }

Si es el frente, responde:
{
  "wrong_side": false,
  "cedulaNumber": "número de cédula (solo dígitos)",
  "fullName": "nombre completo",
  "dateOfBirth": "DD/MM/YYYY",
  "placeOfBirth": "lugar de nacimiento",
  "bloodType": "tipo de sangre con RH si aparece",
  "sex": "M o F",
  "height": "estatura en cm si aparece",
  "confidence": "high|medium|low"
}
Usa null para campos no visibles. NO inventes datos.`

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${openaiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        max_tokens: 500,
        messages: [{ role: 'user', content: [
          { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}`, detail: 'high' } },
          { type: 'text', text: prompt },
        ]}],
      }),
    })

    if (!response.ok) {
      const errText = await response.text()
      throw new Error(`OpenAI API error ${response.status}: ${errText}`)
    }

    const data = await response.json()
    const rawText: string = data.choices?.[0]?.message?.content ?? '{}'

    let parsed: Record<string, unknown> = {}
    try {
      const m = rawText.match(/\{[\s\S]*\}/)
      parsed = JSON.parse(m ? m[0] : rawText)
    } catch (_e) { /* keep empty */ }

    // Si el modelo detectó que la imagen no corresponde al lado esperado
    if (parsed.wrong_side === true) {
      return new Response(JSON.stringify({
        success: false,
        wrong_side: true,
        error: parsed.message ?? `Imagen incorrecta para ${side === 'back' ? 'el reverso' : 'el frente'}`,
      }), { status: 422, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (typeof parsed.cedulaNumber === 'string') parsed.cedulaNumber = (parsed.cedulaNumber as string).replace(/\D/g, '')
    if (typeof parsed.height === 'string') parsed.height = (parsed.height as string).replace(/\D/g, '')

    return new Response(JSON.stringify({ success: true, data: parsed }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('ocr-cedula error:', String(err))
    return new Response(JSON.stringify({ success: false, error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
