# Postmortem: test awarii backendu web1 za ALB w AWS (dział 10)

- **Data:** 29.10.2026
- **Czas:** lokalny (CET, UTC+1), o ile nie napisano inaczej. Prometheus UI, Ansible i systemd podają UTC (odejmij 1 h od czasu lokalnego).
- **Autor:** Radosław Drzymała
- **Rodzaj zdarzenia:** zaplanowany test awarii (kontrolowane wyłączenie usługi), nie incydent produkcyjny
- **Status:** zakończony, środowisko usunięte (`terraform destroy`)

## 1. Podsumowanie

Środowisko laboratoryjne zostało odtworzone w AWS (region eu-north-1) za pomocą Terraform: sieć VPC, dwie instancje EC2 z nginx (web1, web2) za Application Load Balancerem, a do tego instancja monitoringu (Prometheus, Grafana, blackbox_exporter w Dockerze) wdrożona Ansiblem. O 11:20:06 celowo zatrzymano nginx na web1. Prometheus wykrył awarię i uruchomił alert `WebBackendProbeFailing` (stan *firing* o 11:21:00). ALB po około 2 minutach przestał kierować ruch do web1, a przedtem zwracał błędy `502`. O 11:25:41 nginx uruchomiono ponownie i sonda wróciła do stanu poprawnego o 11:26:00. Moment powrotu web1 do puli ALB nie został zmierzony (najpóźniej 11:34:19).

## 2. Wpływ

- Brak rzeczywistych użytkowników (środowisko testowe).
- Z perspektywy klienta ALB: przez około 1,5–2 minuty żądania kierowane do web1 kończyły się odpowiedzią `502`. Liczby nieudanych żądań **nie zmierzono**. W pętli testowej zaobserwowano wyłącznie kody `502` (bez `503`).
- Po około 11:22 ALB obsługiwał ruch tylko z web2. W dwóch pętlach uruchomionych po 11:25:41 wszystkie 40 odpowiedzi to `200` z web2.
- Łączny czas, kiedy nginx na web1 był wyłączony: 5 min 35 s (11:20:06 – 11:25:41).

## 3. Środowisko

| Element | Wartość |
|---|---|
| Region | eu-north-1 (Sztokholm), dwie strefy dostępności |
| Sieć | VPC 10.0.0.0/16, podsieci 10.0.1.0/24 i 10.0.2.0/24, brama internetowa, Security Groups (HTTP z internetu, SSH i Prometheus/Grafana tylko z jednego adresu /32) |
| Backendy | web1 (10.0.1.44), web2 (10.0.2.139): `t3.micro`, Ubuntu 24.04, nginx |
| Load balancer | ALB, listener HTTP 80, health check `/` co 30 s, próg 3 nieudanych / 3 udanych |
| Monitoring | maszyna `mon` (`t3.small`): Prometheus, Grafana, blackbox_exporter. Alertmanager **nie** został wdrożony |
| Zarządzanie | Terraform (kod w `lab8/`), Ansible (`monitoring.yml`, `site.yml`) |

## 4. Oś czasu

| Godzina | Zdarzenie | Źródło |
|---|---|---|
| 10:15 | `terraform apply` (sieć, web1, web2, ALB) | notatka ręczna |
| 10:22 | pierwsze testy: web1 i web2 odpowiadają, ALB rozdziela 10 / 10 z 20 zapytań | log terminala |
| ok. 10:52–10:54 | `terraform apply` (maszyna `mon`, nowa reguła portu 9100) | log terminala |
| 11:06 | `ansible-playbook monitoring.yml`: `mon1` changed=8, web1 i web2 changed=1 | log terminala |
| 11:14 | powtórne uruchomienie playbooka: changed=0 na wszystkich maszynach | log terminala |
| **11:20:06** | **nginx zatrzymany na web1** (`ansible web1 -b -m service ... state=stopped`) | log systemd (10:20:06 UTC) |
| 11:20:30 | pierwsza próbka `probe_success=0` dla web1; alert w stanie *pending* | Prometheus (zapytanie `query_range`, krok 15 s) |
| **11:21:00** | **alert `WebBackendProbeFailing` → *firing*** | Prometheus |
| ok. 11:22 | ALB zwraca tylko odpowiedzi z web2 | obserwacja ręczna (dokładność do minuty) |
| **11:25:41** | **nginx uruchomiony ponownie** na web1 | `date` po komendzie |
| 11:26:00 | `probe_success=1`; alert nie jest już aktywny (ostatni punkt *firing*: 11:25:45) | Prometheus |
| 11:25:41 i później | dwie pętle po 20 zapytań do ALB: nadal same odpowiedzi z web2 | log terminala |
| 11:34:19 | 10 zapytań do ALB: 5 × web1, 5 × web2 (web1 z powrotem w puli) | log terminala |
| 11:36:15 | `terraform destroy` | `date` |
| 11:37:27 | `Destroy complete! Resources: 18 destroyed.` | `date` |

## 5. Wskaźniki (wyliczone z powyższych danych)

| Wskaźnik | Wartość | Uwagi |
|---|---|---|
| Czas od awarii do pierwszej próbki 0 | ok. 24 s | granica dokładności: krok zapytania 15 s i interwał zbierania 15 s |
| Czas od awarii do alertu *firing* (wykrycie) | **54 s** | w tym ok. 30 s w stanie *pending* (z wykresu; samej reguły `for` nie sprawdzano) |
| Czas, w którym ALB zwracał `502` | do ok. 11:22 (ok. 1,5–2 min) | zgodne z konfiguracją: 3 × 30 s = 90 s; liczby błędów nie zmierzono |
| Czas od startu nginx do udanej sondy | ok. 19 s | 11:25:41 → 11:26:00 |
| Czas od startu nginx do końca alertu | najpóźniej 19 s | ostatni punkt *firing* 11:25:45 |
| Czas powrotu web1 do puli ALB | **nie zmierzono** | między 11:25:41 a 11:34:19 (zgodnie z konfiguracją oczekiwane ok. 90 s po starcie) |
| Czas całkowity niedostępności web1 | 5 min 35 s | 11:20:06 – 11:25:41 |

