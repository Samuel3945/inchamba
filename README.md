# InChamba

**Marketplace móvil de trabajos por días para Colombia.** Conecta a quien necesita una mano de obra puntual (cargue y descargue, mudanzas, apoyo logístico, oficios) con trabajadores verificados cerca, con pago seguro dentro de la app.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white)
![n8n](https://img.shields.io/badge/n8n-EA4B71?logo=n8n&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI-412991?logo=openai&logoColor=white)

---

## El problema

En Colombia, conseguir trabajo por días o contratar a alguien para una tarea puntual depende de conocidos, grupos de WhatsApp y llamadas. El empleador no sabe si la persona es confiable. El trabajador no sabe si le van a pagar. Nadie tiene historial ni respaldo.

## La solución

Una app al estilo *InDrive*, pero para trabajo: el empleador publica una oferta, los trabajadores se postulan y **negocian el precio**, y el dinero queda respaldado en una billetera hasta que ambas partes confirman que el trabajo se hizo.

### Funcionalidades

| Para el empleador | Para el trabajador |
|---|---|
| Publicar ofertas con ubicación y precio | Feed de ofertas cercanas (geolocalización) |
| Recibir postulaciones y contraofertas | Postularse y negociar el precio |
| Pagar en línea con Wompi | Marcar avance y trabajo completado |
| Confirmar el trabajo y liberar el pago | Billetera con retiros |
| Calificar al trabajador | Calificar al empleador |

**Comunes:** mensajería en la app, notificaciones, disputas, perfiles con reputación y un modo invitado para explorar sin registrarse.

### Verificación de identidad con IA

Para generar confianza, cada usuario verifica su **cédula colombiana** con una foto:

- Una *Edge Function* (`ocr-cedula`) envía la imagen a un modelo de visión de OpenAI que **detecta si es el frente o el reverso** y extrae los datos en JSON estructurado.
- Un **asistente conversacional** (agente de n8n con Claude y memoria) guía al usuario cuando la foto no sirve.

## Arquitectura

```mermaid
flowchart TB
    subgraph App["App Flutter · Riverpod · go_router"]
        UI[Pantallas<br/>empleador · trabajador · compartidas]
    end

    subgraph Supabase
        AUTH[Auth]
        DB[(Postgres + RLS<br/>RPC de billetera)]
        EF1[Edge Function<br/>ocr-cedula]
        EF2[Edge Function<br/>wompi-webhook]
        EF3[Edge Function<br/>notify-withdrawal]
    end

    subgraph n8n
        W1[Agente asesor de cédula<br/>Claude]
        W2[Notificación de retiros]
    end

    UI --> AUTH & DB
    UI --> EF1 --> OAI[OpenAI Vision]
    UI --> W1
    WOMPI[Wompi] --> EF2 --> DB
    EF3 --> W2
```

El código sigue una **arquitectura limpia por capas**:

```
lib/
├── core/           Constantes, tema, errores, utilidades
├── domain/         Entidades del negocio
├── data/           Modelos y fuentes de datos (Supabase, HTTP)
└── presentation/
    ├── providers/  Estado con Riverpod
    ├── screens/
    │   ├── employer/   Crear oferta, pagos, billetera, confirmar trabajo
    │   ├── worker/     Feed, postulaciones, progreso, completar
    │   └── shared/     Cédula, mensajería, disputas, calificaciones, perfil
    └── widgets/
supabase/
├── functions/      Edge Functions (Deno/TypeScript)
└── migrations/     Esquema SQL versionado
n8n/                Workflows exportados
```

## Stack

- **Móvil:** Flutter 3, Dart, Riverpod + Hooks, go_router, Dio
- **Backend:** Supabase (Auth, Postgres, RLS, RPC, Edge Functions en Deno)
- **Pagos:** Wompi, con webhook que acredita la billetera
- **IA:** OpenAI Vision (OCR de cédula) y Claude vía n8n (asistente)
- **Extras:** geolocalización, notificaciones locales, voz a texto, grabación de audio

## Correr en local

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<tu-proyecto>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<tu-anon-key>
```

Las claves se inyectan en tiempo de compilación con `--dart-define`; ninguna vive en el repositorio.

---

Desarrollado por **[Samuel Alzate](https://github.com/Samuel3945)** · Cartagena, Colombia
