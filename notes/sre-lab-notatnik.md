# SRE Lab – notatnik do nauki

Ten plik to Twoja ściąga i podręcznik z laboratorium. Rośnie po każdym dziale. Na końcu każdego działu dopisuję:
co zrobiliśmy, na co uważać, nowe pojęcia i nowe polecenia.

Wersja: 4 (działy 0-11 z ćwiczeniami, stan na 30.10.2026)

## Jak czytać ten plik

- `[sre-lab]` = polecenie wpisujesz na serwerze Ubuntu (PC, przez SSH lub terminal VS Code Remote-SSH).
- `[MAC]` = polecenie lub czynność na MacBooku.
- `[VPS]` = polecenie na serwerze VPS w OVHcloud (przez `ssh ovh`).
- Bloki z kodem YAML, skryptami i konfiguracją wklejasz **do edytora** (VS Code), nie do terminala.
- Do terminala wklejasz tylko polecenia powłoki (bash).
- Pojęcia po angielsku podaję w oryginale, bo tak są w ogłoszeniach i na rozmowach. Obok jest wyjaśnienie po polsku.
- Rzeczy niepewne oznaczam słowem **hipoteza**. Rzeczy sprawdzone oznaczam **potwierdzone**.
- Na końcu każdego działu jest sekcja **Ćwiczenia**: pytania, odpowiedzi pod spodem (zakryj je kartką i spróbuj odpowiedzieć sam) i jedno zadanie praktyczne.
- Plik leży w repozytorium: `notes/sre-lab-notatnik.md`. Na końcu nauki zrobimy z niego PDF.

---

## 1. Mapa środowiska (ściąga)

### Urządzenia

| Nazwa | Co to jest | Adres |
|---|---|---|
| MAC | MacBook M1, 8 GB RAM, ARM. Tylko edytor, terminal, przeglądarka | – |
| sre-lab | PC i5-12700K, 32 GB RAM, Ubuntu na osobnym dysku SATA 500 GB. Windows na M.2 | 192.168.100.2 |
| web1 | maszyna wirtualna (KVM), nginx | 192.168.122.14 |
| web2 | maszyna wirtualna, nginx | 192.168.122.175 |
| db1 | maszyna wirtualna, PostgreSQL | 192.168.122.11 |
| lb1 | maszyna wirtualna, nginx jako load balancer | 192.168.122.20 |
| VPS | OVHcloud, Limburg, Ubuntu 26.04, 2 vCore, 4 GB RAM, działa 24/7 | tunel: 10.8.0.1 (sre-lab ma 10.8.0.2) |

### Porty usług

| Usługa | Port |
|---|---|
| SSH | 22 |
| Prometheus | 9090 |
| Alertmanager | 9093 |
| Grafana | 3000 |
| blackbox_exporter | 9115 |
| node_exporter | 9100 |
| nginx | 80 |
| WireGuard | UDP 51820 |
| Alertmanager (klaster) | 9094 (wyłączony przez `--cluster.listen-address=`) |

### Struktura repozytorium sre-lab

```
sre-lab/
  README.md
  .gitignore            (ignoruje lab2/secrets/)
  .yamllint             (reguły lintera)
  .github/workflows/validate.yml   (CI)
  lab1/                 maszyny wirtualne, Ansible, patching
  lab2/                 Prometheus, Grafana, Alertmanager, blackbox (docker compose)
  lab3/                 test obciążeniowy k6, postmortem nginx
  lab5/                 load balancer
  lab6/                 postmortem CI
  lab7/                 postmortem CD
  lab8/                 Terraform (AWS), Ansible dla AWS, postmortem-aws.md
  lab9/                 postmortem monitoringu z VPS (kopie konfiguracji bez sekretów)
  notes/                ten notatnik i plan nauki
```

Poza repozytorium (celowo): `~/deploy/` (skrypt wdrażający, kopia konfiguracji, token Telegrama).

### Zasady, które warto zapamiętać z całego labu

1. Sekrety (token, hasło, klucz prywatny) nigdy nie trafiają do repozytorium ani do czatu.
2. Przed każdym `git commit` czytasz `git status`.
3. Po zmianie pliku konfiguracji usługa musi ją wczytać (restart lub reload). Zapisany plik to jeszcze nie zmiana na serwerze.
4. Test awarii: zapisz `date` przed i po. Bez godzin nie zmierzysz czasu wykrycia.
5. Hipotezę oddzielaj od faktu.
6. W chmurze nic nie zostaje na noc: po sesji `terraform destroy` i kontrola konsoli.
7. Godziny testów bierz z metryk i logów (uwaga na UTC), nie z pamięci.
8. Monitoring musi działać poza maszyną, którą pilnuje.
9. Prognozę wyniku testu zapisuj przed testem. Rozbieżność uczy najwięcej.
10. Po każdym zakończonym dziale dopisujemy wszystko do tego notatnika.

---

## 2. Dział 0 – Środowisko, dual boot, SSH

### Co zrobiliśmy
Ubuntu Server na dysku SATA (`sda`), Windows zostaje na M.2 (`nvme0n1`). Dostęp z Maca przez SSH kluczem. Skrót `ssh sre-lab`.

### Kluczowe informacje
- Dyski w Linuksie: `sda` (SATA) i `nvme0n1` (M.2). Instalator pracuje tylko na dysku docelowym.
- Każdy system ma własny bootloader, więc aktualizacja jednego nie psuje drugiego. Przełączasz się menu rozruchowym (F11 na MSI).
- SSH używa pary kluczy: prywatny zostaje u Ciebie, publiczny trafia na serwer do `~/.ssh/authorized_keys` (robi to `ssh-copy-id`).
- Plik `~/.ssh/config` na MAC pozwala skrócić połączenie do `ssh sre-lab`:

```
Host sre-lab
    HostName 192.168.100.2
    User radek
    IdentityFile ~/.ssh/klucz
    IdentitiesOnly yes
```

### Na co uważać
- Przy pierwszym połączeniu SSH pyta o odcisk klucza hosta (fingerprint). Odpowiedz pełnym słowem `yes`.
- Hasło w terminalu się nie wyświetla (nawet gwiazdek). To normalne.
- Wyłączenie logowania hasłem (`PasswordAuthentication no`) dopiero po sprawdzeniu, że klucz działa, i z otwartą drugą sesją.
- Klucz zapisany pod własną nazwą (np. `klucz`) wymaga `-i klucz` albo wpisu `IdentityFile` w configu.
- `ssh-copy-id`: błąd "No identities found" oznacza brak klucza w domyślnym miejscu.

### Typowe błędy z tej sesji
- `quote>` w terminalu: został otwarty apostrof lub cudzysłów bez zamknięcia. Wyjście: **Ctrl+C**.
- Heredoc (`<< 'EOF'`) wklejony z wcięciem przed `EOF` się nie zamyka. Linia z samym `EOF` musi zaczynać się od pierwszego znaku. Prościej: twórz pliki w edytorze albo używaj `printf`.
- VS Code tworzy nowy plik w zaznaczonym folderze. Pliki w konkretnym miejscu najpewniej tworzy się terminalem: `mkdir -p`, `touch`, potem edycja w edytorze (**Cmd+P**, nazwa pliku).

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Który plik na MAC pozwala skrócić `ssh -i ~/.ssh/klucz radek@192.168.100.2` do `ssh sre-lab`?
2. Który z pary kluczy SSH zostaje u Ciebie, a który trafia na serwer? Do jakiego pliku?
3. Co oznacza znak zachęty `quote>` w terminalu i jak z niego wyjść?
4. Dlaczego heredoc (`<< 'EOF'`) wklejony z wcięciem przed `EOF` się nie zamyka?
5. Jak w instalatorze odróżnić dysk z Windowsem od dysku docelowego Linuksa?
6. Dlaczego nie wyłączasz logowania hasłem (`PasswordAuthentication no`), zanim sprawdzisz klucz?
7. Co robi `ssh-copy-id`?

**Odpowiedzi**

1. `~/.ssh/config` z wpisem `Host sre-lab` (`HostName`, `User`, `IdentityFile`).
2. Prywatny zostaje u Ciebie. Publiczny trafia na serwer do `~/.ssh/authorized_keys`.
3. Powłoka czeka na zamknięcie apostrofu lub cudzysłowu, który został otwarty. Wyjście: **Ctrl+C**.
4. Znacznik końca (`EOF`) musi zaczynać się od pierwszego znaku linii. Spacje przed nim sprawiają, że powłoka go nie rozpoznaje.
5. Po nazwie urządzenia (`nvme0n1` to Windows na M.2, `sda` to dysk SATA), rozmiarze, modelu i typie partycji (NTFS). Pomaga `lsblk -o NAME,SIZE,MODEL,FSTYPE`.
6. Jeśli klucz nie działa, odetniesz sobie dostęp do serwera. Zostaw też otwartą drugą sesję na czas zmiany.
7. Dopisuje Twój klucz publiczny do `~/.ssh/authorized_keys` na serwerze, żeby logować się bez hasła.

**Zadanie praktyczne:** na MAC zrób wpis w `~/.ssh/config` dla `sre-lab`, połącz się samym `ssh sre-lab` i sprawdź `whoami` oraz `hostname`.

---

## 3. Dział 1 – Docker, Kubernetes (kind), Terraform, Ansible, narzędzia

### Co zrobiliśmy
Zainstalowaliśmy Docker Engine, kubectl, Helm, Terraform, Ansible i kind. Klaster kind (Kubernetes w kontenerach), test z nginx.

### Kluczowe informacje
- **Docker** uruchamia aplikacje w kontenerach (obraz = szablon, kontener = działająca instancja).
- **kind** to Kubernetes w Dockerze, do nauki i testów. Klaster tworzy się w kilkanaście sekund.
- Stan węzła: `NotReady` zaraz po utworzeniu jest normalny, po chwili `Ready`.
- Pod: `ContainerCreating` (pobiera obraz) → `Running`.
- Dodanie użytkownika do grupy `docker` daje praktycznie prawa roota na maszynie. Na własnym labie to normalne, w pracy bywa ograniczane.

### Na co uważać
- Repozytorium HashiCorp nie miało katalogu dla nowego wydania Ubuntu (`resolute`). Obejście: użyć katalogu `noble`. Plik repozytorium (`/etc/apt/sources.list.d/hashicorp.list`) trzeba faktycznie utworzyć, bo brak pliku = brak pakietu.
- `kubectl` nie powinien być starszy niż jedna wersja minor względem klastra. Snap miał starszą wersję, więc zainstalowaliśmy binarkę z dl.k8s.io.
- Problem z DNS w kind: węzeł nie pobierał obrazu (`server misbehaving`), bo resolver sieci kind przekazywał zapytania do lokalnego stuba hosta. Naprawa: ustawić serwery DNS dla Dockera w `/etc/docker/daemon.json` i zrestartować Dockera. Test: `docker exec kind-control-plane getent hosts registry-1.docker.io`.
- `docker compose down` bez `-v` zachowuje wolumeny (dane). Z `-v` je usuwa.

