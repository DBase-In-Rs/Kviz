# Security Policy

## Prijava ranjivosti

Ako pronađeš bezbednosni propust, **molimo te NE otvaraj javni issue**.

Umesto toga, pošalji detalje na email vlasnika projekta. Odgovorićemo u roku
od 48 sati sa planom za rešavanje.

## Podržane verzije

| Verzija | Podržana |
|---|---|
| Najnoviji release | ✅ |
| Starije verzije | ❌ |

## Bezbednosne prakse

- Aplikacija koristi Play Integrity za Android verifikaciju
- Mrežni saobraćaj koristi certificate pinning
- Svi API tokeni su kratkotrajni (Bearer + mobile session token)
- Backend je autoritet za score i anti-cheat
