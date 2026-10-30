# Postmortem: test awarii sre-lab widzianej z VPS przez tunel WireGuard (dział 11)

- **Data:** 30.10.2026
- **Czas:** podano w UTC i w czasie lokalnym (CET, UTC+1). Serwery (VPS) pracują w UTC, sre-lab pokazuje czas lokalny.
- **Autor:** Radosław Drzymała
- **Rodzaj zdarzenia:** zaplanowany test awarii (kontrolowane zatrzymanie usługi), nie incydent produkcyjny
- **Status:** zakończony, usługa przywrócona

## 1. Podsumowanie

Na VPS (OVHcloud, Niemcy) działa Prometheus z blackbox_exporterem i Alertmanagerem, który co 15 sekund sonduje przez tunel WireGuard endpoint zdrowia Prometheusa na sre-lab (`http://10.8.0.2:9090/-/healthy`) i wysyła alerty na Telegram osobnym botem. O 10:00:38 UTC (11:00:38 lokalnie) zatrzymano kontener Prometheusa na sre-lab. Alert `SreLabUnreachable` przeszedł w stan *firing* po ok. 5 min 54-57 s od zatrzymania, a wiadomość na Telegramie dotarła około 6 min 22 s - 7 min 21 s po zatrzymaniu (godzina znana z dokładnością do minuty: 11:07 lokalnie). O 10:07:14 UTC (11:07:14 lokalnie) kontener uruchomiono ponownie i w ciągu najwyżej 22 s alert wrócił do stanu nieaktywnego. Wiadomość *Resolved* przyszła o 11:12 lokalnie. Cała ścieżka (sonda → reguła → Alertmanager → Telegram) działa, ale **prognoza czasu powiadomienia była zbyt optymistyczna** (patrz sekcja 5 i 9).

## 2. Wpływ

- Brak użytkowników zewnętrznych (środowisko labowe).
- Prometheus na sre-lab (wraz z jego dashboardami i alertami labu) był niedostępny przez **6 min 36 s** (10:00:38 - 10:07:14 UTC). W tym czasie lab nie zbierał metryk (luka w danych).
- Nie sprawdzano, czy w tym czasie coś innego na sre-lab zostało dotknięte (np. cron wdrażający, który nie miał nowego commita).
- Alert nie został wyciszony przez regułę godzinową (test w oknie 08:00-22:00 UTC).

## 3. Środowisko

| Element | Wartość |
|---|---|
| VPS | OVHcloud, Niemcy (Limburg), 2 vCore, 4 GB RAM (+ swap 2 GB), Ubuntu 26.04, SSH tylko kluczem, `ufw` (SSH i UDP 51820) |
| Tunel | WireGuard `wg0`: VPS `10.8.0.1`, sre-lab `10.8.0.2`; opóźnienie ping 22,3-24,3 ms (3 pakiety) |
| Zapora na sre-lab | `ufw`: port 9090 z `10.8.0.1` tylko przez interfejs `wg0` |
| Monitoring na VPS | Docker Compose, `network_mode: host`, wszystko na `127.0.0.1` (Prometheus 9090, Alertmanager 9093, blackbox 9115), port klastra Alertmanagera (9094) wyłączony |
| Sondy | `http://10.8.0.2:9090/-/healthy` (sre-lab) i `https://github.com` (kontrola wyjścia VPS); interwał 15 s |
| Reguła | `SreLabUnreachable`: `probe_success == 0` i `hour()` w 8-22 UTC, `for: 5m`; `evaluation_interval` nie ustawiony (domyślnie 1 min) |
| Alertmanager | `group_wait: 30s`, `group_interval` domyślny (5 min), `repeat_interval: 4h`, osobny bot Telegram |
| Baseline sond | sre-lab 48 ms, github.com 20 ms (czas sondy) |

## 4. Oś czasu