### Polecenia
```bash
docker run hello-world
kind create cluster
kubectl get nodes
kubectl create deployment test-nginx --image=nginx
kubectl get pods -w
kubectl describe pod -l app=test-nginx | tail -20     # sekcja Events pokazuje przyczynę błędu
kind delete cluster
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Czym różni się obraz Dockera od kontenera?
2. Dlaczego `NotReady` zaraz po utworzeniu klastra kind jest normalne?
3. Gdzie w wyniku `kubectl describe pod` szukasz przyczyny problemu?
4. Co oznacza stan `ImagePullBackOff` i jaka była jego przyczyna u nas?
5. Dlaczego `kubectl` w wersji 1.35 przy klastrze 1.37 jest problemem?
6. Czym różni się `docker compose down` od `docker compose down -v`?
7. Dlaczego członkostwo w grupie `docker` to w praktyce uprawnienia roota?
8. Dlaczego pakiet Terraform nie znalazł się w `apt` mimo poprawnej instalacji klucza?

**Odpowiedzi**

1. Obraz to szablon (tylko do odczytu), kontener to jego działająca instancja.
2. Węzeł dopiero uruchamia sieć i kubelet. Po kilkudziesięciu sekundach powinien być `Ready`.
3. W sekcji **Events** na samym dole wyniku.
4. Pod nie może pobrać obrazu. U nas winny był DNS w sieci kind (`server misbehaving`): węzeł przekazywał zapytania do lokalnego stuba hosta. Naprawa: serwery DNS w `/etc/docker/daemon.json`.
5. Oficjalnie wspierana różnica to jedna wersja minor w obie strony. Dwie wersje to już poza wsparciem, choć proste polecenia zwykle działają.
6. Bez `-v` kontenery i sieci znikają, ale wolumeny (dane) zostają. Z `-v` wolumeny też są usuwane.
7. Kto może kontrolować Dockera, może uruchomić kontener z zamontowanym systemem plików hosta i zmieniać je jako root.
8. Plik repozytorium (`/etc/apt/sources.list.d/hashicorp.list`) nie powstał, a katalog dla najnowszego wydania Ubuntu mógł nie istnieć. Użyliśmy katalogu `noble`.

**Zadanie praktyczne:** utwórz klaster kind, uruchom deployment z `nginx`, zepsuj go (np. nazwa obrazu z literówką), znajdź przyczynę w Events i usuń klaster.

---

## 4. Dział 2 – Maszyny wirtualne (KVM, libvirt, cloud-init)

### Co zrobiliśmy
Trzy maszyny z obrazu chmurowego Ubuntu 24.04 (`web1`, `web2`, `db1`), potem `lb1`. Konfiguracja przy starcie przez cloud-init (użytkownik `sre`, klucz SSH, hostname).

### Kluczowe informacje
- **KVM** to wirtualizacja w jądrze Linuksa, **libvirt** to warstwa zarządzania (`virsh`).
- **Obraz bazowy** (`noble-base.img`) jest tylko do odczytu. Każda maszyna ma własny dysk **qcow2** oparty na obrazie bazowym (backing file), więc zajmuje mało miejsca.
- **cloud-init** czyta plik `user-data` (z dysku cdrom `seed.iso`) i konfiguruje maszynę przy pierwszym starcie.
- Sieć `default` w libvirt: zakres 192.168.122.0/24, DHCP, NAT do internetu.
- **Rezerwacja DHCP po MAC** (`virsh net-update ... ip-dhcp-host`) daje stały adres IP maszynie.

### Na co uważać
- `qemu-kvm` jest pakietem wirtualnym. Instaluj `qemu-system-x86`.
- Maszyny nie startują same po restarcie hosta, dopóki nie zrobisz `virsh autostart NAZWA`. Objaw: `No route to host` ze wszystkich maszyn.
- Sieć `default` też potrzebuje `virsh net-autostart default`.
- Adresy z DHCP mogą się zmienić. Dlatego rezerwacje po MAC.
- `kvm-ok` musi zwrócić `KVM acceleration can be used`. Jeśli nie, włącz wirtualizację (VT-x) w BIOS-ie.

### Polecenia
```bash
virsh list --all                       # wszystkie maszyny i ich stan
virsh start web2 / virsh shutdown web2
virsh autostart web1
virsh net-list --all
virsh net-dhcp-leases default          # adresy IP maszyn
virsh undefine NAZWA                   # usuwa definicję maszyny (dyski usuwasz osobno)
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Dlaczego instalujemy `qemu-system-x86`, a nie `qemu-kvm`?
2. Co robi cloud-init przy pierwszym starcie maszyny?
3. Czym jest backing file w dysku qcow2 i co daje?
4. Po restarcie PC wszystkie maszyny dają `No route to host`. Jaka jest najczęstsza przyczyna i naprawa?
5. Jak nadać maszynie stały adres IP?
6. Jak sprawdzić aktualne adresy IP maszyn?
7. Co sprawdza `kvm-ok` i co zrobić, gdy zgłasza problem?

**Odpowiedzi**

1. `qemu-kvm` jest pakietem wirtualnym (apt prosi o wybór konkretnego). `qemu-system-x86` to właściwy pakiet.
2. Czyta `user-data` (z dysku cdrom `seed.iso`) i konfiguruje hostname, użytkownika i klucz SSH.
3. Dysk maszyny zapisuje tylko różnice względem wspólnego obrazu bazowego. Oszczędza miejsce i pozwala szybko tworzyć nowe maszyny.
4. Maszyny nie mają włączonego autostartu i po restarcie hosta są wyłączone. Naprawa: `virsh start NAZWA`, na stałe `virsh autostart NAZWA` (oraz `virsh net-autostart default` dla sieci).
5. Rezerwacja DHCP po adresie MAC: `virsh net-update default add ip-dhcp-host ...`.
6. `virsh net-dhcp-leases default`.
7. Czy procesor i BIOS udostępniają wirtualizację (`/dev/kvm`). Gdy nie: włącz Intel Virtualization Technology (VT-x) w BIOS-ie.

**Zadanie praktyczne:** zatrzymaj maszynę `web2` (`virsh shutdown web2`), sprawdź `virsh list --all`, uruchom ją ponownie i zmierz, po jakim czasie odpowiada na `ping`.

---

## 5. Dział 3 – Ansible

### Co zrobiliśmy
Inwentarz (`inventory.ini`), `ansible.cfg`, test `ping`, playbooki: `patch.yml` (aktualizacje), `site.yml` (nginx na web, PostgreSQL na db), `node-exporter.yml`.

### Kluczowe informacje
- **Inventory** to lista maszyn i grup (`[web]`, `[db]`, `[lb]`, `[lab:children]`).
- **Playbook** to opis stanu, który chcesz uzyskać (YAML). **Task** to pojedynczy krok. **Module** (np. `apt`, `service`, `copy`) to narzędzie wykonujące krok.
- **Idempotentność:** drugie uruchomienie tego samego playbooka nie zmienia niczego (`changed=0`). To najważniejsza cecha Ansible i infrastruktury jako kodu.
- `become: true` oznacza uruchamianie jako root (sudo).
- `serial: 1` wykonuje playbook po jednej maszynie naraz, tak jak w prawdziwym patchowaniu.
- **Handler** wykonuje się tylko wtedy, gdy zadanie zgłosi zmianę (np. `reload nginx`).
- `--check` to tryb próbny, nic nie zmienia.

### Na co uważać
- **`ansible.cfg` jest czytany tylko z katalogu, z którego uruchamiasz Ansible.** Uruchomienie z innego katalogu daje `Permission denied (publickey)` (zły użytkownik i klucz). Zawsze pracuj z `~/sre-lab/lab1`.
- PLAY RECAP: sprawdzaj `failed=0` i `unreachable=0`.
- `host_key_checking = False` jest akceptowalne tylko w labie.
- `skipped` nie jest błędem (np. restart, który nie był potrzebny).

### Polecenia
```bash
cd ~/sre-lab/lab1
ansible all -m ping
ansible all -m command -a "uptime"
ansible-playbook patch.yml --check
ansible-playbook patch.yml
ansible-playbook patch.yml -e do_reboot=true
ansible web2 -b -m ansible.builtin.service -a "name=nginx state=stopped"
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Co to jest idempotentność i jak ją zweryfikować w Ansible?
2. Dlaczego uruchomienie playbooka z katalogu `lab5` dało `Permission denied (publickey)`?
3. Co robi `serial: 1` i po co się go używa przy patchowaniu?
4. Czym różni się `--check` od `--syntax-check`?
5. Kiedy wykonuje się handler?
6. Czy `skipped=1` w PLAY RECAP to błąd?
7. Do czego służy `become: true`?
8. Wyjaśnij polecenie `ansible web2 -b -m ansible.builtin.service -a "name=nginx state=stopped"`.

**Odpowiedzi**

1. Wielokrotne wykonanie playbooka daje ten sam stan i nie wprowadza nowych zmian. Weryfikacja: drugie uruchomienie pokazuje `changed=0`.
2. `ansible.cfg` jest czytany z katalogu, z którego uruchamiasz Ansible. W `lab5` nie było go, więc Ansible użył domyślnego użytkownika (`radek`) i klucza zamiast `sre` i `lab_vm`.
3. Wykonuje playbook po jednej maszynie naraz. Przy patchowaniu ogranicza skutki błędu: jeśli pierwsza maszyna się wywali, reszta pozostaje nietknięta.
4. `--check` to tryb próbny na maszynach (symuluje zmiany, niczego nie wprowadza). `--syntax-check` tylko sprawdza składnię pliku, bez łączenia się z maszynami.
5. Tylko wtedy, gdy zadanie, które go zgłasza (`notify`), faktycznie coś zmieniło.
6. Nie. Zadanie zostało pominięte, bo warunek nie był spełniony (np. restart nie był potrzebny).
7. Uruchamia zadania z uprawnieniami roota (sudo).
8. Na maszynie `web2` (host z inwentarza) uruchamia moduł `service`, który zatrzymuje usługę `nginx`. Flaga `-b` oznacza `become` (jako root).

**Zadanie praktyczne:** dopisz do `site.yml` zadanie tworzące plik `/etc/motd` z nazwą hosta (`{{ inventory_hostname }}`) i uruchom playbook dwa razy. Za pierwszym razem ma być `changed`, za drugim nie.

---

## 6. Dział 4 – Monitoring (Prometheus, Grafana, node_exporter, blackbox)

### Co zrobiliśmy
`node_exporter` na maszynach (Ansible), Prometheus, Grafana i blackbox_exporter w Dockerze (docker compose, `network_mode: host`). Dashboard Node Exporter Full (ID 1860). Pierwszy alert `InstanceDown`.

### Kluczowe informacje
- **Prometheus** zbiera metryki (pull): co `scrape_interval` odpytuje adresy (targets) i zapisuje wartości w czasie.
- **Exporter** udostępnia metryki w formacie tekstowym pod `/metrics` (node_exporter: CPU, pamięć, dysk, sieć).
- **blackbox_exporter** sprawdza usługi z zewnątrz (probe), np. HTTP. Metryka `probe_success` ma wartość 1 (sukces) lub 0.
- Metryka `up`: 1 gdy ostatnie zbieranie się udało, 0 gdy nie.
- **Alert rule** ma `expr` (wyrażenie PromQL) i `for` (jak długo warunek musi trwać). Stany: **pending** → **firing** → **resolved**.
- Reguły są oceniane co `evaluation_interval` (domyślnie 1 minuta). Zbieranie danych (`scrape_interval`) to osobne ustawienie.
- Czas wykrycia ≈ scrape + evaluation + `for` + opóźnienia Alertmanagera. Nasze pomiary: ok. 2 min przy `evaluation_interval` 1m, ok. 1 min przy 15 s.
- Grafana używa czasu przeglądarki. Prometheus (wykresy) domyślnie UTC. W Polsce jesienią UTC+1.

### Na co uważać
- Po zmianie `prometheus.yml` **trzeba zrestartować lub przeładować Prometheusa**. `docker compose up -d` nie odtwarza kontenera, jeśli zmienił się tylko zamontowany plik.
- Wcięcia w YAML to spacje. Złe wcięcie = Prometheus nie wstanie. Logi: `docker compose logs prometheus --tail 20`.
- Zaraz po restarcie cele mają stan `unknown`, a po kilkunastu sekundach `up`. Sprawdzaj po chwili.
- Brak danych na wykresie przed uruchomieniem monitoringu to nie awaria.
- Hasło Grafany `admin/admin` zmień przy pierwszym logowaniu.
- Monitorowanie hosta (`up`, node_exporter) nie wykrywa awarii aplikacji. Do tego służy sonda HTTP (blackbox).
- `ALERTS_FOR_STATE` to znacznik czasu (w sekundach Uniksa) wejścia alertu w stan pending. Zamień: `date -d @NUMER`.

### Polecenia
```bash
docker compose ps
docker compose logs prometheus --tail 20
docker compose restart prometheus
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[a-z]*"' | sort | uniq -c
curl -s http://localhost:9090/api/v1/alertmanagers
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Czym różni się `scrape_interval` od `evaluation_interval`?
2. Co oznacza wynik `up == 0` i `probe_success == 0`?
3. Opisz trzy stany alertu i rolę parametru `for`.
4. Dlaczego monitorowanie samego `up` nie wykrywa awarii nginx na działającej maszynie?
5. W Prometheusie alert pojawił się o 15:28. Która to godzina w Polsce w październiku po zmianie czasu na zimowy?
6. Co trzeba zrobić po edycji `prometheus.yml`, żeby zmiana zadziałała?
7. Co zawiera `ALERTS_FOR_STATE` i jak zamienić tę wartość na godzinę?
8. Dlaczego zaraz po restarcie Prometheusa część celów ma stan `unknown`?

