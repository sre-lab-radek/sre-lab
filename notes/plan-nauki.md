# Plan nauki: z Application Systems Engineer do SRE / DevOps

Przygotowany dla: Radosław Drzymała

Założenia: ok. 10 godzin nauki tygodniowo (5 dni po 1 h + weekend po 2-2,5 h), horyzont 12 miesięcy, cel to pierwsza rola DevOps / SRE / Cloud Engineer, a docelowo widełki 15-20 tys. zł brutto miesięcznie. Jeśli możesz uczyć się więcej, plan skraca się proporcjonalnie, a jeśli mniej, rozciąga.

## 1. Punkt startowy i luka do zamknięcia

**Co już masz (realna przewaga nad osobami wchodzącymi od zera):**

- 3 lata w operacjach IT, w tym praca na produkcyjnych systemach dla klienta publicznego,
- incydenty, SLA, change management (ServiceNow, Jira), czyli język, którym mówi SRE,
- monitoring i obserwowalność (Dynatrace),
- patching, podatności, cykl życia serwerów,
- Linux i Windows, podstawy chmury (AWS Cloud Practitioner, OVH),
- angielski na poziomie roboczym i doświadczenie w pracy z zagranicznym klientem.

**Czego brakuje (to jest właściwa luka):**

- programowanie i skryptowanie (Python, Bash),
- Git i praca w repozytorium,
- infrastruktura jako kod (Terraform),
- kontenery i orkiestracja (Docker, Kubernetes),
- pipeline'y CI/CD,
- sieci na poziomie, który pozwala projektować, a nie tylko diagnozować,
- praktyka SRE: SLI/SLO, error budgets, postmortemy.

Główna zmiana: z "obsługuję i utrzymuję" na "buduję i automatyzuję". Każdy etap poniżej kończy się czymś, co możesz pokazać w repozytorium na GitHubie.

## 2. Harmonogram w skrócie

| Miesiące | Temat | Efekt na koniec etapu |
| --- | --- | --- |
| 1-2 | Python, Bash, Git, sieci | skrypty automatyzujące, pierwsze repozytorium |
| 3-4 | Docker, Terraform, AWS (poziom Associate) | infrastruktura na AWS zbudowana kodem, certyfikat SAA |
| 5-6 | CI/CD i obserwowalność | pipeline wdrażający aplikację, dashboardy i alerty |
| 7-9 | Kubernetes | klaster z aplikacją, certyfikat CKA lub równoważna praktyka |
| 10-12 | Praktyki SRE, portfolio, rekrutacja | gotowe CV, projekt końcowy, aplikacje |

## 3. Etap 1 (miesiące 1-2): fundamenty programistyczne

**Cel:** przestać bać się terminala i kodu, zacząć automatyzować drobne rzeczy z codziennej pracy.

**Czego się uczyć:**

- **Bash:** pętle, warunki, pipe'y, `grep`/`awk`/`sed`, `cron`, praca z logami, skrypty z argumentami.
- **Python:** składnia, funkcje, moduły, praca z plikami, JSON/YAML, biblioteka `requests` (API), `argparse`, obsługa błędów, podstawy testów (`pytest`).
- **Git:** commit, branch, merge, rebase, pull request, rozwiązywanie konfliktów, `.gitignore`.
- **Sieci:** model TCP/IP, DNS, HTTP/HTTPS, TLS, porty, NAT, load balancing, podsieci i CIDR. Narzędzia: `curl`, `dig`, `ss`, `tcpdump`, `traceroute`.

**Polecane materiały:**

- "Automate the Boring Stuff with Python" (darmowa książka online),
- "Pro Git" (darmowa książka online),
- kursy Linux i Bash na platformach typu KodeKloud, Linux Foundation lub Udemy,
- darmowe materiały Cloudflare Learning Center o DNS, HTTP i TLS,
- roadmap.sh/devops jako mapa tematów do odhaczania.

