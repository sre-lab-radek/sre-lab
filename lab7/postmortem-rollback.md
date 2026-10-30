# Postmortem: test rollbacku wdrożenia (pull-deploy) i fałszywy alert po rollbacku

- **Data:** 30.10.2026
- **Czas:** lokalny (CET, UTC+1). Godziny z `date -Is`, logu `deploy.log` i Prometheusa (zapytanie `query_range`).
- **Autor:** Radosław Drzymała
- **Rodzaj zdarzenia:** zaplanowany test (wdrożenie celowo zepsutej konfiguracji), nie incydent produkcyjny. W nazwach plików i commitów oznaczony `testA`, w notatniku jako test D (testy A–C były w dziale 9)
- **Status:** zakończony, commit z błędem wycofany przez `git revert`, wdrożenie wycofania `DEPLOY OK`, 8 celów

## 1. Podsumowanie

Do repozytorium wypchnięto commit dodający do `lab2/prometheus.yml` job `testA-broken` z celem `localhost:9999`, który nigdy nie odpowiada. Konfiguracja była poprawna składniowo, więc przeszła walidację (`promtool`, `amtool`, `docker compose config`). Skrypt `pull-deploy.sh` wykrył commit po 4 min 33 s od pushu, wdrożył go i po 12 próbach kontroli zdrowia (co 5 s) ogłosił porażkę. O 12:41:04 cofnął pliki z `.previous/` i o 12:41:05 zakończył rollback, w 63 s od wykrycia commita. Rollback zadziałał: konfiguracja wróciła do 8 celów. Jednak **po rollbacku alert `InstanceDown` dla nieistniejącego już celu wrócił i przeszedł w stan *firing*** (12:42:15 – 12:45:55), a na Telegram przyszły wiadomości *Firing* (12:42) i *Resolved* (12:46). Wiadomości były fałszywe: usługi nie miały awarii. Przyczyną jest najprawdopodobniej odtworzenie kontenera Prometheusa (`--force-recreate`) zamiast przeładowania konfiguracji (hipoteza, patrz sekcja 7).

## 2. Wpływ

- Brak użytkowników zewnętrznych (środowisko labowe).
- Prometheus na sre-lab był odtwarzany dwukrotnie w trakcie testu (start wdrożenia i rollback). Przerwy w zbieraniu metryk trwały po kilkanaście sekund (nie mierzono dokładnie).
- Fałszywy alert `InstanceDown` o wadze `critical`: stan *firing* przez 3 min 40 s, ogółem od ponownego pojawienia się w stanie *pending* (12:41:12) do końca *firing* (12:45:55) 4 min 43 s. Dwie wiadomości na Telegramie.
- Zepsuty commit pozostawał na `main` w GitHubie od 12:35:29 do wycofania o 12:50:26 (14 min 57 s), choć na maszynie działała już stara konfiguracja.

## 3. Środowisko

| Element | Wartość |
|---|---|
| Maszyna | sre-lab (Docker Compose, projekt `lab2`) |
| Wdrażanie | `pull-deploy.sh` z crona co 5 min (`flock -n`), walidacja, `--force-recreate` Prometheusa i Alertmanagera, kontrola zdrowia 12 × 5 s, rollback z `.previous/` |
| Kryterium zdrowia | Alertmanager `/-/healthy` oraz wszystkie cele w `/api/v1/targets` mają `health == up` (i jest co najmniej jeden cel) |
| Alert | `InstanceDown`: `up == 0`, `for: 1m`, `severity: critical` |
| Alertmanager (lab2) | `group_wait: 10s`, `group_interval: 1m`, `repeat_interval: 4h` (inne niż na VPS: 30 s / 5 min / 4 h) |
| Stan skryptu | `last_sha` zapisywany **przed** walidacją i wdrożeniem: każdy commit jest obsługiwany raz |
| Prognozy przed testem | rollback: tak; `InstanceDown` na Telegramie: tak; całość ok. 7 min (zgadnięte) |

## 4. Oś czasu