**Odpowiedzi**

1. `scrape_interval` to jak często zbierane są dane z celów. `evaluation_interval` to jak często oceniane są reguły alertów.
2. `up == 0`: ostatnie zbieranie metryk z celu się nie udało. `probe_success == 0`: sonda (np. HTTP) nie dostała poprawnej odpowiedzi.
3. `pending` (warunek spełniony, ale jeszcze nie przez cały czas `for`), `firing` (spełniony przez całe `for`, alert idzie do Alertmanagera), `resolved` (warunek przestał być spełniony). `for` zapobiega fałszywym alarmom przy krótkich zacięciach, ale warunek jest sprawdzany tylko przy ocenie reguł.
4. `up` mówi tylko o tym, czy można zebrać metryki z `node_exporter`. Maszyna i exporter mogą żyć, mimo że nginx nie działa. Do tego potrzebna jest sonda HTTP.
5. 16:28. Prometheus pokazuje UTC, a Polska jesienią to UTC+1.
6. Przeładować lub zrestartować Prometheusa (`docker compose restart prometheus`). Samo zapisanie pliku nie wystarcza.
7. Znacznik czasu (sekundy od 1970 roku) wejścia alertu w stan pending. Zamiana: `date -d @NUMER`.
8. Prometheus nie zdążył jeszcze zrobić pierwszego zbierania danych. Po kilkunastu sekundach cele mają stan `up`.

**Zadanie praktyczne:** zatrzymaj nginx na `web2`, zapisz `date` przed zatrzymaniem i zmierz czas do alertu na Telegramie. Porównaj z wynikiem ok. 1 minuty.

---

## 7. Dział 5 – SLO i test obciążeniowy

### Co zrobiliśmy
Reguły SLO w Prometheusie (recording rules), dashboard `Web SLO` w Grafanie, test obciążeniowy k6 (100 i 1000 użytkowników), symulacja awarii nginx.

### Kluczowe informacje
- **SLI** (Service Level Indicator): co mierzysz (u nas: odsetek udanych sond HTTP).
- **SLO** (Service Level Objective): cel dla SLI (u nas: 99% w oknie 6 godzin).
- **SLA**: umowa z klientem, zwykle z karami. SLO jest wewnętrzne i ostrzejsze.
- **Error budget**: ile możesz zawalić. 1% z 6 godzin = 216 s = 14,4 nieudanej próbki przy próbkowaniu co 15 s.
- **Recording rule** zapisuje wynik zapytania jako nową metrykę (np. `sli:availability:ratio_6h`).
- **Percentyle**: `p(95)` to wartość, poniżej której mieści się 95% próbek. Mediana (p50) potrafi być bez zmian, gdy "ogon" (p95, max) już rośnie. Średnia ukrywa problemy.
- **Cztery złote sygnały**: latency (opóźnienie), traffic (ruch), errors (błędy), saturation (nasycenie).
- **k6**: `stages` zmienia liczbę wirtualnych użytkowników (VU) w czasie, `thresholds` to progi zaliczenia testu.

### Wyniki z laba
- 100 VU: 440 zapytań/s, 0% błędów, p95 = 1,82 ms.
- 1000 VU: 3743 zapytania/s, 0% błędów, p95 = 3,89 ms, max 61 ms, CPU web1 ok. 33%.
- Wniosek: nginx na małej statycznej stronie wytrzymuje dużo. Generator (k6) działał na tym samym PC, więc pomiar jest zaniżony.
- Awaria nginx na web2 (ok. 2,25 minuty zarejestrowane): budżet błędów spadł do 37,5%. Panel "dostępność" pokazał 94,8%, bo historia była krótsza niż 6 godzin.

### Na co uważać
- Panel dostępności w oknie 6 godzin wprowadza w błąd, dopóki nie ma 6 godzin danych. Budżet błędów (dzielony przez stałe okno) jest wiarygodniejszy.
- W Grafanie zapytania filtruj po `job` (np. `{job="blackbox-lb"}`), bo po zmianie reguł stare serie zostają widoczne.
- Czerwony kolor przy 100% to domyślne progi Grafany. Zmień progi (Thresholds).
- Test obciążeniowy z tego samego komputera zawyża zużycie CPU.

### Przydatne zapytania PromQL
```
probe_success{job="blackbox-lb"}
probe_duration_seconds * 1000
avg_over_time(probe_success{job="blackbox-lb"}[6h])
min_over_time(probe_success{job="blackbox-lb"}[20m])
sum_over_time((1 - probe_success{job="blackbox-lb"})[20m:15s])
slo:error_budget_remaining:ratio_6h{job="blackbox-lb"}
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Wyjaśnij SLI, SLO i SLA jednym zdaniem każde.
2. Oblicz budżet błędów dla SLO 99% w oknie 6 godzin przy sondowaniu co 15 sekund.
3. Oblicz, ile minut niedostępności dopuszcza SLO 99,9% w 30 dniach.
4. Dlaczego p95 jest lepszą miarą niż średnia?
5. Wymień cztery złote sygnały.
6. Dlaczego panel dostępności pokazał 94,8%, a budżet błędów 37,5%?
7. Dlaczego test obciążeniowy uruchomiony na tym samym PC zawyża wyniki?
8. Co oznacza `min_over_time(probe_success[20m]) = 1`?

**Odpowiedzi**

1. SLI to mierzony wskaźnik, SLO to cel dla tego wskaźnika, SLA to umowa z klientem (zwykle z konsekwencjami).
2. 1% z 6 godzin to 216 sekund, czyli 14,4 nieudanej próbki (216 / 15).
3. 30 dni to 43 200 minut, 0,1% z tego to 43,2 minuty.
4. Średnia ukrywa wolne zapytania. p95 pokazuje, jak długo czeka najwolniejsze 5% użytkowników. W teście k6 mediana się nie zmieniła, a p95 i maksimum już tak.
5. Latency (opóźnienie), traffic (ruch), errors (błędy), saturation (nasycenie).
6. Panel dostępności liczył średnią z dostępnych danych (mniej niż 6 godzin historii), a budżet dzielił przez stałe okno 6 godzin. Budżet jest tu wiarygodniejszy.
7. Generator i testowane serwery rywalizują o ten sam procesor, pamięć i sieć, więc mierzysz też obciążenie samego generatora.
8. W ciągu ostatnich 20 minut sonda ani razu nie zawiodła (minimum to 1).

**Zadanie praktyczne:** uruchom test k6 z `target: 1000` i podczas testu obserwuj CPU `web1` w Grafanie. Zapisz p95, maksimum i zużycie CPU.

---

## 8. Dział 6 – Alertmanager i powiadomienia na Telegramie

### Co zrobiliśmy
Alertmanager (docker compose), bot Telegram, token w pliku poza repozytorium, `chat_id` w konfiguracji, test sztucznym alertem i prawdziwą awarią.

### Kluczowe informacje
- Prometheus **ocenia** reguły, Alertmanager **odbiera** alerty, grupuje je i **wysyła powiadomienia**.
- Parametry trasy: `group_by` (jak łączyć alerty), `group_wait` (czekanie przed pierwszym powiadomieniem), `group_interval` (odstęp między powiadomieniami o zmianach w grupie), `repeat_interval` (jak często przypominać o trwającym alercie), `send_resolved` (wysyłaj też "naprawione").
- `RESOLVED` przychodzi z opóźnieniem względem faktycznej naprawy (ocena reguły + grupowanie).
- Alert wysłany ręcznie przez API wygasa sam po ok. 5 minutach.
- Token bota jest hasłem. Wyciek = `/revoke` u BotFather i nowy token.

### Na co uważać
- Prometheus musi znać Alertmanagera (`alerting:` w `prometheus.yml`) i być zrestartowany. Diagnoza: `curl localhost:9090/api/v1/alertmanagers` (`activeAlertmanagers` nie może być puste).
- Token czytaj do pliku przez `read -rs TOKEN` wpisane **osobno**, a dopiero potem wklej token. Wklejony w tej samej linii zapisze się w historii (`~/.bash_history`).
- `chat_id` poznasz z `getUpdates` po wysłaniu wiadomości do swojego bota.
- Wpis `lab2/secrets/` w `.gitignore` chroni nowe pliki. Plik już dodany do poczekalni trzeba wyjąć: `git restore --staged PLIK`.
- `git add lab2/` bierze **cały** katalog (z sekretami, jeśli nic ich nie ignoruje). Zawsze czytaj `git status`.
- Kontener Alertmanagera działa jako użytkownik `nobody` (uid 65534). Plik tokenu: `chown 65534:65534`, `chmod 600`.

### Polecenia
```bash
docker run --rm --entrypoint amtool -v "$PWD/alertmanager.yml:/a.yml:ro" \
  -v "$PWD/secrets/telegram_token:/etc/alertmanager/telegram_token:ro" \
  prom/alertmanager check-config /a.yml
curl -s -XPOST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"info"},"annotations":{"summary":"Test"}}]'
git check-ignore -v lab2/secrets/telegram_token
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Jaka jest różnica ról Prometheusa i Alertmanagera?
2. Wyjaśnij `group_wait`, `group_interval` i `repeat_interval`.
3. Jak sprawdzić, że Prometheus zna Alertmanagera?
4. Dlaczego polecenie `read -rs TOKEN` wpisujesz osobno, a token wklejasz dopiero w następnej linii?
5. Co robi `git restore --staged PLIK`?
6. Jak sprawdzić, że `.gitignore` chroni dany plik?
7. Co robisz, gdy token bota wyciekł?
8. Dlaczego `git add lab2/` jest ryzykowne?

**Odpowiedzi**

1. Prometheus ocenia reguły i wysyła alerty. Alertmanager je odbiera, grupuje i wysyła powiadomienia (np. na Telegram).
2. `group_wait`: ile czekać przed pierwszym powiadomieniem o nowej grupie. `group_interval`: jak długo czekać przed powiadomieniem o zmianach w istniejącej grupie. `repeat_interval`: co ile przypominać o trwającym alercie.
3. `curl -s http://localhost:9090/api/v1/alertmanagers`. Lista `activeAlertmanagers` nie może być pusta.
4. Wklejony w tej samej linii trafia do historii powłoki i jest interpretowany jako polecenie lub nazwa zmiennej (stąd błąd `not a valid identifier`). Przy `read -rs` w osobnej linii tekst się nie wyświetla i nie ląduje w historii.
5. Wyjmuje plik z poczekalni (staged), zostawiając go na dysku.
6. `git check-ignore -v ŚCIEŻKA`. Wynik wskazuje linię `.gitignore`, która go obejmuje.
7. Unieważnij go u BotFather (`/revoke`), wygeneruj nowy, zapisz w pliku poza repozytorium i sprawdź historię repozytorium (`git log --all -- ścieżka`).
8. Dodaje cały katalog, więc razem z plikami, których nie chciałeś (np. sekretami), jeśli nic ich nie ignoruje. Zawsze czytaj `git status` przed commitem.

**Zadanie praktyczne:** wyślij sztuczny alert przez API (`curl -XPOST localhost:9093/api/v2/alerts ...`) i sprawdź, po ilu sekundach przyjdzie na Telegram (spodziewane ok. 10 sekund przez `group_wait`).

---

## 9. Dział 7 – Load balancer (nginx)

### Co zrobiliśmy
`lb1` z nginx jako reverse proxy przed `web1` i `web2`. Osobna sonda przez load balancer (`blackbox-lb`), SLO liczone z perspektywy użytkownika, alerty podzielone na backend (warning) i usługę (critical).