**Projekty do repozytorium:**

1. Skrypt Python, który odpytuje API (np. ServiceNow w wersji deweloperskiej albo publiczne API) i generuje raport z incydentów w CSV.
2. Skrypt Bash do rotacji logów i sprawdzania stanu dysków z alertem mailowym lub na Slacku.
3. Repozytorium z README po angielsku, bo tak będą je czytać rekruterzy.

## 4. Etap 2 (miesiące 3-4): Docker, Terraform, AWS

**Cel:** zbudować coś w chmurze wyłącznie z kodu.

**Czego się uczyć:**

- **Docker:** obrazy, Dockerfile, warstwy, multi-stage build, wolumeny, sieci, Docker Compose, dobre praktyki bezpieczeństwa obrazów.
- **Terraform:** provider, resource, variable, output, moduły, state (zdalny backend w S3 z blokadą), `plan`/`apply`, struktura projektu.
- **AWS (pogłębienie ponad Cloud Practitioner):** IAM (role, polityki, zasada najmniejszych uprawnień), VPC (podsieci, route tables, NAT, security groups), EC2, S3, RDS, ALB, Route 53, CloudWatch, Lambda.

**Certyfikat na koniec etapu:** AWS Certified Solutions Architect – Associate. Dobry wybór po Cloud Practitioner, bo jest szeroko rozpoznawalny i zmusza do poznania usług w praktyce. Do ćwiczeń z egzaminu przydają się zestawy próbne (np. Tutorials Dojo) i kursy z dużą ilością labów.

**Projekty do repozytorium:**

1. Aplikacja w kontenerze (prosty serwis w Pythonie lub Node), spakowana Dockerfile'em i uruchamiana przez Compose z bazą danych.
2. **Projekt flagowy nr 1:** infrastruktura w Terraformie na AWS: VPC z podsieciami publicznymi i prywatnymi, ALB, instancje (lub ECS) z aplikacją, baza RDS, zdalny state. Cały stos stawiany jedną komendą i usuwany drugą.
3. Uwaga na koszty: ustaw budżet i alerty rozliczeniowe w AWS od pierwszego dnia i zawsze kasuj zasoby po ćwiczeniach (`terraform destroy`).

## 5. Etap 3 (miesiące 5-6): CI/CD i obserwowalność

**Cel:** zautomatyzować wdrażanie i zobaczyć, jak system zachowuje się w produkcji. Tu Twoje doświadczenie z Dynatrace daje przewagę.

**Czego się uczyć:**

- **CI/CD:** GitHub Actions (lub GitLab CI): build, testy, skanowanie, publikacja obrazu do rejestru, wdrożenie, środowiska, sekrety, strategie wdrożeń (rolling, blue/green, canary).
- **Bezpieczeństwo w pipeline'ie:** skanowanie obrazów (Trivy), skanowanie zależności, sekrety poza repozytorium. Łączy się to z Twoim doświadczeniem w zarządzaniu podatnościami.
- **Monitoring i logi:** Prometheus, Grafana, Alertmanager, podstawy PromQL, logowanie (Loki lub ELK), OpenTelemetry jako standard śledzenia.
- **Konfiguracja:** podstawy Ansible do zarządzania konfiguracją serwerów (bliskie Twojej pracy z patchingiem).

**Projekty do repozytorium:**

1. **Projekt flagowy nr 2:** pipeline, który po pushu buduje obraz, skanuje go, publikuje i wdraża na infrastrukturę z poprzedniego etapu.
2. Stos Prometheus + Grafana monitorujący Twoją aplikację, z dashboardem (cztery złote sygnały: opóźnienie, ruch, błędy, nasycenie) i alertami.
3. Playbook Ansible do automatycznego patchowania grupy serwerów. Jeśli to możliwe, zaproponuj podobne usprawnienie w obecnej pracy.

## 6. Etap 4 (miesiące 7-9): Kubernetes

