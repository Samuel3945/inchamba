import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CedulaData {
  cedulaNumber: string | null
  fullName: string | null
  dateOfBirth: string | null
  placeOfBirth: string | null
  bloodType: string | null
  sex: string | null
  height: string | null
  confidence: 'high' | 'medium' | 'low'
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { imageBase64, mimeType } = await req.json()
    if (!imageBase64) {
      return new Response(
        JSON.stringify({ error: 'imageBase64 is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY not configured')

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 600,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: mimeType ?? 'image/jpeg',
                  data: imageBase64,
                },
              },
              {
                type: 'text',
                text: `Esta es una imagen de una Cédula de Ciudadanía colombiana. Extrae los siguientes datos exactamente como aparecen en el documento.

Responde SOLO con JSON válido, sin texto adicional, con esta estructura exacta:
{
  "cedulaNumber": "número de cédula (solo dígitos, sin puntos ni espacios)",
  "fullName": "nombre completo tal como aparece",
  "dateOfBirth": "fecha de nacimiento en formato DD/MM/YYYY",
  "placeOfBirth": "lugar de nacimiento",
  "bloodType": "tipo de sangre con RH (ej: O+, A-, B+, AB+)",
  "sex": "M o F",
  "height": "estatura en centímetros como texto (ej: 170, 165). En cédulas colombianas aparece como ESTATURA o EST en la parte inferior",
  "confidence": "high si puedes leer claramente todos los datos, medium si algunos son legibles, low si la imagen no es clara"
}

Si un campo no es visible o no puedes leerlo, usa null para ese campo. NO inventes datos.`,
              },
            ],
          },
        ],
      }),
    })

    if (!response.ok) {
      const err = await response.text()
      throw new Error(`Claude API error: ${response.status} - ${err}`)
    }

    const data = await response.json()
    const rawText = data.content?.[0]?.text ?? '{}'

    let cedulaData: CedulaData
    try {
      const jsonMatch = rawText.match(/\{[\s\S]*\}/)
      cedulaData = JSON.parse(jsonMatch ? jsonMatch[0] : rawText)
    } catch {
      cedulaData = {
        cedulaNumber: null,
        fullName: null,
        dateOfBirth: null,
        placeOfBirth: null,
        bloodType: null,
        sex: null,
        height: null,
        confidence: 'low',
      }
    }

    if (cedulaData.cedulaNumber) {
      cedulaData.cedulaNumber = cedulaData.cedulaNumber.replace(/\D/g, '')
    }
    // Normalizar altura: solo dígitos
    if (cedulaData.height) {
      cedulaData.height = cedulaData.height.replace(/\D/g, '')
    }

    return new Response(
      JSON.stringify({ success: true, data: cedulaData }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('ocr-cedula error:', err)
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