### Kluczowe informacje
- **Reverse proxy** przyjmuje żądania od użytkownika i przekazuje je do serwerów za sobą.
- **upstream** w nginx to lista backendów. Domyślnie round-robin (po kolei).
- `max_fails` i `fail_timeout` oznaczają backend jako niedostępny po błędach. `proxy_next_upstream` ponawia żądanie na innym backendzie.
- Nagłówek `X-Served-By` pokazuje, który backend odpowiedział.
- **SPOF** (single point of failure): `lb1` sam jest pojedynczym punktem awarii.
- Wynik testu: po zatrzymaniu nginx na web2, 20 z 20 żądań przez load balancer obsłużył web1. Użytkownik nie zauważył awarii. Budżet błędów usługi zostal na 100%. Alert `WebBackendProbeFailing` (warning) przyszedł po ok. 1 minucie.

### Na co uważać
- Alerty dziel wg wpływu na użytkownika: awaria jednego backendu = warning, awaria usługi = critical.
- Mierz SLO tam, gdzie widzi je użytkownik (sonda przez load balancer).
- Uruchamiaj playbooki z `lab1` (patrz dział Ansible).

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Czym jest reverse proxy?
2. Co robi `proxy_next_upstream`?
3. Dlaczego rozdzielamy alerty na backendowy (warning) i usługowy (critical)?
4. Co to jest SPOF i co nim jest w tym labie?
5. Jakie trzy dowody pokazały, że awaria `web2` była niewidoczna dla użytkownika?
6. Dlaczego SLO mierzymy przez sondę na load balancerze, a nie na pojedynczych serwerach?
7. Do czego służy nagłówek `X-Served-By`?

**Odpowiedzi**

1. Serwer przyjmujący żądania od użytkowników i przekazujący je do serwerów za nim (backendów).
2. Gdy backend zwróci błąd lub nie odpowie, nginx ponawia to samo żądanie na innym backendzie z listy.
3. Awaria jednego backendu przy działającym load balancerze nie psuje usługi (człowiek ma o niej wiedzieć, ale bez pilności). Awaria całej usługi to sytuacja krytyczna.
4. Pojedynczy punkt awarii. Tu przede wszystkim `lb1`, a także sam PC `sre-lab`, na którym stoją wszystkie maszyny i monitoring.
5. 20 z 20 żądań obsłużył `web1`, `min_over_time(probe_success{job="blackbox-lb"}[20m])` wyniosło 1, a budżet błędów usługi został na 100%.
6. Użytkownik widzi usługę, a nie pojedyncze serwery. Cel jakości dotyczy tego, co czuje klient.
7. Pokazuje, który backend (adres z `$upstream_addr`) obsłużył żądanie.

**Zadanie praktyczne:** zatrzymaj nginx na `web1` zamiast `web2` i sprawdź, że 20 żądań dostaje odpowiedź tylko od `web2`. Zapisz, który alert przyszedł.

---

## 10. Dział 8 – CI (GitHub Actions)

### Co zrobiliśmy
Workflow `validate.yml`: yamllint, `ansible-playbook --syntax-check`, `promtool check config`, `amtool check-config`, `docker compose config -q`. Uruchamia się przy każdym pushu i pull requeście.

### Kluczowe informacje
- **CI** (Continuous Integration) automatycznie sprawdza każdą zmianę.
- **Runner** to maszyna wykonująca zadania. `ubuntu-latest` to runner hostowany przez GitHub.
- Pipeline zatrzymuje się na pierwszym kroku z błędem, kolejne są pomijane.
- Linter (yamllint) sprawdza składnię i styl YAML. Walidatory narzędziowe (promtool, amtool) sprawdzają **znaczenie** (np. czy wyrażenie PromQL jest poprawne). Potrzebne są oba.
- W CI użyliśmy fałszywego tokenu (`dummy-token`), żeby walidator znalazł plik. Prawdziwy token nigdy nie trafia do CI.

### Wyniki z laba
- #1 czerwony (11 s): brak nowej linii na końcu 9 plików (`new-line-at-end-of-file`).
- #2, #3 zielone. #3 po podniesieniu `actions/checkout` z v4 do v6 (znikło ostrzeżenie o Node 20).
- Test z zepsutą regułą na gałęzi: czerwony na kroku `promtool` z komunikatem wskazującym plik, linię i regułę.
- Kolejne przebiegi zielone, także dla commitów z błędnym portem (składnia poprawna).

### Na co uważać
- Włącz w VS Code (Remote [SSH: sre-lab]) ustawienie **Files: Insert Final Newline**.
- Błędy kopiowania (np. `-qr` zamiast `-q`) wyłapuj odczytem pliku przed commitem (`tail`, `cat`).
- Zielone CI nie znaczy, że konfiguracja działa. CI nie wie, czy cel istnieje.
- Testy awarii rób na gałęzi, nie na `main`.
- Wersje akcji się starzeją (Node 20 → 24). Sprawdzaj stronę wydań akcji.

### Polecenia
```bash
yamllint -f parsable .
git checkout -b test-broken-alert
git push -u origin test-broken-alert
git push origin --delete test-broken-alert
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Czym różni się `yamllint` od `promtool`?
2. Dlaczego CI było zielone dla commita ze złym portem celu?
3. Po co w kroku z Alertmanagerem jest `dummy-token`?
4. Co znaczy, że pipeline zatrzymuje się na pierwszym kroku z błędem?
5. Dlaczego pojawił się błąd `new-line-at-end-of-file` i jak mu zapobiec?
6. Co oznaczało ostrzeżenie o Node 20 i jak je usunęliśmy?
7. Dlaczego testy psujące konfigurację robimy na osobnej gałęzi?
8. Który krok zawiódł w teście z zepsutą regułą alertu i co pokazał komunikat?

**Odpowiedzi**

1. `yamllint` sprawdza składnię i styl YAML. `promtool` rozumie znaczenie konfiguracji Prometheusa (np. czy wyrażenie PromQL jest poprawne).
2. Składnia była poprawna, a CI nie wie, czy cel `:9199` istnieje. Taki błąd wychodzi dopiero w kontroli po wdrożeniu.
3. Walidator wymaga istnienia pliku z tokenem. Prawdziwy token nigdy nie trafia do CI ani do repozytorium.
4. Kolejne kroki są pomijane. Naprawiasz pierwszy błąd i dopiero wtedy widzisz kolejne.
5. Pliki tworzone w edytorze nie miały pustej linii na końcu. Zapobiega temu ustawienie VS Code **Files: Insert Final Newline** (w ustawieniach Remote [SSH: sre-lab]).
6. Akcja `actions/checkout@v4` działała na Node 20, który jest wycofywany. Podnieśliśmy ją do `v6` (Node 24).
7. Żeby nie zostawić `main` w złym stanie i nie wdrożyć błędu. Gałąź usuwasz po teście.
8. Krok z `promtool` (`Check Prometheus config and rules`). Komunikat wskazał plik, linię, grupę i regułę: `alerts.yml: 5:15: group "lab", rule 1, "InstanceDown": could not parse expression`.

**Zadanie praktyczne:** na osobnej gałęzi zmień w `lab2/alertmanager.yml` linię `receiver: telegram` na `receiver: nieistniejacy`, wypchnij gałąź i sprawdź, który krok CI się zawali (spodziewany jest krok z `amtool`, bo trasa wskazuje nieistniejącego odbiorcę). Potem usuń gałąź.

---

## 11. Dział 9 – CD (wdrażanie przez pobieranie)

### Co zrobiliśmy
Skrypt `~/deploy/pull-deploy.sh` w cronie co 5 minut. Pobiera `main`, waliduje konfigurację, wdraża do `~/deploy/lab2`, sprawdza, czy wszystkie cele są `up`, w razie problemu cofa zmiany.

### Kluczowe informacje
- **CD** (Continuous Delivery/Deployment) automatycznie wdraża zmiany po przejściu kontroli.
- Dlaczego **nie** self-hosted runner: runner w publicznym repozytorium mógłby wykonać kod z obcego pull requesta. Zmiana repozytorium na prywatne nie powiodła się (przycisk nie reagował, przyczyny nie znaleziono). Wybrano wdrażanie przez pobieranie (pull): serwer sam pobiera zmiany i nie przyjmuje poleceń z zewnątrz.
- Skrypt leży **poza** repozytorium, więc zwykły commit nie zmieni kodu uruchamianego na serwerze.
- **Rollback**: przywrócenie poprzedniej konfiguracji (kopia w `.previous/`).
- **Health check** z ponawianiem (12 prób co 5 s), bo zaraz po restarcie Prometheus pokazuje `0 targets` lub `unknown`.
- Każdy commit jest obsługiwany raz (`last_sha`). Poprawką jest nowy commit (`git revert`).
- `flock -n` w cronie zapobiega równoległemu uruchomieniu dwóch wdrożeń.

### Trzy warstwy kontroli (z testów)
| Test | Zmiana | CI | Walidacja na serwerze | Kontrola po wdrożeniu | Wynik |
|---|---|---|---|---|---|
| A, B | zły port celu (`:9199`) | zielone | przeszła | **nie przeszła** | rollback po ok. 63 s |
| C | zepsute wyrażenie PromQL | **czerwone** | **odrzucone** | nie dotarło | nic nie wdrożono |

### Fałszywy alert (otwarte pytanie)
`InstanceDown` dla nieistniejącego już celu `192.168.122.14:9199` wysłał `Firing` (ok. 20:26 UTC) i `Resolved` (ok. 20:34 UTC), mimo że rollback już się odbył.
- **Hipoteza 1:** kontener został odtworzony zamiast przeładowany, więc stara seria nie dostała znacznika wygaśnięcia, a Prometheus przez ok. 5 minut (okno "staleness") widział ostatnią wartość 0. Dane zgadzają się z tym (seria widoczna do 20:34:09).
- **Hipoteza 2:** stan alertu został odtworzony po restarcie (może tłumaczyć `pending → firing` w 7 s przy `for: 1m`). Nie sprawdzona.
- Niewyjaśnione: dlaczego pierwszy alert pojawił się dopiero po ok. 2 minutach.
- Pomysł naprawy do przetestowania: przeładowanie konfiguracji w działającym procesie (`--web.enable-lifecycle` i `curl -X POST localhost:9090/-/reload`).

### Na co uważać
- Dwa takie same testy pod rząd zostawiają `main` w złym stanie. Cofnij od razu.
- Zapisuj wynik pierwszego uruchomienia i godziny testów. Bez tego wymiary trzeba odtwarzać z logów (`git reflog --date=iso`, wykresy).
- Cron potrzebuje pełnych ścieżek i `PATH` w skrypcie.

### Polecenia
```bash
~/deploy/pull-deploy.sh; echo "exit: $?"      # 0 bez komunikatu = brak nowego commita
crontab -l
tail -20 ~/deploy/deploy.log
grep -E "new commit|DEPLOY OK|ROLLBACK|REJECTED|FAILED" ~/deploy/deploy.log
git revert --no-edit HEAD
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Dlaczego nie użyliśmy self-hosted runnera w tym repozytorium?
2. Czym różni się wdrażanie push od pull?
3. Co robi `flock -n` w wpisie crona?
4. Dlaczego kontrola po wdrożeniu ma ponawianie (12 prób co 5 sekund)?
5. Do czego służy katalog `.previous/` przy wdrożeniu?
6. Dlaczego skrypt wdrażający leży poza repozytorium?
7. Dlaczego test C (zepsuty PromQL) skończył się inaczej niż test A (zły port)?
8. Jak rozumiesz hipotezę o fałszywym `InstanceDown` i jak ją sprawdzić?
9. Co oznacza, że `pull-deploy.sh` zakończył się kodem 0 bez żadnych komunikatów?

**Odpowiedzi**