**Cel:** poznać standard orkiestracji kontenerów, który pojawia się w większości ogłoszeń DevOps/SRE.

**Czego się uczyć:**

- architektura: control plane, węzły, etcd, scheduler,
- obiekty: Pod, Deployment, Service, Ingress, ConfigMap, Secret, StatefulSet, Job/CronJob,
- wolumeny i storage, RBAC, NetworkPolicy, resource requests/limits, probes,
- **Helm** do paczkowania aplikacji, podstawy **Kustomize**,
- **GitOps** (Argo CD lub Flux),
- diagnostyka: `kubectl describe`, logi, eventy, typowe awarie (CrashLoopBackOff, ImagePullBackOff, OOMKilled).

**Certyfikat:** CKA (Certified Kubernetes Administrator). Egzamin jest praktyczny, w terminalu, dlatego dużo wart na rynku. Trenuj na symulatorze (killer.sh jest dołączany do egzaminu) i kursach z labami (KodeKloud).

**Gdzie ćwiczyć tanio:** lokalnie `kind` lub `minikube`, a do wersji chmurowej EKS z Terraformem (pamiętaj o kosztach i kasowaniu klastra).

**Projekt flagowy nr 3:** klaster Kubernetes na AWS (EKS) zbudowany Terraformem, aplikacja wdrażana przez Helm i Argo CD, monitoring w Prometheus/Grafana, autoskalowanie.

## 7. Etap 5 (miesiące 10-12): praktyki SRE, portfolio i rekrutacja

**Cel:** pokazać myślenie SRE i zamienić umiejętności w ofertę pracy.

**Czego się uczyć:**

- **Fundamenty SRE:** SLI, SLO, SLA, error budget, toil i jego eliminacja, ocena ryzyka. Podstawa: darmowa książka "Site Reliability Engineering" od Google (dostępna online) oraz "The Site Reliability Workbook".
- **Zarządzanie incydentami:** role (incident commander), komunikacja, **postmortemy bez szukania winnych**. Masz tu przewagę, bo incydenty to Twoja codzienność.
- **Odporność i niezawodność:** testy obciążeniowe (k6), podstawy chaos engineeringu, backupy i odtwarzanie po awarii, wysoka dostępność w wielu strefach.
- **Projektowanie systemów:** skalowanie, cache, kolejki, bazy danych, kompromisy. Przydaje się na rozmowach rekrutacyjnych.

**Projekt końcowy:** weź swój projekt flagowy nr 3 i dołóż:

- zdefiniowane SLO oraz dashboard i alerty oparte na error budget,
- test obciążeniowy,
- dokument postmortemu z symulowanej awarii (co się stało, wpływ, przyczyna, wnioski, działania naprawcze),
- runbook dla najczęstszych alertów.

## 8. Rytm tygodnia (przy ok. 10 h)

- **Pon-czw:** po 1 h teorii lub kursu wieczorem.
- **Piątek:** 1 h przeglądu tygodnia i notatek.
- **Sobota:** 2-3 h laboratoriów i projektu (najważniejsza sesja).
- **Niedziela:** wolne albo 1-2 h na powtórki lub dokończenie projektu.

Zasada: **70% praktyki, 30% teorii**. Samo oglądanie kursów nie daje kompetencji, daje ją zepsucie czegoś i naprawienie. Prowadź notatki (np. w Markdownie w repozytorium), bo to też materiał do portfolio i do rozmów.

## 9. Wykorzystaj obecną pracę

Najszybszy skrót do roli DevOps/SRE często prowadzi przez bieżącego pracodawcę:

- od około miesiąca 2 zacznij automatyzować drobne zadania (raporty, sprawdzanie stanu serwerów, szablony zgłoszeń) i zapisuj efekt w liczbach, np. "skróciłem czas przygotowania raportu z 2 godzin do 5 minut",
- zapytaj przełożonego o udział w projektach infrastrukturalnych, automatyzacjach lub zespołach cloud/DevOps w DXC. Wewnętrzny transfer jest zwykle łatwiejszy niż rekrutacja z zewnątrz,
- upewnij się, że to, co automatyzujesz, jest zgodne z zasadami bezpieczeństwa klienta. Nie przenoś danych ani kodu klienta do prywatnych repozytoriów.

