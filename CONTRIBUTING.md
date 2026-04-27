# Contributing to Kviz DBase

Hvala što želiš da doprineseš! Evo kako da počneš.

## Pre prvog commit-a

```bash
dart format .
flutter analyze
flutter test
```

Svi koraci moraju proći pre nego što otvoriš PR.

## Pull Request proces

1. Fork-uj repo i napravi branch iz `main`
2. Commit-uj svoje izmene — koristi imperative mood (`add`, `fix`, `update`)
3. Proveri da CI prolazi (format, analyze, test)
4. Otvori PR sa jasnim opisom šta si promenio/la i zašto

## Stil koda

- Prati postojeći Dart stil (`dart format`)
- Za UI tekst koristi postojeći `t(latin, cyr)` obrazac
- Ne uključuj API ključeve, tokene ili lozinke u kod

## Prijava bagova

Koristi GitHub Issues. Navedi:
- Verziju aplikacije
- Korake za reprodukciju
- Očekivano ponašanje vs. stvarno
- Screenshot ako pomaže

## Licenca

Svi doprinosi podležu [GPLv3+ licenci](LICENSE).