1. Repozytorium jest publiczne, a runner na własnym serwerze w publicznym repo mógłby wykonać kod z cudzego pull requesta. Zmiana repozytorium na prywatne nie powiodła się.
2. Push: system zewnętrzny łączy się z serwerem i wypycha zmiany. Pull: serwer sam, cyklicznie, sprawdza repozytorium i pobiera zmiany. Pull nie przyjmuje poleceń z zewnątrz.
3. Zapobiega równoległemu uruchomieniu dwóch kopii skryptu. Gdy poprzednia jeszcze trwa, nowa się nie uruchamia (`-n` = bez czekania).
4. Zaraz po restarcie Prometheus pokazuje `0 targets` lub część celów `unknown`. Bez ponawiania każde wdrożenie byłoby błędnie cofane.
5. Przechowuje poprzednią, działającą konfigurację, do której skrypt wraca przy rollbacku.
6. Zwykły commit nie może zmienić kodu uruchamianego na serwerze, a skrypt ma dostęp do sekretów i do Dockera.
7. W teście C błędna składnia została zatrzymana przez CI i przez walidację na serwerze, zanim cokolwiek zostało wdrożone. W teście A składnia była poprawna, więc CI i walidacja przeszły, a błąd (nieistniejący cel) wykryła dopiero kontrola po wdrożeniu i uruchomiła rollback.
8. **Hipoteza:** kontener został odtworzony, więc stara seria dla celu `:9199` nie dostała znacznika wygaśnięcia i przez ok. 5 minut miała wartość 0. Sprawdzenie: przeładowanie konfiguracji w działającym procesie (`--web.enable-lifecycle`, `curl -X POST localhost:9090/-/reload`) i powtórzenie testu A. Jeśli fałszywy alert zniknie, hipoteza jest potwierdzona.
9. Na `main` nie ma nowego commita w porównaniu z tym, co już obsłużono. Skrypt nic nie robi.

**Zadanie praktyczne:** wypchnij niegroźną zmianę (np. komentarz w `lab2/prometheus.yml`) i sprawdź w `~/deploy/deploy.log`, że cron wdrożył ją w ciągu 5 minut (`DEPLOY OK`).

---

## 12. Dział 10 – Terraform i AWS

### Co zrobiliśmy
Konto AWS (plan Free, MFA na koncie głównym, region eu-north-1), użytkownik IAM `terraform-radek` z kluczem dostępu, AWS CLI na `[sre-lab]`. Kod Terraform w `lab8/`. Odtworzyliśmy lab w chmurze: sieć VPC, dwie instancje EC2 z nginx, ALB, Ansible (ten sam `site.yml` co w labie), monitoring na trzeciej instancji, test awarii web1 i `terraform destroy`. Pełny postmortem: `lab8/postmortem-aws.md`.

### Mapa: lab domowy a AWS
| Lab domowy | AWS / Terraform |
|---|---|
| maszyna KVM (web1, web2) | instancja EC2 (`aws_instance`) |
| obraz bazowy (qcow2) | AMI (`data "aws_ami"`, Ubuntu 24.04) |
| cloud-init | `user_data` |
| sieć libvirt | VPC + podsieci + brama internetowa + tablica tras |
| `ufw` | Security Group |
| lb1 (nginx) | ALB (Application Load Balancer) |
| `lab_vm.pub` w maszynach | Key Pair (`aws_key_pair`) |
| `virsh` ręcznie | `terraform apply` i `terraform destroy` |

### Kluczowe informacje
- **Terraform** opisuje infrastrukturę kodem (IaC). Opisujesz stan docelowy, a Terraform sam wylicza kroki.
- **Cykl pracy:** `init` (pobranie providera) → `plan` (co się zmieni) → `apply` (wykonanie) → `destroy` (usunięcie wszystkiego).
- **Stan** (`terraform.tfstate`) to pamięć Terraforma o tym, co istnieje. Zawiera dane wrażliwe, więc **nie wchodzi do Gita** (`.gitignore`: `*.tfstate`, `*.tfstate.*`, `.terraform/`, `*.tfvars`). Plik `.terraform.lock.hcl` commitujemy.
- Terraform czyta **wszystkie pliki `.tf`** z bieżącego katalogu, więc kod można dzielić na `main.tf`, `ec2.tf`, `monitoring.tf`.
- Symbole w planie:

| Symbol | Znaczenie | Przykład |
|---|---|---|
| `+` | utworzenie | pierwszy `apply` z VPC |
| `~` | zmiana na miejscu (to samo `id`) | tag VPC, nowa reguła Security Group |
| `-/+` | zniszczenie i utworzenie od nowa (nowe `id`) | zmiana `cidr_block` (`# forces replacement`) |
| `-` | usunięcie | `terraform destroy` |

- `data` tylko **odczytuje** informacje z AWS (np. numer konta, najnowszy AMI). `resource` tworzy zasób.
- `variable` deklaruje wejście, wartość leży w `terraform.tfvars` (poza Gitem). `output` wypisuje wynik.
- `for_each` tworzy wiele podobnych zasobów z jednej definicji (`each.key`, `each.value`). Tak powstały web1 i web2.
- Odwołania (`aws_vpc.lab.id`) tworzą zależności, według których Terraform ustala kolejność tworzenia (i odwrotną przy usuwaniu).
- **Security Group** może wskazywać **inną** Security Group zamiast adresu IP (monitoring → port 9100 na webach).
- **ALB** potrzebuje podsieci w co najmniej dwóch strefach dostępności. **Health check** (3 × 30 s) decyduje o wyłączeniu i przywróceniu backendu. W czasie tej zwłoki ALB zwraca `502`.
- Adresy IP instancji zmieniają się po każdym `apply`, więc inwentarz Ansible generuje skrypt `gen-inventory.py` z `terraform output -json`.
- Ansible: `template` (szablony **Jinja2**, pętle `{% for %}`), `handlers` + `notify` (restart tylko po zmianie pliku), `changed_when` (kiedy uznać krok za zmianę).
- **Konto AWS Free:** po 6 miesiącach lub po zużyciu kredytów konto się zamyka. Zadanie „Explore AWS: Set up a cost budget" dało 20 USD kredytu.
- **Czas:** Prometheus UI, Ansible i systemd podają **UTC**. W Polsce zimą czas lokalny = UTC + 1 h.

### Wyniki z laba
| Co | Wynik |
|---|---|
| Cykl na VPC | `+` (create) → `~` (tag) → `-/+` (CIDR, nowe `id`) → `-` (destroy) |
| Sieć | `Plan: 8 to add` |
| EC2 + ALB | `Plan: 8 to add`; 20 zapytań do ALB: 10 × web1 i 10 × web2 |
| Monitoring | `Plan: 2 to add, 1 to change` (nowa maszyna + reguła 9100) |
| Ansible `site.yml` na EC2 | `changed=0` (nginx i strona już były z `user_data`) |
| Ansible `monitoring.yml` | pierwsze uruchomienie: `mon1` changed=8; drugie: **changed=0** |
| Test awarii web1 | nginx stop 11:20:06, `firing` 11:21:00 (54 s), ALB bez web1 ok. 11:22, nginx start 11:25:41, sonda OK 11:26:00 |
| `terraform destroy` | 18 zasobów, 11:36:15 – 11:37:27, konsola pusta |

### Na co uważać
- **Po sesji zawsze `terraform destroy`** i sprawdź konsolę AWS (instancje, load balancery, wolumeny, VPC). Nic nie zostaje na noc.
- Klucze dostępu AWS tylko w `~/.aws/credentials`. Nigdy w repozytorium ani w czacie.
- SSH w Security Group tylko z własnego adresu `/32`. Jeśli dostawca zmieni Ci adres IP, zmień `terraform.tfvars` i zrób `apply`.
- Czytaj plan przed `apply`. Szczególnie `-/+` i `-`.
- W HCL **każdy atrybut w osobnej linii**. Wklejony w jednej linii blok się nie wczyta.
- Jeden styl reguł Security Group naraz (w bloku albo jako osobne zasoby), bo mieszanie obu powoduje konflikty (ostrzega dokumentacja providera).
- `terraform` uruchamiasz w katalogu z plikami `.tf`, a `git add lab8` z katalogu głównego repozytorium.
- Nie nazywaj hosta tak samo jak grupy w inwentarzu Ansible.
- Godziny z testów bierz z metryk i logów (`query_range`), nie z pamięci. Zapisuj strefę czasową.
- ALB potrzebuje około 1,5 min na wyłączenie i przywrócenie backendu. Test mierz pętlą z `date`.
- Dane w Prometheusie na maszynie `mon` znikają razem z nią po `destroy`. Odczytaj godziny **przed** sprzątaniem.