## 10. Zmiany w CV i profilu

- Zmień nagłówek na wariant typu "Cloud / DevOps Engineer (SRE-oriented)" dopiero, gdy będziesz mieć 2-3 projekty w repozytorium.
- Dodaj sekcję **Projects** z linkami do GitHuba i krótkim opisem (cel, technologie, efekt).
- Wpisz liczby: ile aplikacji i serwerów obsługujesz, jaki jest wolumen incydentów, jaka jest zgodność z SLA, ile czasu zaoszczędziła automatyzacja.
- Popraw literówki ("Proffesional", "Englishlanguage", "Crossfunctional", "ITSM Dynatrace") i rozważ wersję CV po angielsku bez zdjęcia pod rynek międzynarodowy.
- Uporządkuj LinkedIn tym samym językiem słów kluczowych (Terraform, Kubernetes, AWS, CI/CD, observability, SRE).

## 11. Rekrutacja: kiedy i jak aplikować

- **Od miesiąca 6-7** zaczynaj aplikować na stanowiska **Junior/Mid DevOps, Cloud Engineer, Platform Support, Site Reliability (junior)**. Nie czekaj na idealne przygotowanie, bo rozmowy same pokażą luki.
- Szukaj na Just Join IT, No Fluff Jobs, Pracuj.pl, LinkedIn oraz u firm z dużymi centrami usług we Wrocławiu i pracą zdalną.
- Przygotuj opowieści z realnych incydentów (sytuacja, działanie, efekt) oraz krótkie omówienie swoich trzech projektów flagowych.
- Powtórz tematy z rozmów technicznych: Linux, sieci, Docker, Kubernetes, Terraform, CI/CD, monitoring, podstawy projektowania systemów.

## 12. Realistyczne widełki i ścieżka zarobków

Poniższe kwoty są orientacyjne (brutto miesięcznie, B2B lub UoP, rynek polski) i zależą od firmy, miasta oraz pracy zdalnej. Sprawdzaj aktualne dane w ogłoszeniach z widełkami.

| Etap | Rola | Orientacyjny poziom |
| --- | --- | --- |
| Dziś | Application Systems Engineer | obecne wynagrodzenie |
| Po ok. 12-18 miesiącach | Junior/Mid DevOps lub Cloud Engineer | zwykle ok. 10-15 tys. zł |
| Po 2-3 latach | Mid/Senior DevOps lub SRE | zwykle ok. 15-20 tys. zł |
| Po 4+ latach | Senior SRE / Platform Engineer | często 20 tys. zł i więcej, szczególnie dla firm zagranicznych |

Najsilniejsze dźwignie podnoszące stawkę: praca dla zagranicznych firm lub z zagranicznymi klientami, B2B zamiast UoP, specjalizacja (Kubernetes na dużą skalę, bezpieczeństwo, wydajność) oraz udokumentowane projekty z wymiernym efektem.

## 13. Najczęstsze pułapki

1. **Kolekcjonowanie kursów bez projektów.** Każdy etap musi kończyć się repozytorium.
2. **Skakanie po technologiach.** Zostań przy jednej chmurze (AWS), a jednym narzędziu z danej kategorii (Terraform, GitHub Actions) do momentu opanowania.
3. **Zbyt wczesne CKA lub zbyt wiele certyfikatów.** Certyfikat ma potwierdzać praktykę, nie ją zastępować. Dwa dobrze dobrane (SAA i CKA) wystarczą.
4. **Niekontrolowane koszty chmury.** Budżet, alerty rozliczeniowe i `destroy` po każdym ćwiczeniu.
5. **Wypalenie.** Przy nauce po pracy lepiej 1 h dziennie przez rok niż 5 h w weekend przez miesiąc. Planuj tygodnie lżejsze.
6. **Brak dokumentowania.** Notatki, README i opisy projektów to później CV i materiał na rozmowy.