| Godzina | Zdarzenie | Źródło |
|---|---|---|
| 12:05:24 | wcześniejsze wdrożenie (notatnik v4, kopie VPS): odtworzenie kontenerów, `DEPLOY OK`, brak alertu | `deploy.log`, Telegram |
| 12:20:24 | wdrożenie zmiany `--web.enable-lifecycle`: `DEPLOY OK`, wykrycie po 52 s od pushu, wdrożenie 22 s, brak alertu | `deploy.log`, `testA0-push.txt` |
| 12:34:14 | start pętli zapisującej stan alertów co 5 s | `testA-loop.txt` |
| **12:35:29** | **`git push` zepsutego commita `9219064`** | `testA-push.txt` |
| **12:40:02** | **skrypt wykrywa commit, walidacja przechodzi** | `deploy.log` |
| 12:40:27 | `InstanceDown` dla `localhost:9999`: *pending* (pierwsza obserwacja w pętli) | `testA-loop.txt` |
| 12:41:04 | `HEALTH CHECK FAILED, rolling back` (9 ostatnich prób: 1 cel „not up") | `deploy.log` |
| **12:41:05** | **`ROLLBACK done`** | `deploy.log` |
| 12:41:07 | pętla: `[]` (Prometheus świeżo odtworzony) | `testA-loop.txt` |
| **12:41:12** | **`InstanceDown` ponownie *pending*, choć job usunięty z konfiguracji** | `testA-loop.txt` |
| **12:42:13** | **`InstanceDown` *firing*** (w serii `ALERTS`: od 12:42:15) | `testA-loop.txt`, Prometheus |
| 12:42 | wiadomość *Firing* na Telegramie | Telegram (godzina do minuty) |
| 12:44 | zamknięcie okien terminala z pętlą (dane do tego momentu w pliku, dalsze z Prometheusa) | obserwacja |
| 12:45:55 | ostatni punkt *firing* w serii `ALERTS` | Prometheus (`query_range`) |
| 12:46 | wiadomość *Resolved* na Telegramie | Telegram (godzina do minuty) |
| 12:48 | kontrola: `grep testA` → 0, 8 celów, brak próbki `up{job="testA-broken"}` | polecenia w terminalu |
| **12:50:26** | **`git revert` i push (commit `8ed013d`)** | `testA-revert-push.txt` |
| 12:55:02 | skrypt wykrywa commit wycofania (4 min 36 s po pushu) | `deploy.log` |
| **12:55:24** | **`DEPLOY OK` po wycofaniu (22 s), 8 celów** | `deploy.log`, `/api/v1/targets` |

## 5. Wskaźniki (wyliczone z powyższych danych, obliczenia sprawdzone kodem)

| Wskaźnik | Wartość | Uwagi |
|---|---|---|
| Push → wykrycie commita | **4 min 33 s** (273 s) | czekanie na tick crona co 5 min |
| Wykrycie → `HEALTH CHECK FAILED` | **62 s** | 12 prób × 5 s plus kilka sekund na start |
| Wykrycie → `ROLLBACK done` | **63 s** | prognoza własna: 85 s |
| Push → `ROLLBACK done` | **5 min 36 s** (336 s) | prognoza użytkownika: ok. 7 min (zgadnięte) |
| Czas w stanie *pending* przed rollbackiem | 38 s (12:40:27 → 12:41:05) | `for: 1m` nie zdążył się wypełnić: rollback wygrał z alertem |
| Ponowne *pending* → *firing* | 61 s (12:41:12 → 12:42:13) | zgodne z `for: 1m` |
| Czas *firing* (fałszywy alert) | **3 min 40 s** (220 s) | 12:42:15 → 12:45:55 |
| Od rollbacku do końca *firing* | 4 min 50 s (290 s) | 12:41:05 → 12:45:55 |
| Koniec *firing* względem ostatniej próbki `up` (ok. 12:41:00) | ok. 4 min 55 s | zbliżone do 5-minutowego lookbacku zapytań Prometheusa |

## 6. Wykrycie

Nieudane wdrożenie wykrył skrypt (kontrola zdrowia), bez udziału człowieka. **Skrypt nie wysłał żadnego powiadomienia o porażce ani o rollbacku** (w obejrzanych liniach 1–80 nie ma wywołania powiadomienia): informacja o rollbacku jest tylko w `deploy.log`. Za to Telegram dostał fałszywy alert `InstanceDown`, który wyglądał jak awaria. Osoba wykonująca test wiedziała o wszystkim od początku, więc nie zmierzono realnego czasu reakcji człowieka.

## 7. Przyczyna

Przyczyna testu była zamierzona: cel `localhost:9999` miał nie odpowiadać, żeby kontrola zdrowia zakończyła się porażką.

**Przyczyna fałszywego alertu (hipoteza, mocno wspierana danymi):** rollback odtworzył kontener Prometheusa (`docker compose up -d --force-recreate`). Zatrzymany proces nie zapisał znaczników wygaśnięcia (stale markers) dla usuniętego celu, więc w bazie została ostatnia próbka `up = 0`. Zapytania i reguły widzą taką próbkę przez 5 minut (lookback), więc `up == 0` było prawdziwe dla nieistniejącego już celu aż do ok. 12:46. Po wygaśnięciu próbki alert zniknął. Dowód wzmacniają: (a) alert nie występował przy wdrożeniach bez usuwanych celów (12:05 i 12:20), (b) zapytanie o próbkę o 12:48 zwróciło pustą listę, (c) koniec *firing* przypada ok. 4 min 55 s po ostatniej próbce. **Nie jest to jeszcze dowód:** rozstrzygnie go powtórka testu z przeładowaniem konfiguracji (`/-/reload`) zamiast odtworzenia kontenera (patrz działanie 1).

## 8. Co zadziałało dobrze

- Walidacja przepuściła zmianę (zgodnie z założeniem testu), a kontrola zdrowia ją odrzuciła: wykrycie w 62 s.
- Rollback był automatyczny i skuteczny: 63 s od wykrycia, konfiguracja wróciła do 8 celów.
- Zasada „commit obsługiwany raz" zapobiegła pętli ponawiania co 5 minut.
- Alert `for: 1m` nie uruchomił się w czasie złego okna (38 s *pending*).
- Pętla zapisująca stan co 5 s i seria `ALERTS` w Prometheusie pozwoliły odtworzyć przebieg także po zamknięciu terminali.
- Prognozy zapisane przed testem (rollback, alert) pozwoliły ocenić wynik.

## 9. Co nie zadziałało / luki

- **Fałszywy alert po rollbacku** (patrz sekcja 7): critical alert na Telegramie bez awarii.
- Skrypt nie powiadamia o odrzuceniu ani o rollbacku.
- Po rollbacku skrypt nie wykonuje drugiej kontroli zdrowia (nie wiadomo, czy stan po rollbacku jest zdrowy).
- `main` w GitHubie pozostaje zepsuty po rollbacku, dopóki człowiek nie zrobi `git revert`.
- Walidacja (`promtool`) nie wykrywa celu, który nigdy nie odpowie. Taka usterka wychodzi dopiero po wdrożeniu.
- Dwa niewyjaśnione drobiazgi: seria `ALERTS` zaczyna się o 12:40:45, a pętla widziała *pending* już o 12:40:27; wcześniejszą godzinę *pending* przyjmujemy z pętli.
- Nie zapisano godzin wiadomości z Telegramu co do sekundy (tylko do minuty).
- Pętla została zamknięta przed końcem alertu. Dalszy przebieg odczytano z Prometheusa.

## 10. Wnioski i działania

| # | Działanie | Rodzaj |
|---|---|---|
| 1 | Test D2: powtórzyć scenariusz, ale po rollbacku przeładować konfigurację przez `/-/reload` (bez `--force-recreate` dla zmian samej konfiguracji). Prognoza do zapisania przed testem: alert nie wraca | pomiar |
| 2 | W `pull-deploy.sh` dla zmian samego `prometheus.yml` / `alerts.yml` używać `reload` zamiast odtworzenia kontenera; odtwarzać tylko przy zmianie `docker-compose.yml` | niezawodność |
| 3 | Wysyłać powiadomienie (Telegram) o `HEALTH CHECK FAILED` i `ROLLBACK done` | monitoring |
| 4 | Dodać kontrolę zdrowia po rollbacku i zapisać jej wynik w logu | niezawodność |
| 5 | Po rollbacku automatycznie lub z przypomnieniem wycofywać commit na `main` (albo zostawić gałąź testową) | proces |
| 6 | Rozważyć wyciszenie (silence) alertu na czas wdrożenia albo dłuższe `for:` dla `InstanceDown` | monitoring |
| 7 | Zapisywać prognozę i godziny przed testem; uruchamiać pętlę logującą przed pushem (zrobione w tym teście) | proces |
| 8 | Dopisać do notatnika różnice w czasach Alertmanagera: lab2 (10 s / 1 min) i VPS (30 s / 5 min) | proces |

## 11. Błędy popełnione w trakcie (nie wpłynęły na wynik testu)

| Błąd | Przyczyna | Rozwiązanie |
|---|---|---|
| `command:` w `lab2/docker-compose.yml` z 5 spacjami wcięcia | literówka przy edycji | `sed`, kontrola `docker compose config` i `yamllint` przed commitem |
| Założenie, że commit samych plików Markdown nic nie zrestartuje | skrypt używa `--force-recreate` przy każdym nowym commicie | odczyt `docker ps` i logu: kontenery zostały odtworzone |
| `ssh-add`: „Could not open a connection to your authentication agent" | brak działającego agenta w tym terminalu | `eval "$(ssh-agent -s)"` przed `ssh-add` |
| `ssh ovh cat ~/bin/aws-cost.sh`: „No such file" | tilda rozwinięta lokalnie | ścieżka w apostrofach: `ssh ovh 'cat ~/bin/aws-cost.sh'` |
| Pomylenie `repeat_interval: 4h` z „4 minutami" | odczyt konfiguracji | `group_interval` to 1 min, `repeat_interval` to 4 godziny |
| Zamknięcie obu terminali (pętla, `tail -f`) w trakcie testu | pomyłka | dane z pliku pętli i z serii `ALERTS` w Prometheusie |
| Poprzednie sprawdzenie `ssh -G` bez efektu | wykonane przed zapisaniem pliku | ponowne uruchomienie po zapisaniu |

## 12. Koszty i sprzątanie

- Brak zasobów chmurowych w tym teście, brak kosztów.
- Sprzątanie: zepsuty commit wycofany przez `git revert` (`8ed013d`, 12:50:26). Pliki `~/testA-push.txt`, `~/testA0-push.txt`, `~/testA-revert-push.txt` i `~/testA-loop.txt` zostają jako dowody (poza repozytorium).
- Wdrożenie wycofania: `DEPLOY OK` o 12:55:24, 8 celów w `/api/v1/targets`. Powiadomień na Telegramie po wycofaniu nie sprawdzano.