### Polecenia
```bash
aws configure                         # klucz, region eu-north-1, format json
aws sts get-caller-identity           # kto jestem? (sprawdzenie klucza)

cd ~/sre-lab/lab8
terraform init
terraform fmt                         # formatowanie
terraform validate                    # składnia
terraform plan
terraform apply
terraform output
terraform output -raw alb_dns
terraform destroy

cd ~/sre-lab/lab8/ansible
python3 gen-inventory.py > inventory.ini
ansible all -m ping
ansible-playbook monitoring.yml
ansible web1 -b -m service -a "name=nginx state=stopped"

S=$(date -d '11:10' +%s); E=$(date +%s)
curl -s -G http://IP_MON:9090/api/v1/query_range \
  --data-urlencode 'query=probe_success{instance="http://10.0.1.44"}' \
  --data-urlencode "start=$S" --data-urlencode "end=$E" --data-urlencode "step=15"
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Co robią po kolei `terraform init`, `plan`, `apply` i `destroy`?
2. Co oznaczają symbole `+`, `~`, `-/+` i `-` w planie? Który wymaga największej ostrożności?
3. Dlaczego `terraform.tfstate` nie może trafić do publicznego repozytorium?
4. Czym różni się blok `data` od bloku `resource`?
5. Po co jest `variable "my_ip"` i dlaczego jej wartość leży w `terraform.tfvars`?
6. Co daje `for_each` i jak w kodzie dostać się do nazwy (web1 / web2)?
7. Dlaczego ALB zwracał `502` po zatrzymaniu nginx na web1 i ile mniej więcej to trwa?
8. Dlaczego reguła dla portu 9100 wskazuje Security Group `mon`, a nie adres IP?
9. Dlaczego inwentarz Ansible generujemy skryptem z outputów Terraforma?
10. Dlaczego drugie uruchomienie `monitoring.yml` dało `changed=0` i kiedy uruchomiłby się handler?
11. W Prometheusie widzisz zdarzenie o 10:20:22. Która to godzina lokalnie i skąd wiesz?
12. Policz z danych z testu: czas wykrycia (od zatrzymania nginx do `firing`) i czas od startu nginx do udanej sondy.

**Odpowiedzi**

1. `init` pobiera providera i przygotowuje katalog. `plan` pokazuje, co się zmieni, bez zmian. `apply` wykonuje zmiany po potwierdzeniu. `destroy` usuwa wszystko, co Terraform utworzył.
2. `+` utworzenie, `~` zmiana na miejscu, `-/+` zniszczenie i utworzenie od nowa, `-` usunięcie. Najostrożniej z `-/+` i `-`: przy prawdziwych maszynach grożą przerwą i utratą danych.
3. Zawiera dane o zasobach i potencjalnie wrażliwe wartości. Repozytorium jest publiczne.
4. `data` tylko odczytuje istniejące informacje, a `resource` tworzy i zarządza zasobem.
5. Zmienna deklaruje, że projekt potrzebuje wartości (adres IP). Wartość w `terraform.tfvars` zostaje poza Gitem, więc nie trafia do publicznego kodu.
6. Jedna definicja tworzy wiele zasobów. W bloku używa się `each.key` (nazwa) i `each.value` (np. podsieć).
7. ALB jeszcze kierował ruch do web1, bo health check musi 3 razy z rzędu (co 30 s) zakończyć się niepowodzeniem. To około 90 s. W tym czasie żądania do web1 kończą się `502`.
8. Adres IP instancji zmienia się po każdym `apply`. Reguła „wpuść wszystkich z grupy `mon`" działa zawsze.
9. Adresy IP zmieniają się po każdym `apply`, więc ręczne wpisywanie jest błędogenne.
10. Wszystkie zadania były już w stanie docelowym: pakiety zainstalowane, pliki identyczne, kontenery działają. Handler uruchamia się tylko wtedy, gdy zadanie z `notify` zgłosi zmianę (np. zmieni się `prometheus.yml`).
11. 11:20:22. Prometheus UI i logi Ansible/systemd podają UTC, a w Polsce zimą jest UTC + 1 h. Potwierdzenie: log systemd pokazał zatrzymanie nginx o 10:20:06 UTC, a Ty zrobiłeś to o 11:20 lokalnie.
12. Wykrycie: 11:20:06 → 11:21:00 = 54 s. Powrót sondy: 11:25:41 → 11:26:00 = około 19 s.

**Zadanie praktyczne:** dodaj trzeci backend `web3` do `local.web_servers` w `ec2.tf` (podsieć `public_a`). Uruchom `terraform plan` i przewidź, ile zasobów dojdzie (podpowiedź: instancja i jej przypisanie do grupy docelowej). Potem `apply`, odśwież inwentarz (`gen-inventory.py`), uruchom `site.yml`, sprawdź pętlą `curl`, że odpowiadają trzy backendy, i zrób `terraform destroy`.

---

## 13. Dział 11 – VPS, tunel WireGuard i monitoring z zewnątrz

### Co zrobiliśmy
Kupiliśmy tani VPS w OVHcloud (Limburg, Ubuntu 26.04, 2 vCore, 4 GB RAM, ok. 20 zł/mies.). Zabezpieczyliśmy go (SSH tylko kluczem, `ufw`, `fail2ban`, automatyczne aktualizacje, swap 2 GB). Zbudowaliśmy tunel WireGuard VPS ↔ sre-lab. Przenieśliśmy na VPS codzienną kontrolę kosztów AWS (skrypt `aws-cost.sh` + Telegram), bo sre-lab jest na noc wyłączany. Postawiliśmy na VPS drugi monitoring (Prometheus, blackbox_exporter, Alertmanager), który z zewnątrz sprawdza sre-lab i wysyła alerty na Telegram osobnym botem. Zrobiliśmy test awarii B (zatrzymanie Prometheusa na sre-lab). Pełny postmortem: `lab9/postmortem-vps-monitoring.md`.

### Mapa: kto kogo pilnuje
| Element | Rola |
|---|---|
| sre-lab (10.8.0.2) | lab: Prometheus, Grafana, Docker; wyłączany na noc |
| VPS (10.8.0.1) | działa 24/7: monitoring z zewnątrz, kontrola kosztów AWS |
| Tunel WireGuard `wg0` | prywatna sieć 10.8.0.0/24, UDP 51820 |
| Mac | tylko klient SSH; nie jest w tunelu, więc nie widzi 10.8.0.2 |

Zasada: **monitoring nie może leżeć na tej samej maszynie, którą pilnuje.** Jak padnie sre-lab, jego własny Prometheus nic nie powie.

### Kluczowe informacje
- **WireGuard**: każda strona ma parę kluczy. Klucz **publiczny** wymieniasz, **prywatny** nigdy nie opuszcza maszyny. `AllowedIPs` mówi, jaki ruch idzie przez tunel. `PersistentKeepalive = 25` podtrzymuje tunel za NAT. Start: `wg-quick@wg0` (systemd).
- **Zapora**: `ufw` z regułą per interfejs (`allow in on wg0 from 10.8.0.1 to any port 9090`). Najpierw `allow`, potem `enable` (inaczej odetniesz sobie SSH).
- **SSH hardening**: logowanie tylko kluczem (`PasswordAuthentication no`, `PermitRootLogin no`). Pliki w `sshd_config.d/` są czytane w kolejności, **wygrywa pierwsza wartość**, dlatego plik nazywa się `00-hardening.conf`. Alias w `~/.ssh/config` (`ssh ovh`), `ssh-agent` i `ssh-add` zamiast wpisywania hasła klucza.
- **Docker i `ufw`**: porty publikowane przez Dockera potrafią omijać `ufw`. Dlatego `network_mode: host` i nasłuch tylko na `127.0.0.1`.
- **Prometheus**: `scrape_interval` (jak często zbiera), `evaluation_interval` (jak często liczy reguły; domyślnie 1 min), `for` (jak długo warunek musi trwać: *pending* → *firing*). Przeładowanie konfiguracji bez restartu: `--web.enable-lifecycle` i `POST /-/reload`.
- **`hour()` w PromQL zwraca UTC**. Reguła `hour() >= 8 and hour() < 22` oznacza 9:00–23:00 czasu lokalnego zimą. Cron na VPS też liczy w UTC (7:00 UTC = 8:00 CET).
- **blackbox_exporter**: sonda HTTP z `relabel_configs` (adres celu trafia do parametru `target`). Metryka `probe_success` (1 = OK).
- **Alertmanager**: `group_wait` 30 s (czekanie na kolejne alerty z grupy), `group_interval` 5 min (domyślnie; odstęp między wiadomościami o zmianie w grupie), `repeat_interval` 4 h, `resolve_timeout` 5 min. Token bota w pliku (`bot_token_file`), nie w konfiguracji.
- **Sekrety**: katalog `~/.secrets/` (700), pliki 600. Wysyłanie przez `curl -K -`, żeby token nie wisiał na liście procesów. `alertmanager.yml` zawiera `chat_id`, więc nie trafia do publicznego repozytorium (`.gitignore`).
- **Cost Explorer API**: `aws ce get-cost-and-usage`, ok. 0,01 USD za zapytanie. `End` jest wyłączny, dane spływają z opóźnieniem ok. doby, wynik brutto (przed kredytami). Przez API nie sprawdzisz salda kredytów. Dla skryptu: osobny użytkownik IAM `cost-reader` z minimalnymi uprawnieniami (least privilege).
- **Dead man's switch** (do zrobienia): alert, który ma przychodzić zawsze. Brak wiadomości oznacza, że padł sam monitoring.

### Wyniki z laba
| Co | Wynik |
|---|---|
| Ping przez tunel | 22,3–24,3 ms (3 pakiety) |
| Baseline sond (czas) | sre-lab 48 ms, github.com 20 ms |
| Test sztucznego alertu | Telegram o 10:50 lokalnie; *Resolved* po ok. 5 min (domyślny `group_interval`) |
| Test awarii B: zatrzymanie Prometheusa | 11:00:38 (`date -Is`) |
| Reguła *firing* | po ok. 5 min 54–57 s |
| Wiadomość *Firing* na Telegramie | po 6 min 22 s – 7 min 21 s (godzina 11:07, do minuty) |
| Start usługi | 11:07:14; reguła *inactive* najwyżej 22 s później |
| Wiadomość *Resolved* | 11:12 (4 min 46 s – 5 min 45 s po starcie) |
| Prognoza vs wynik | prognoza 5,5–6 min, wynik 6,4–7,3 min |
| Koszt AWS 29.10 (Cost Explorer API) | 0,1754 USD (brutto), konsola 0,13 → 0,18 USD |
| Quiz po dziale 10 | 8/10 |

Wyjaśnienie rozbieżności prognozy to **hipoteza**: nieustawiony `evaluation_interval` (domyślnie 1 min). Do sprawdzenia przez ustawienie 15 s i powtórzenie testu.

### Na co uważać
- **Najpierw `ufw allow` dla SSH, dopiero potem `ufw enable`.** Zmianę SSH testuj w drugim oknie, zanim zamkniesz pierwsze.
- Klucza prywatnego WireGuarda i SSH nie wklejasz nigdzie. W czacie i repozytorium tylko klucze publiczne.
- Nie wystawiaj portów Prometheusa i Alertmanagera na świat: nasłuch `127.0.0.1` lub tylko interfejs `wg0`.
- Port klastra Alertmanagera (9094) jest domyślnie otwarty na `*`. Wyłączasz go przez `--cluster.listen-address=`.
- Czas: VPS i `hour()` to UTC, sre-lab i Telegram pokazują czas lokalny. Zapisuj strefę.
- `docker compose down -v` kasuje wolumeny (dane).
- Każdy nowy commit na `main` uruchamia w ciągu 5 minut wdrożenie na sre-lab (`pull-deploy.sh`). Nie commituj przypadkiem niedokończonych zmian (`git add` tylko wskazanych plików, nie `git add .`).
- Skanuj i atakuj wyłącznie własny VPS i przeczytaj regulamin dostawcy.
- Prognozę zapisuj **przed** testem. Rozbieżność z wynikiem to najcenniejsza część testu.

### Polecenia
```bash
# [VPS] WireGuard
sudo wg show
sudo systemctl enable --now wg-quick@wg0
ping -c 3 10.8.0.2

# [VPS] zapora i logowania
sudo ufw status verbose
sudo fail2ban-client status sshd
sudo journalctl -u ssh --since "1 hour ago" | grep -i "invalid user"

# [VPS] monitoring
cd ~/monitoring && docker compose ps
docker run --rm --entrypoint promtool -v "$PWD/prometheus.yml:/etc/prometheus/prometheus.yml:ro" -v "$PWD/alerts.yml:/etc/prometheus/alerts.yml:ro" prom/prometheus check config /etc/prometheus/prometheus.yml
curl -s -X POST http://127.0.0.1:9090/-/reload
curl -s http://127.0.0.1:9090/api/v1/rules
ss -tlnp | grep -c 9094

# [sre-lab] test awarii B (zawsze z zapisem godzin)
date -Is | tee ~/testB-stop.txt && docker stop lab2-prometheus-1
date -Is | tee ~/testB-start.txt && docker start lab2-prometheus-1

