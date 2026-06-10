import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Deploy: supabase functions deploy invite-rsvp
// Requires: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by Supabase.

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

interface Invite {
  activity: string
  start_time: string
  end_time: string
  status: string
  friend_name: string
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url)
  const id = url.searchParams.get('id')

  if (!id) {
    return html(errorPage('This invite link is invalid or missing an ID.'))
  }

  const { data: invite, error } = await supabase
    .from('invitations')
    .select('activity, start_time, end_time, status, friend_name')
    .eq('id', id)
    .single<Invite>()

  if (error || !invite) {
    return html(errorPage("This invite has expired or can't be found."))
  }

  if (req.method === 'POST') {
    const body = await req.json().catch(() => ({}))
    const action: string = body.action ?? ''
    if (action !== 'accept' && action !== 'decline') {
      return json({ error: 'Invalid action' }, 400)
    }
    if (invite.status !== 'pending') {
      return json({ error: 'Already responded', status: invite.status }, 409)
    }
    const newStatus = action === 'accept' ? 'confirmed' : 'declined'
    await supabase.from('invitations').update({ status: newStatus }).eq('id', id)
    return json({ ok: true, status: newStatus })
  }

  const start = new Date(invite.start_time)
  const end = new Date(invite.end_time)
  return html(rsvpPage(id, invite.friend_name, invite.activity, start, end, invite.status))
})

// ─── Response helpers ────────────────────────────────────────────────────────

function html(body: string): Response {
  return new Response(body, { headers: { 'Content-Type': 'text/html; charset=utf-8' } })
}

function json(body: object, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

// ─── HTML pages ──────────────────────────────────────────────────────────────

function formatDate(d: Date): string {
  return d.toLocaleString('en-US', {
    weekday: 'long', month: 'long', day: 'numeric',
    hour: 'numeric', minute: '2-digit', hour12: true,
  })
}

function shell(title: string, body: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #f5f5f7; color: #1c1c1e;
      min-height: 100vh; display: flex; align-items: center; justify-content: center;
      padding: 24px;
    }
    .card {
      background: #fff; border-radius: 22px; padding: 36px 28px;
      max-width: 380px; width: 100%; box-shadow: 0 4px 32px rgba(0,0,0,.08);
      text-align: center;
    }
    .seal {
      width: 72px; height: 72px; border-radius: 50%;
      background: linear-gradient(135deg, #3e7b78, #5aada9);
      margin: 0 auto 20px; display: flex; align-items: center; justify-content: center;
      font-size: 32px;
    }
    h1 { font-size: 22px; font-weight: 700; margin-bottom: 8px; }
    .meta { font-size: 15px; color: #636366; line-height: 1.5; margin-bottom: 28px; }
    .btn {
      display: block; width: 100%; padding: 16px;
      border: none; border-radius: 14px; font-size: 17px; font-weight: 600;
      cursor: pointer; text-decoration: none; margin-bottom: 12px; transition: opacity .15s;
    }
    .btn:active { opacity: .7; }
    .btn-accept { background: #3e7b78; color: #fff; }
    .btn-decline { background: #f2f2f7; color: #636366; }
    .btn-eta { background: linear-gradient(135deg, #3e7b78, #5aada9); color: #fff; font-size: 15px; }
    .note { font-size: 13px; color: #aeaeb2; margin-top: 16px; }
    a.appstore { color: #3e7b78; text-decoration: none; font-weight: 600; }
  </style>
</head>
<body>
  <div class="card">${body}</div>
</body>
</html>`
}

function rsvpPage(
  id: string, friendName: string, activity: string,
  start: Date, end: Date, currentStatus: string
): string {
  if (currentStatus !== 'pending') {
    return alreadyRespondedPage(activity, currentStatus)
  }

  const startTs = start.getTime() / 1000
  const endTs = end.getTime() / 1000
  const etaURL = `eta://invite-accepted?activity=${encodeURIComponent(activity)}&start=${startTs}&end=${endTs}&senderName=${encodeURIComponent(friendName)}`

  const body = `
    <div class="seal">✉️</div>
    <h1>${friendName} invited you!</h1>
    <div class="meta">
      <strong>${activity}</strong><br/>
      ${formatDate(start)}
    </div>
    <button class="btn btn-accept" onclick="respond('accept')">I'm in! 🎉</button>
    <button class="btn btn-decline" onclick="respond('decline')">Can't make it</button>
    <p class="note">Have the Eta app?
      <a class="appstore" href="${etaURL}">Open in Eta</a>
    </p>
    <script>
      async function respond(action) {
        const res = await fetch(location.href, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action })
        })
        const data = await res.json()
        if (data.ok) {
          if (action === 'accept') {
            // Try opening Eta app — silently fails if not installed
            window.location.href = '${etaURL}'
            setTimeout(() => {
              document.body.innerHTML = '<div class="card">' + confirmedHtml() + '</div>'
            }, 400)
          } else {
            document.body.innerHTML = '<div class="card">' + declinedHtml() + '</div>'
          }
        } else if (res.status === 409) {
          document.body.innerHTML = '<div class="card">' + alreadyHtml(data.status) + '</div>'
        }
      }
      function confirmedHtml() {
        return '<div class="seal">✅</div><h1>You\'re in!</h1><p class="meta">We\'ve let them know. See you at <strong>${activity}</strong> on ${formatDate(start)}.</p><p class="note">Don\'t have Eta yet? <a class="appstore" href="https://apps.apple.com/app/eta/id0000000000">Download on the App Store</a></p>'
      }
      function declinedHtml() {
        return '<div class="seal">👋</div><h1>No worries</h1><p class="meta">We\'ve let them know you can\'t make it this time.</p>'
      }
      function alreadyHtml(status) {
        const label = status === 'confirmed' ? 'accepted' : 'declined'
        return '<div class="seal">ℹ️</div><h1>Already responded</h1><p class="meta">You\'ve already ' + label + ' this invite.</p>'
      }
    </script>`

  return shell(`Hangout invite — ${activity}`, body)
}

function alreadyRespondedPage(activity: string, status: string): string {
  const label = status === 'confirmed' ? 'accepted' : 'declined'
  const seal = status === 'confirmed' ? '✅' : '👋'
  const body = `
    <div class="seal">${seal}</div>
    <h1>Already ${label}</h1>
    <p class="meta">You've already ${label} this <strong>${activity}</strong> invite.</p>`
  return shell('Hangout invite', body)
}

function errorPage(message: string): string {
  const body = `
    <div class="seal">❓</div>
    <h1>Invite not found</h1>
    <p class="meta">${message}</p>
    <p class="note">Download Eta to plan hangouts with friends.</p>`
  return shell('Invite not found', body)
}