| UTC | Lokalnie | Zdarzenie | Źródło |
|---|---|---|---|
| 09:45:17 | 10:45:17 | Alertmanager uruchomiony na VPS (log kontenera) | log kontenera |
| ok. 09:50 | 10:50 | test sztucznego alertu `TestAlert`: wiadomość na Telegramie dotarła o 10:50 lokalnie | Telegram (godzina do minuty) |
| **10:00:38** | **11:00:38** | **zatrzymanie kontenera `lab2-prometheus-1` na sre-lab** | `date -Is` (plik `~/testB-stop.txt`) |
| 10:06:19 | 11:06:19 | reguła `SreLabUnreachable` w stanie *pending* (pierwsza obserwacja; początek *pending* nie zarejestrowany) | odczyt API reguł na VPS |
| 10:06:32 | 11:06:32 | nadal *pending* | odczyt API reguł |
| **10:06:35** | **11:06:35** | **reguła w stanie *firing*** | odczyt API reguł |
| między 10:06:35 a 10:07:30 | między 11:06:35 a 11:07:30 | sonda ręczna z VPS: kod `000` (brak połączenia) | `curl` na VPS |
| 11:07 (minuta) | 11:07 | wiadomość *Firing* na Telegramie | Telegram (godzina do minuty) |
| 10:07:14 | 11:07:14 | **uruchomienie kontenera** (`docker start`) | `date -Is` (plik `~/testB-start.txt`) |
| 10:07:30 | 11:07:30 | reguła nadal *firing* | odczyt API reguł |
| między 10:07:30 a 10:07:36 | między 11:07:30 a 11:07:36 | sonda ręczna: kod `200` | `curl` na VPS |
| **10:07:36** | **11:07:36** | **reguła *inactive*** | odczyt API reguł |
| 11:12 (minuta) | 11:12 | wiadomość *Resolved* na Telegramie | Telegram (godzina do minuty) |

## 5. Wskaźniki (wyliczone z powyższych danych, obliczenia sprawdzone kodem)

| Wskaźnik | Wartość | Uwagi |
|---|---|---|
| Całkowity czas niedostępności Prometheusa na sre-lab | **6 min 36 s** (396 s) | 10:00:38 - 10:07:14 UTC |
| Zatrzymanie → *firing* w Prometheusie | **ok. 5 min 54 s - 5 min 57 s** | z odczytów 10:06:32 (jeszcze *pending*) i 10:06:35 (*firing*); dokładność kilku sekund |
| Zatrzymanie → wiadomość *Firing* na Telegramie | **6 min 22 s - 7 min 21 s** | godzina znana do minuty (11:07) |
| *Firing* → wiadomość na Telegramie | 25-84 s | zgodne z `group_wait: 30s` plus rozdzielczość do minuty |
| Start usługi → reguła *inactive* | **najwyżej 22 s** | pierwszy odczyt *inactive* o 10:07:36; odczyt z 10:07:30 jeszcze *firing* |
| Start usługi → wiadomość *Resolved* | 4 min 46 s - 5 min 45 s | zgodne z domyślnym `group_interval` 5 min (odstęp od poprzedniej wiadomości) |
| **Prognoza vs wynik** | prognoza 5,5-6 min, wynik 6,4-7,3 min | prognoza chybiona o ok. 0,5-1,3 min |

## 6. Wykrycie

Awarię wykrył Prometheus na VPS dzięki sondzie blackbox po tunelu. Powiadomienie dotarło na Telegram bez udziału człowieka. W tym teście osoba wykonująca test wiedziała o awarii od początku, więc nie zmierzono realnego czasu reakcji człowieka.

## 7. Przyczyna

Przyczyna była zamierzona: zatrzymanie kontenera Prometheusa na sre-lab poleceniem `docker stop`.

## 8. Co zadziałało dobrze

- Cała ścieżka alertu (sonda → reguła → Alertmanager → token z pliku → Telegram) zadziałała za pierwszym razem.
- Powrót do normy: reguła przestała być aktywna w ciągu 22 s po starcie usługi, a wiadomość *Resolved* dotarła bez interwencji.
- Reguła godzinowa (`hour()`) i osobny, ograniczony bot sprawiły, że alert nie dotyczy nocnego wyłączania komputera.
- Zabezpieczenia: wszystkie usługi nasłuchują na `127.0.0.1`, port klastra Alertmanagera zamknięty, firewall na sre-lab wpuszcza tylko VPS na jeden port przez `wg0`.
- Pomiary czasu zapisywane `date -Is` w plikach i odczytami z API, a nie z pamięci, z jawną konwersją UTC ↔ lokalny.

## 9. Co nie zadziałało / luki