# [VPS] koszty AWS
~/bin/aws-cost.sh
aws ce get-cost-and-usage --time-period Start=2026-10-29,End=2026-10-30 --granularity DAILY --metrics UnblendedCost
```

### Ćwiczenia (sprawdź siebie)

**Pytania**

1. Dlaczego monitoring sre-lab postawiliśmy na VPS, a nie na sre-lab?
2. Który klucz WireGuarda wolno wkleić do czatu i dlaczego?
3. Co robi `AllowedIPs` i co `PersistentKeepalive`?
4. Dlaczego plik w `sshd_config.d/` nazywa się `00-hardening.conf`?
5. Dlaczego przy `ufw` najpierw robimy `allow` dla SSH, a dopiero potem `enable`?
6. Dlaczego w Docker Compose używamy `network_mode: host` i nasłuchu na `127.0.0.1`?
7. Czym różnią się `scrape_interval`, `evaluation_interval` i `for`?
8. Reguła ma `hour() >= 8 and hour() < 22`. Od której do której godziny czasu lokalnego (zima) działa?
9. Co robią `group_wait`, `group_interval` i `repeat_interval`?
10. Dlaczego token Telegrama trzymamy w pliku z uprawnieniami 600, a skrypt wysyła go przez `curl -K -`?
11. Dlaczego `alertmanager.yml` nie może trafić do publicznego repozytorium?
12. Policz z testu B: czas od zatrzymania do *firing* w Prometheusie i do wiadomości na Telegramie. Co mówi różnica?
13. Dlaczego koszty z Cost Explorera za dzień „dzisiejszy" są zaniżone?

**Odpowiedzi**

1. Gdy sre-lab jest wyłączony lub padnie, jego własny Prometheus nie wyśle żadnego alertu. Monitor musi działać poza obserwowaną maszyną, tu na VPS działającym 24/7.
2. Tylko publiczny. Prywatny daje dostęp do tunelu i nie opuszcza swojej maszyny.
3. `AllowedIPs` określa, jakie adresy idą przez tunel do danego peera (i skąd przyjmujemy ruch). `PersistentKeepalive` wysyła co 25 s mały pakiet, żeby tunel za NAT nie wygasł.
4. SSH czyta pliki w kolejności alfabetycznej i wygrywa pierwsza ustawiona wartość. `00-` ustawia nasze reguły przed domyślnymi plikami dostawcy.
5. Włączenie zapory bez reguły dla SSH odcina Cię od serwera. Najpierw wpuszczasz SSH, potem włączasz.
6. Porty publikowane przez Dockera mogą omijać `ufw`. Nasłuch na `127.0.0.1` sprawia, że usługa nie jest widoczna z internetu.
7. `scrape_interval`: jak często Prometheus zbiera metryki. `evaluation_interval`: jak często liczy reguły alertów. `for`: jak długo warunek musi być spełniony, zanim alert przejdzie z *pending* do *firing*.
8. 8:00–22:00 UTC to 9:00–23:00 czasu lokalnego zimą (UTC+1), a latem 10:00–24:00 (UTC+2).
9. `group_wait`: ile czekać na pierwsze powiadomienie, żeby zebrać alerty z grupy. `group_interval`: minimalny odstęp między kolejnymi powiadomieniami o zmianach w grupie. `repeat_interval`: jak często powtarzać wiadomość o wciąż aktywnym alercie.
10. Plik 600 czyta tylko właściciel. `curl -K -` czyta konfigurację ze standardowego wejścia, więc token nie pojawia się w argumentach i na liście procesów (`ps`).
11. Zawiera `chat_id` (identyfikator czatu), a repozytorium jest publiczne. Plik trafia do `.gitignore`, a w repozytorium może leżeć wersja bez wartości.
12. *Firing*: ok. 5 min 54–57 s. Telegram: 6 min 22 s – 7 min 21 s. Różnica (ok. 25–84 s) to głównie `group_wait` 30 s plus niedokładność godziny podanej do minuty.
13. Dane spływają z opóźnieniem ok. doby, a bieżący dzień jest niepełny. Zakres `End` jest wyłączny, więc dla jednego dnia podajesz kolejny dzień.

**Zadanie praktyczne:** na VPS ustaw w `prometheus.yml` `evaluation_interval: 15s`, sprawdź `promtool check config`, przeładuj przez `/-/reload`. Zapisz prognozę czasu powiadomienia, powtórz test B z zapisem godzin i porównaj z wynikiem 6,4–7,3 min. Wynik dopisz do postmortemu.

---

## 14. Słowniczek

### Podstawy SRE
- **SRE** (Site Reliability Engineering): podejście do utrzymania niezawodności usług przez inżynierię (automatyzacja, pomiary, cele).
- **DevOps**: kultura i praktyki łączące tworzenie i utrzymanie oprogramowania.
- **SLI / SLO / SLA**: wskaźnik, cel, umowa. Patrz dział SLO.
- **Error budget**: dopuszczalny poziom błędów w oknie czasu. Gdy budżet się kończy, zwalniasz zmiany i naprawiasz niezawodność.
- **Toil**: powtarzalna, ręczna praca bez trwałej wartości. Cel SRE: eliminować przez automatyzację.
- **Observability**: zdolność rozumienia stanu systemu z metryk, logów i śladów.
- **Incident**: zdarzenie pogarszające usługę. **Postmortem**: dokument po incydencie (przebieg, przyczyny, wnioski, działania). **Blameless**: bez szukania winnych.
- **MTTD / MTTR**: średni czas wykrycia / naprawy.
- **Runbook**: instrukcja postępowania przy konkretnym alercie.
- **SPOF**: pojedynczy punkt awarii.
- **Rollback**: powrót do poprzedniej, działającej wersji.
- **Failure injection / chaos**: celowe psucie systemu w kontrolowany sposób.

### Monitoring
- **Metric**: liczba zmieniająca się w czasie. **Label**: etykieta (np. `instance`, `job`).
- **Target**: adres, który Prometheus odpytuje. **Scrape**: jedno odpytanie.
- **Exporter**: program udostępniający metryki.
- **Probe**: aktywne sprawdzenie usługi z zewnątrz.
- **Alerting rule / recording rule**: reguła alertu / reguła zapisująca wynik zapytania jako nową metrykę.
- **pending / firing / resolved**: stany alertu.
- **Severity**: waga alertu (`warning`, `critical`).
- **Staleness**: Prometheus uznaje serię za wygasłą po ok. 5 minutach bez próbek (lub po znaczniku wygaśnięcia).
- **Percentyl (p95)**: wartość, poniżej której mieści się 95% próbek.
- **Latency / traffic / errors / saturation**: cztery złote sygnały.
- **VU** (virtual user): wirtualny użytkownik w teście k6.

### Infrastruktura i sieć
- **Hypervisor**: oprogramowanie uruchamiające maszyny wirtualne (KVM).
- **VM / kontener**: maszyna wirtualna ma własny system, kontener dzieli jądro hosta.
- **qcow2**: format dysku maszyny wirtualnej. **Backing file**: obraz bazowy, na którym oparty jest dysk.
- **cloud-init**: konfiguracja maszyny przy pierwszym starcie.
- **DHCP**: automatyczne przydzielanie adresów IP. **Rezerwacja**: stały adres po MAC.
- **NAT**: tłumaczenie adresów (maszyny w sieci prywatnej wychodzą do internetu).
- **CIDR** (np. `192.168.100.0/24`): zapis zakresu adresów. `/24` = 256 adresów.
- **DNS**: zamiana nazw na adresy IP.
- **Reverse proxy / load balancer**: pośrednik rozdzielający ruch na backendy.
- **Upstream / backend**: serwer, do którego przekazywane są żądania.
- **Firewall (ufw)**: reguły dozwolonego ruchu.

### Narzędzia i procesy
- **IaC** (Infrastructure as Code): infrastruktura opisana kodem.
- **Idempotency**: wielokrotne wykonanie daje ten sam wynik.
- **Inventory / playbook / task / module / handler**: pojęcia Ansible.
- **CI / CD**: automatyczne sprawdzanie / automatyczne wdrażanie zmian.
- **Pipeline**: ciąg kroków automatyzacji. **Runner**: maszyna wykonująca kroki.
- **Lint**: automatyczna kontrola stylu i składni.
- **Pull vs push (wdrażanie)**: serwer sam pobiera zmiany (pull) vs system zewnętrzny wypycha je na serwer (push).
- **Secret**: hasło, token lub klucz. **Rotate / revoke**: wymiana / unieważnienie.
- **Cron**: planista zadań systemowych.
- **Heredoc**: wieloliniowy tekst w powłoce (`<< 'EOF'`).
- **UTC**: czas uniwersalny. Polska to UTC+1 (zima) i UTC+2 (lato).

### Terraform i AWS
- **Terraform**: narzędzie IaC, które tworzy i zmienia infrastrukturę według kodu.
- **Provider**: wtyczka Terraforma do konkretnej platformy (tu AWS).
- **Resource / data source**: zasób tworzony przez Terraform / informacja tylko odczytywana.
- **State** (`terraform.tfstate`): zapis tego, co Terraform utworzył. Nie commitujemy go.
- **plan / apply / destroy**: podgląd zmian / wykonanie / usunięcie wszystkiego.
- **Variable / output**: wejście do kodu / wynik wypisywany na końcu.
- **`for_each`**: tworzenie wielu podobnych zasobów z jednej definicji.
- **HCL**: język, w którym pisze się pliki `.tf`.
- **Region / Availability Zone (AZ)**: obszar geograficzny AWS / osobne centrum danych w regionie.
- **VPC**: prywatna sieć w AWS. **Subnet**: podsieć w jednej strefie. **Internet Gateway**: wyjście do internetu. **Route table**: tablica tras.
- **Security Group**: wirtualny firewall instancji (reguły wejścia i wyjścia).
- **EC2**: wirtualne maszyny w AWS. **AMI**: obraz systemu. **Instance type** (np. `t3.micro`): rozmiar maszyny.
- **`user_data`**: skrypt uruchamiany raz przy pierwszym starcie instancji (jak cloud-init).
- **ALB** (Application Load Balancer): load balancer warstwy HTTP. **Target group**: grupa backendów. **Listener**: port, na którym ALB nasłuchuje. **Health check**: sprawdzanie, czy backend żyje.
- **IAM user / access key**: użytkownik w AWS / jego klucz do CLI. **Least privilege**: tylko minimalne potrzebne uprawnienia.
- **Credits**: kredyty AWS na koncie. **Budget**: limit kosztów z alertem.
- **Jinja2 / template**: język szablonów w Ansible (`{{ zmienna }}`, `{% for %}`).
- **Handler / notify**: krok uruchamiany tylko po zmianie, którą zgłosiło inne zadanie.

### VPS, tunel i monitoring z zewnątrz
- **VPS**: wynajęty wirtualny serwer w centrum danych, działa całą dobę.
- **WireGuard**: szybki VPN. **Peer**: druga strona tunelu. **Klucz publiczny / prywatny**: publiczny wymieniasz, prywatny zostaje na maszynie.
- **`AllowedIPs`**: adresy kierowane przez tunel do peera. **`PersistentKeepalive`**: cykliczny pakiet podtrzymujący tunel za NAT.
- **Hardening**: utwardzanie systemu (SSH tylko kluczem, zapora, aktualizacje).
- **fail2ban**: blokuje adresy po serii nieudanych logowań. **unattended-upgrades**: automatyczne aktualizacje bezpieczeństwa.
- **ssh-agent / `ssh-add`**: przechowuje odblokowany klucz, żeby nie wpisywać hasła klucza za każdym razem.
- **Dead man's switch**: alert, który ma przychodzić stale. Cisza oznacza awarię monitoringu.
- **Blast radius**: zasięg skutków awarii lub błędu. **Least privilege**: minimalne uprawnienia.
- **`evaluation_interval`**: jak często Prometheus liczy reguły. **`group_wait` / `group_interval` / `repeat_interval`**: czasy grupowania i powtarzania powiadomień w Alertmanagerze.
- **Cost Explorer**: usługa AWS z kosztami (API: `aws ce get-cost-and-usage`).
- **RPO / RTO**: ile danych możesz stracić / jak szybko musisz wrócić do działania. **Reguła 3-2-1**: 3 kopie, 2 nośniki, 1 poza miejscem.

---

## 15. Ściąga składni

### YAML
```yaml
# komentarz
klucz: wartość            # para klucz-wartość
lista:
  - pierwszy              # elementy listy zaczynają się od "- "
  - drugi
mapa:
  podklucz: 1             # wcięcie = zagnieżdżenie (SPACJE, nigdy tabulatory)
tekst: |                  # blok wieloliniowy zachowujący nowe linie
  linia 1
  linia 2
```
Zasady: te same wcięcia w całym pliku (dwie spacje), pusta linia na końcu pliku, wartości z dwukropkiem lub `{{ }}` w cudzysłowie.

### Bash
```bash
cd ~/sre-lab            # zmiana katalogu
ls -la                  # lista plików, także ukrytych
cat plik | head -5      # początek pliku
tail -20 plik           # koniec pliku
grep -n "tekst" plik    # szukanie tekstu z numerem linii
sed -i 's/stare/nowe/' plik   # zamiana tekstu w pliku
mkdir -p a/b            # tworzenie katalogów (także zagnieżdżonych)
touch plik              # pusty plik
chmod 600 plik          # prawa: tylko właściciel czyta/zapisuje
chmod +x skrypt.sh      # plik wykonywalny
sudo komenda            # jako root
for i in 1 2 3; do echo $i; done
komenda1 && komenda2    # druga tylko po sukcesie pierwszej
komenda; echo "exit: $?"   # kod wyjścia (0 = sukces)
```
Kontrola: **Ctrl+C** przerywa, **Ctrl+R** szuka w historii, strzałka w górę to poprzednie polecenie.

### Git
```bash
git status                       # co się zmieniło (czytaj ZAWSZE przed commitem)
git add plik                     # do poczekalni (staged)
git add -u                       # tylko zmiany w już śledzonych plikach
git restore --staged plik        # wyjmij z poczekalni (plik zostaje)
git checkout -- plik             # cofnij zmiany w pliku (nieodwracalne!)
git commit -m "opis"
git commit -am "opis"            # UWAGA: zabiera wszystkie zmienione pliki śledzone
git push / git pull
git log --oneline -6
git revert --no-edit HEAD        # nowy commit cofający poprzedni
git checkout -b nazwa            # nowa gałąź
git branch -D nazwa              # usuń gałąź lokalnie
git push origin --delete nazwa   # usuń gałąź na GitHubie
git check-ignore -v plik         # sprawdź, czy .gitignore chroni plik
git reflog --date=iso            # historia ruchów (z godzinami)
```

### Docker i docker compose
```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker logs NAZWA --tail 20
docker compose up -d
docker compose -p lab2 up -d --force-recreate prometheus
docker compose down              # BEZ -v: dane zostają
docker compose restart prometheus
docker compose logs prometheus --tail 20
docker compose config -q         # sprawdzenie składni pliku compose
```

### Ansible
```bash
ansible all -m ping
ansible grupa -b -m modul -a "argumenty"
ansible-playbook plik.yml --check
ansible-playbook plik.yml --limit lb1
ansible-playbook plik.yml --syntax-check
```

### SSH
```bash
ssh sre-lab
ssh-keygen -t ed25519 -f ~/.ssh/nazwa
ssh-copy-id -i ~/.ssh/nazwa.pub uzytkownik@adres
```

### Prometheus – narzędzia i PromQL
```bash
docker run --rm --entrypoint promtool -v ... prom/prometheus check config /etc/prometheus/prometheus.yml
```
```
up == 0                                   # cele niedostępne
probe_success{job="blackbox-lb"}          # filtr po etykiecie
avg_over_time(metryka[6h])                # średnia z 6 godzin
sum_over_time((1 - metryka)[20m:15s])     # podzapytanie: okno 20 min, krok 15 s
rate(metryka[5m])                         # tempo wzrostu licznika na sekundę
```

### nginx (load balancer)
```nginx
upstream web_backend {
    server 192.168.122.14 max_fails=1 fail_timeout=10s;
    server 192.168.122.175 max_fails=1 fail_timeout=10s;
}
server {
    listen 80;
    location / {
        proxy_pass http://web_backend;
        proxy_next_upstream error timeout http_502 http_503 http_504;
    }
}
```

### cron
```
*/5 * * * * flock -n /tmp/pull-deploy.lock $HOME/deploy/pull-deploy.sh >> $HOME/deploy/deploy.log 2>&1
```
Pola: minuta, godzina, dzień miesiąca, miesiąc, dzień tygodnia. `*/5` = co 5.

### virsh
```bash
virsh list --all | start NAZWA | shutdown NAZWA | autostart NAZWA
virsh net-list --all | net-dhcp-leases default
```

### Terraform (HCL)
```hcl
provider "aws" {
  region = "eu-north-1"
}