## 6. Wykrycie

Awarię wykrył Prometheus (blackbox_exporter sonduje web1 po prywatnym adresie). Alert był widoczny w interfejsie na stronie `/alerts`. **W tym środowisku nie było Alertmanagera**, więc nikt nie dostałby powiadomienia. W praktyce wykryciem było ręczne spojrzenie na stronę z alertami.

## 7. Przyczyna

Przyczyna była zamierzona: ręczne zatrzymanie usługi nginx na jednym z dwóch backendów, żeby zmierzyć reakcję ALB i monitoringu.

## 8. Co zadziałało dobrze

- Sonda i alert wykryły awarię w czasie krótszym niż minuta.
- ALB sam wyłączył uszkodzony backend z puli i ruch przeszedł na web2 bez ingerencji człowieka.
- Naprawa była jednym poleceniem Ansible, a sonda wróciła w ciągu około 19 sekund.
- Monitoring zbudowany kodem (Terraform + Ansible) dał się odtworzyć od zera w około 40 minut, a po teście usunąć w około 1 minutę. Powtórne uruchomienie Ansible nic nie zmieniło (idempotentność).
- Dane historyczne w Prometheusie pozwoliły odtworzyć godziny, których nie zapisano ręcznie.

## 9. Co nie zadziałało / luki

- **Nie zapisano godzin na bieżąco.** Czas powrotu web1 do ALB i liczba zwróconych `502` są nieznane. Dodatkowo ręcznie zanotowane godziny okazały się błędne: godzinę z Prometheusa podanego w UTC wzięto za czas lokalny, a potwierdzona potem godzina alertu (11:22:22) nie zgadzała się z danymi (rzeczywiście 11:21:00). Obowiązują dane z metryk i logów, nie z pamięci.
- **Brak powiadomienia.** Bez Alertmanagera alert pozostaje tylko wpisem w interfejsie.
- Pierwsze uruchomienie pętli testowej nastąpiło po momencie wyłączenia backendu przez ALB, więc nie widzieliśmy, ile żądań zakończyło się błędem.
- Cały test odbył się na jednym adresie IP źródłowym (z domu), więc nie wiemy nic o zachowaniu przy dużej liczbie klientów.

## 10. Wnioski i działania

| # | Działanie | Rodzaj |
|---|---|---|
| 1 | Przed każdym testem awarii uruchamiać pętlę, która sama zapisuje godziny: `while true; do date -Is; curl -s -m 2 -o /dev/null -w '%{http_code}\n' http://$ALB; sleep 2; done \| tee test.log` | proces |
| 2 | Zapisywać godziny w UTC (`date -u`) albo zawsze podawać strefę | proces |
| 3 | Wdrożyć Alertmanager z powiadomieniem także w AWS i zmierzyć czas od awarii do powiadomienia | monitoring |
| 4 | Powtórzyć test z pomiarem liczby `502` i czasem powrotu do puli ALB | pomiar |
| 5 | Osobna Security Group dla ALB (instancje przyjmują port 80 tylko z ALB) | bezpieczeństwo |
| 6 | Zawęzić uprawnienia użytkownika IAM `terraform-radek` (obecnie `AdministratorAccess`) | bezpieczeństwo |
| 7 | Stan Terraforma przenieść do zdalnego backendu (S3) | niezawodność |
| 8 | Przed kolejną sesją sprawdzić, czy adres IP domu się nie zmienił (reguła SSH jest ograniczona do jednego `/32`) | operacje |

## 11. Błędy popełnione w trakcie dnia (nie wpłynęły na awarię)

| Błąd | Przyczyna | Rozwiązanie |
|---|---|---|
| `Error: No configuration files` | polecenie w katalogu bez plików `.tf` | `cd ~/sre-lab/lab8` |
| `fatal: pathspec 'lab8' did not match any files` | `git add lab8` z podkatalogu | `cd ~/sre-lab` |
| `Error: Argument or block definition required` (linia 87) | linia `vpc_id = ...` rozbita przy wklejaniu | uzupełnienie `= aws_vpc.lab.id` |
| `Could not resolve hostname adres_ip_web1` | w poleceniu został przykładowy tekst | podstawienie prawdziwego adresu |
| ostrzeżenie `Found both group and host with same name: mon` | host i grupa o tej samej nazwie | host przemianowany na `mon1` |
| rozbieżność godzin (10:20 vs 11:20) | Prometheus i Ansible podają UTC | konwersja do CET (+1 h), dane z `query_range` |

## 12. Koszty i sprzątanie

- Czas życia: web1, web2 i ALB ok. 1 h 22 min (10:15–11:37), `mon` ok. 44 min (ok. 10:53–11:37).
- `terraform destroy`: 11:36:15 – 11:37:27, 18 zasobów usuniętych.
- Kontrola w konsoli AWS: brak instancji, brak load balancerów, brak wolumenów, w VPC tylko domyślna sieć.
- Rachunek: w konsoli kosztów wszędzie 0 USD. Dane o zużyciu mogą pojawiać się z opóźnieniem do ok. doby, więc dokładny koszt i stan kredytów **do sprawdzenia kolejnego dnia**.
- Za wykonanie zadania „Explore AWS: Set up a cost budget" doliczono 20 USD kredytu (28.10.2026).