## 14. Lista kontrolna kamieni milowych

- [ ] Pierwszy skrypt Python i Bash w repozytorium (miesiąc 2)
- [ ] Aplikacja w kontenerze z Docker Compose (miesiąc 3)
- [ ] Infrastruktura AWS w Terraformie (miesiąc 4)
- [ ] Certyfikat AWS Solutions Architect – Associate (miesiąc 4)
- [ ] Pipeline CI/CD ze skanowaniem (miesiąc 5)
- [ ] Dashboard i alerty w Prometheus/Grafana (miesiąc 6)
- [ ] Pierwsze aplikacje na stanowiska DevOps/Cloud (miesiąc 6-7)
- [ ] Klaster Kubernetes z Helm i Argo CD (miesiąc 8-9)
- [ ] Certyfikat CKA (miesiąc 9)
- [ ] Projekt końcowy z SLO, testem obciążeniowym i postmortemem (miesiąc 11)
- [ ] Zaktualizowane CV i LinkedIn, aktywna rekrutacja (miesiąc 10-12)

## 15. Jak korzystać z tego planu

Traktuj go jako szkielet, nie sztywny harmonogram. Co 4-6 tygodni zrób przegląd: co zrobiłeś, co Cię blokuje, czy tempo jest realne. Jeśli któryś etap idzie szybciej, przejdź dalej, a jeśli wolniej, nie przeskakuj tematu, bo luki z fundamentów wracają na rozmowach i w pracy.

## 16. Rozwój labu: AWS i VPS (dopisano 29.10.2026)

Po etapie 2 lab rośnie w stronę hybrydy (domowy sre-lab, VPS w OVHcloud, AWS). Kolejność: najpierw punkty 2 i 3 (zamykają zaległości), potem 1.

| # | Zadanie | Czego uczy | Kolejność |
| --- | --- | --- | --- |
| 1 | Monitoring AWS z VPS: Prometheus i blackbox\_exporter na VPS sondują ALB i instancje; w Terraformie reguła Security Group wpuszcza port 9100 i sondy tylko z adresu VPS (/32); osobna maszyna mon w AWS niepotrzebna | niezależny monitoring, Security Groups, oszczędność kredytów | 3 |
| 2 | Zdalny stan Terraforma w S3 (szyfrowanie, wersjonowanie) | backendy, blokady, bezpieczeństwo stanu | 1 |
| 3 | Backup restic z VPS i sre-lab do S3, użytkownik IAM tylko do jednego bucketa | zasada 3-2-1, least privilege, test przywracania | 2 |
| 4 | Jeden inwentarz Ansible dla VPS i EC2 oraz wspólna rola hardeningu (SSH, ufw, fail2ban, aktualizacje) | idempotencja, jeden kod na wiele środowisk | 4 |
| 5 | Alerty kosztów: AWS Budgets (e-mail) i Telegram z VPS; codzienny skrypt aws-cost.sh już działa w cronie | koszty jako element SRE | 5 |
| 6 | Route53 z health checkiem i przełączaniem (failover) między AWS a VPS; wymaga domeny | DNS, failover | później |

W kolejce obok: WireGuard między VPS a sre-lab, zewnętrzny monitoring uptime z alertem na Telegram, hardening VPS jako playbook Ansible (lab9/), strona z postmortemami (portfolio, wymaga domeny).

Zasady przy tych zadaniach: w AWS reguły dostępu tylko z /32 (VPS lub dom), klucze tylko w \~/.aws/credentials, po sesji w chmurze terraform destroy i kontrola konsoli (bucket na stan i kopie jest wyjątkiem), na VPS nigdy klucze administratora AWS.