variable "my_ip" {
  type = string
}

resource "aws_vpc" "lab" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "sre-lab"
  }
}

output "vpc_id" {
  value = aws_vpc.lab.id
}
```
Każdy atrybut w osobnej linii. Odwołanie do innego zasobu: `typ.nazwa.atrybut`. Wartość zmiennej: `var.nazwa`. Pętla: `for_each = mapa` i `each.key` / `each.value`.
```bash
terraform init | fmt | validate | plan | apply | destroy | output
```

### AWS CLI
```bash
aws configure
aws sts get-caller-identity
```

### WireGuard i zapora (VPS)
```bash
wg genkey | tee priv | wg pubkey > pub     # para kluczy (priv zostaje na maszynie)
sudo wg show                               # stan tunelu, ostatni handshake
sudo systemctl enable --now wg-quick@wg0
sudo ufw allow OpenSSH && sudo ufw enable  # najpierw allow, potem enable
sudo ufw allow in on wg0 from 10.8.0.1 to any port 9090
```

### Prometheus i Alertmanager (reload, kontrola)
```bash
promtool check config prometheus.yml
curl -s -X POST http://127.0.0.1:9090/-/reload      # wymaga --web.enable-lifecycle
curl -s http://127.0.0.1:9090/api/v1/rules
amtool check-config alertmanager.yml
```

### AWS Cost Explorer
```bash
aws ce get-cost-and-usage --time-period Start=2026-10-29,End=2026-10-30 \
  --granularity DAILY --metrics UnblendedCost   # End jest wyłączny
```

---

## 16. Lista kontrolna "przed commitem" i "po zmianie konfiguracji"

Przed commitem:
1. `git status` – czy na liście nie ma sekretów (`secrets/`, tokeny, klucze)?
2. Czy pliki YAML mają pustą linię na końcu i poprawne wcięcia (`yamllint -f parsable .`)?
3. Czy wiem, co zmieniłem (`git diff --stat`)?
4. Czy jestem na właściwej gałęzi (`git branch --show-current`)?

Po zmianie konfiguracji usługi:
1. Czy usługa wczytała zmianę (restart lub reload)?
2. Czy wszystkie cele są `up`?
3. Czy w logach nie ma błędów?
4. Czy alert, który powinien działać, nadal działa?

Podczas testu awarii:
1. Zapisz `date` przed i po. 2. Zapisz godzinę alertu na Telegramie.
3. Po teście sprawdź, że stan jest przywrócony. 4. Spisz wnioski w postmortemie.
5. Najlepiej uruchom pętlę, która sama zapisuje godziny i kody odpowiedzi (`date -Is`, `curl -w`, `tee`).
6. Pamiętaj o strefie czasowej (Prometheus i Ansible podają UTC).

Przed zmianą SSH lub zapory na serwerze zdalnym:
1. Drugie okno SSH zostaje otwarte. 2. Najpierw `ufw allow`, potem `enable`.
3. Nowy plik `sshd_config.d/00-...`, `sudo sshd -t`, dopiero reload. 4. Test logowania w nowym oknie.

Przed `terraform apply`:
1. Jesteś w katalogu z plikami `.tf` (`pwd`, `ls`). 2. `fmt` i `validate` przeszły.
3. Przeczytałeś plan (liczba zasobów, symbole `-/+` i `-`). 4. Zapisałeś godzinę.

Po sesji w chmurze:
1. `terraform destroy`. 2. Konsola AWS: instancje, load balancery, wolumeny, VPC.
3. Koszty i kredyty następnego dnia (dane mają opóźnienie). 4. `git status` przed commitem (stan i `tfvars` poza Gitem).

---

## 17. Typowe błędy z tego laba (tabela diagnostyczna)

| Objaw | Najczęstsza przyczyna | Co zrobić |
|---|---|---|
| `quote>` w terminalu | niedomknięty cudzysłów | Ctrl+C, wpisz polecenie bez apostrofów |
| `>` na początku linii po wklejeniu | niezamknięty heredoc | Ctrl+C, twórz plik w edytorze lub `printf` |
| `-: command not found` po wklejeniu | tekst YAML wklejony do terminala | nic się nie wykonało, YAML wkleja się do edytora |
| `Permission denied (publickey)` w Ansible | uruchomienie z innego katalogu niż `lab1` | `cd ~/sre-lab/lab1` |
| `No route to host` do maszyn | maszyny wyłączone po restarcie hosta | `virsh start`, `virsh autostart` |
| `Unable to locate package terraform` | brak pliku repozytorium HashiCorp dla nowego wydania Ubuntu | repozytorium `noble` |
| `activeAlertmanagers: []` | Prometheus nie wczytał nowej konfiguracji | restart Prometheusa |
| pod `ImagePullBackOff`, `server misbehaving` | DNS w sieci kind | DNS w `daemon.json` Dockera |
| `new-line-at-end-of-file` w CI | brak pustej linii na końcu pliku | ustawienie VS Code, pętla `echo >>` |
| token w `git status` | brak wpisu w `.gitignore` | `git restore --staged`, wpis w `.gitignore` |
| fałszywy `InstanceDown` po rollbacku | hipoteza: odtworzenie kontenera i okno staleness | reload zamiast recreate (do sprawdzenia) |
| nowy plik w złym folderze w VS Code | zaznaczony inny folder | `touch` w terminalu, potem edycja |
| `Error: No configuration files` | `terraform` uruchomiony w katalogu bez `.tf` | `cd ~/sre-lab/lab8` |
| `fatal: pathspec 'lab8' did not match any files` | `git add lab8` z podkatalogu | `cd ~/sre-lab` |
| `Error: Argument or block definition required` | rozbita linia lub brak `=` w pliku `.tf` | `sed -n 'N,Mp' main.tf`, popraw linię |
| `Could not resolve hostname adres_ip_web1` | w poleceniu został tekst przykładowy | wstaw prawdziwy adres |
| `Found both group and host with same name` | host i grupa o tej samej nazwie w inwentarzu | zmień nazwę hosta (`mon1`) |
| ALB zwraca `502` po awarii backendu | health check jeszcze go nie wyłączył (3 × 30 s) | poczekaj ok. 90 s, mierz pętlą z `date` |
| `ssh` pyta o hasło mimo klucza | zły klucz, brak `ssh-add` lub zła kolejność plików w `sshd_config.d/` | `ssh -v`, `ssh-add`, plik `00-` |
| Alertmanager nasłuchuje na 9094 na `*` | domyślny port klastra | `--cluster.listen-address=` |
| `does not point to an existing file` w promtool | pliki nie zamontowane w kontenerze testowym | zamontuj `prometheus.yml` i `alerts.yml` w `/etc/prometheus/` |
| `getUpdates` zwraca `[]` | bot nie dostał żadnej wiadomości | wyślij `/start` do bota i powtórz |
| Telegram dostaje alert później niż prognoza | `for` + `evaluation_interval` + `group_wait` się sumują | zmierz, zapisz hipotezę, ustaw krótszy `evaluation_interval` |
| Resolved przychodzi po ok. 5 min | domyślny `group_interval` | świadomie ustaw lub zaakceptuj |
| Mac nie widzi 10.8.0.2 | w tunelu są tylko VPS i sre-lab | wejdź przez `ssh ovh` lub dodaj Maca jako peera |
| godzina w Prometheusie o 1 h inna niż lokalna | UTC zamiast czasu lokalnego | dodaj 1 h (zima) lub 2 h (lato) |

---

## 18. Status planu nauki i co dalej

| Etap planu | Status |
|---|---|
| Python, Bash, Git, sieci (etap 1) | Bash i Git używane praktycznie. Python i sieci jeszcze do zrobienia |
| Docker, Terraform, AWS (etap 2) | Docker zrobiony. Terraform i AWS zrobione w podstawach (VPC, EC2, ALB, destroy). Do zrobienia: zdalny stan (S3), moduły, IAM z minimalnymi uprawnieniami |
| CI/CD i obserwowalność (etap 3) | zrobione w wersji lokalnej (Prometheus, Grafana, Alertmanager, CI, CD) |
| Kubernetes (etap 4) | tylko test w kind. Do zrobienia |
| Praktyki SRE, portfolio (etap 5) | postmortemy po każdym dziale, SLO, monitoring z zewnątrz na VPS. Do rozbudowy |

Najbliższe kroki:
0. Test A (rollback), dead man's switch, test przy padniętym tunelu, test w nocy, powtórka testu B z `evaluation_interval: 15s`.
1. Sprawdzić koszty i kredyty AWS (dane z opóźnieniem). Powtórzyć test awarii z pomiarem godzin, Alertmanagerem w AWS i zawężonymi uprawnieniami IAM.
2. Dopisanie do README po angielsku opisu całego laboratorium.
3. Naprawa fałszywych alertów (reload zamiast recreate) i sprawdzenie hipotez.
4. Certyfikat AWS Solutions Architect Associate.
5. Kubernetes: aplikacja demo, monitoring, certyfikat CKA.
6. Na końcu nauki: przegląd braków (np. Python i podstawy sieci) i wersja PDF notatnika.
7. Sondy AWS z VPS (Security Group tylko z /32 VPS), restic do S3, zdalny stan Terraform, playbook hardeningu w `lab9/`, test odtwarzania kopii VPS.

---

## 19. Historia zmian notatnika

- Wersja 1: działy 0-9 (środowisko, Docker i kind, KVM, Ansible, monitoring, SLO, Alertmanager, load balancer, CI, CD), słowniczek, ściąga składni, tabela błędów.
- Wersja 2: ćwiczenia (pytania, odpowiedzi, zadanie praktyczne) na końcu każdego działu. Notatnik trzymany w repozytorium (`notes/`).
- Wersja 3: dział 10 (Terraform i AWS) z ćwiczeniami, słowniczek i ściąga składni dla Terraform i AWS CLI, nowe wiersze w tabeli błędów, rozszerzone listy kontrolne, nowe zasady (chmura, godziny z metryk).
- Wersja 4: dział 11 (VPS, WireGuard, monitoring z zewnątrz, kontrola kosztów AWS, test awarii B) z ćwiczeniami, nowe wpisy w słowniczku, ściądze, listach kontrolnych i tabeli błędów, nowe zasady. Od teraz notatnik uzupełniam po każdym dziale.