- **Prognoza czasu powiadomienia była zbyt optymistyczna.** Przyjęto `for: 5m` plus 30 s `group_wait` (5,5-6 min). W konfiguracji nie ustawiono `evaluation_interval`, więc domyślnie reguły oceniane są **raz na minutę**; to prawdopodobnie wydłuża czas do *firing* o 0,5-1 min (odczyty *firing* i *inactive* występują obie o ok. :35 sekundy kolejnych minut, co jest zgodne z tą hipotezą, ale nie została ona sprawdzona w konfiguracji ani w logach).
- **Początek stanu *pending* nie został zarejestrowany** (pierwszy odczyt dopiero 10:06:19), więc nie sprawdzono, ile *pending* trwał.
- Godziny wiadomości z Telegramu znane tylko do minuty.
- **Nie przetestowano** zachowania reguły godzinowej poza oknem (noc) ani przejścia czasu zimowego/letniego (`hour()` liczy w UTC, więc okno przesunie się o godzinę).
- **Brak monitoringu samego VPS:** jeśli VPS padnie, nikt nie dostanie alertu (pojedynczy punkt awarii monitoringu).
- Nie sprawdzono wpływu przerwy na inne usługi sre-lab (np. czy lab wygenerował własne alerty po wznowieniu).
- Test przeprowadzono z jednego miejsca (VPS w Niemczech) i jedną awarią; brak testu awarii samego tunelu.

## 10. Wnioski i działania

| # | Działanie | Rodzaj |
|---|---|---|
| 1 | Ustawić `evaluation_interval: 15s` w `prometheus.yml` i powtórzyć test; porównać czas do *firing* z obecnym (hipoteza: skrócenie o 0,5-1 min) | pomiar |
| 2 | Przy kolejnym teście zapisywać także godzinę przejścia w *pending* (ciągłe odpytywanie API albo zapytanie `query_range` na `ALERTS` po teście) | proces |
| 3 | Dodać "dead man's switch": regułę zawsze aktywną, a wiadomość z zewnętrznej usługi, gdy cisza; alert, gdy VPS przestanie żyć | monitoring |
| 4 | Przetestować awarię samego tunelu (`wg-quick down wg0` na sre-lab) i odróżnić ją w alertach od awarii usługi | pomiar |
| 5 | Przetestować regułę godzinową poza oknem (np. tymczasowo zmienić zakres godzin) | pomiar |
| 6 | Zapisać pliki `~/monitoring` w repozytorium (`lab9/vps/`), bez `alertmanager.yml` z `chat_id` (do `.gitignore`) i bez sekretów | proces |
| 7 | Dodać sondy na AWS (ALB, instancje) z regułą Security Group tylko dla adresu VPS (`/32`) | rozwój |
| 8 | Rozważyć skrócenie `group_interval` dla *Resolved* albo zostawić (decyzja: czy 5 min do wiadomości o powrocie to akceptowalne) | konfiguracja |

## 11. Błędy popełnione w trakcie (nie wpłynęły na awarię)

| Błąd | Przyczyna | Rozwiązanie |
|---|---|---|
| `curl http://10.8.0.2:9090` z Maca nie działa | Mac nie jest w tunelu, a firewall wpuszcza tylko `10.8.0.1` przez `wg0` | to zamierzone; obserwacja z VPS |
| `FAILED: "/etc/prometheus/alerts.yml" does not point to an existing file` | `promtool` uruchomiony z plikami pod złą ścieżką w kontenerze | zamontować `prometheus.yml` i `alerts.yml` w `/etc/prometheus/` |
| wynik `probe_success` ucięty (`grep -A1`) | filtr `grep` nie pokazał drugiej linii tablicy | odczyt przez `python3` jedną linią na cel |
| `getUpdates` zwraca `[]` | do nowego bota nie wysłano jeszcze wiadomości `/start` | wysłać wiadomość botowi, powtórzyć |
| `Error: an inet prefix is expected rather than "exit"` | `echo "ss exit: $?"` wklejone tak, że powłoka wykonała `ss` | prostsze polecenie `grep -c` |
| port 9094 nasłuchuje na `*` | Alertmanager domyślnie otwiera port klastra | `--cluster.listen-address=` (puste) |
| plik z czatu nie w `~/Downloads` na sre-lab | pobrany na MacBooku | `scp` z Maca |

## 12. Koszty i sprzątanie

- Abonament VPS: ok. 19,20 zł miesięcznie (bez umowy terminowej), automatyczny backup bez dopłaty (rotacja 1, codziennie 16:56 UTC).
- Test nie wygenerował kosztów w AWS (nie uruchamiano zasobów).
- Sprzątanie: kontener Prometheusa na sre-lab uruchomiony ponownie (`docker start`), stan potwierdzony odczytem `200`.
