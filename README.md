## Описание файлов в директории
logFileFull.log - полный лог выполнения  

Vagrant_folder - все что понадобится для поднятия ВМ и краткое описание файлов в ней  
Vagrantfile - вагрант файл  
knock.sh - скрипт для Port Knocking  
provisioning - директория с ролями для провижининга
```
provisioning/
├── library
│   └── iptables_raw.py
├── playbook.yml
└── roles
    ├── centralRouter
    │   ├── defaults
    │   │   └── main.yml
    │   ├── files
    │   ├── handlers
    │   │   └── main.yml
    │   ├── meta
    │   │   └── main.yml
    │   ├── README.md
    │   ├── tasks
    │   │   └── main.yml
    │   ├── templates
    │   ├── tests
    │   │   ├── inventory
    │   │   └── test.yml
    │   └── vars
    │       └── main.yml
    ├── centralServer
    │   ├── defaults
    │   │   └── main.yml
    │   ├── files
    │   ├── handlers
    │   │   └── main.yml
    │   ├── meta
    │   │   └── main.yml
    │   ├── README.md
    │   ├── tasks
    │   │   └── main.yml
    │   ├── templates
    │   ├── tests
    │   │   ├── inventory
    │   │   └── test.yml
    │   └── vars
    │       └── main.yml
    ├── inetRouter
    │   ├── defaults
    │   │   └── main.yml
    │   ├── files
    │   ├── handlers
    │   │   └── main.yml
    │   ├── meta
    │   │   └── main.yml
    │   ├── README.md
    │   ├── tasks
    │   │   └── main.yml
    │   ├── templates
    │   ├── tests
    │   │   ├── inventory
    │   │   └── test.yml
    │   └── vars
    │       └── main.yml
    └── inetRouter2
        ├── defaults
        │   └── main.yml
        ├── files
        ├── handlers
        │   └── main.yml
        ├── meta
        │   └── main.yml
        ├── README.md
        ├── tasks
        │   └── main.yml
        ├── templates
        ├── tests
        │   ├── inventory
        │   └── test.yml
        └── vars
            └── main.yml
```

## Как выглядит сеть и запрос curl
![net](/net.JPG "Сеть дз")

## Описание как запустить виртуальную машину (кратко)
Большая часть ВМ закомментированы, оставленны только нужные inetRouter, inetRouter2, centralRouter, centralServer. Ничего не мешает поднять и оставшиеся ВМ, но на результат работы они не повлияют.
Поднять ВМ и подключиться к ВМ centralRouter
```
vagrant up
vagrant ssh centralRouter
```
Выполнить команды ниже, чтобы подключиться по ssh к inetRouter. Пароль vagrant
```
sudo -i
/vagrant/knock.sh 192.168.255.1 8881 7777 9991
ssh vagrant@192.168.255.1
```
На хосте выполняем curl который пройдет через ВМ inetRouter2
```
curl http://192.168.11.150:8080
```

## ansible playbook только важное
На ВМ inetRouter настраиваем iptables чтобы использовать Port Knocking, с помощью модуля iptables_raw (для него мы подключаем библиотеку iptables_raw.py).
```
- name: MASQUERADE
  iptables_raw:
    name: MASQUERADE
    rules: |
      -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE

- name: custom SSH-INPUT
  iptables_raw:
    name: custom SSH-INPUT
    rules: |
      -N SSH-INPUT
      -A SSH-INPUT -m recent --name SSH1 --set -j DROP

- name: custom SSH-INPUTTWO
  iptables_raw:
    name: custom SSH-INPUTTWO
    rules: |
      -N SSH-INPUTTWO
      -A SSH-INPUTTWO -m recent --name SSH2 --set -j DROP

- name: cutstom TRAFFIC
  iptables_raw:
    name: custom TRAFFIC
    rules: |
      -N TRAFFIC
      -A INPUT -j TRAFFIC
      -A TRAFFIC -p icmp --icmp-type any -j ACCEPT
      -A TRAFFIC -m state --state ESTABLISHED,RELATED -j ACCEPT
      -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 22 -m recent --rcheck --seconds 30 --name SSH2 -j ACCEPT
      -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH2 --remove -j DROP
      -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 9991 -m recent --rcheck --name SSH1 -j SSH-INPUTTWO
      -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH1 --remove -j DROP
      -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 7777 -m recent --rcheck --name SSH0 -j SSH-INPUT
      -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH0 --remove -j DROP
      -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 8881 -m recent --name SSH0 --set -j DROP
      -A TRAFFIC -j DROP
```
так же добавляем статические маршруты через модуль nmcli. Не разобрался как после этого применять настройки через модуль, приходится переподключать интерфейс
```
- name: configure static route
  nmcli:
    conn_name: 'System eth1'
    type: ethernet
    autoconnect: yes
    routes4:
      - 192.168.0.0/24 192.168.255.2
      - 192.168.1.0/24 192.168.255.2
      - 192.168.2.0/24 192.168.255.2
    state: present
  notify:
    - reconnect interface_eth1
```
На ВМ inetRouter2 настраиваем проброс порта. Любой входящий трафик на порт 8080, в PREROUTING меняем адрес назаначения 192.168.0.2:80. А в POSTROUTING меняем адрес отправителя.
```
- name: MASQUERADE
  iptables_raw:
    name: MASQUERADE
    table: nat
    rules: |
      -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
      -A POSTROUTING -p tcp --dst 192.168.0.2 --dport 80 -j SNAT --to 192.168.254.1
```
так же добавляем статические маршруты через модуль nmcli.
```
- name: configure static route
  nmcli:
    conn_name: 'System eth2'
    type: ethernet
    routes4: 192.168.0.2/32 192.168.254.2
    state: present
  notify:
    - reconnect interface_eth2
```
## knock.sh
Вызов скрипта выглядит так
```
/vagrant/knock.sh 192.168.255.1 8881 7777 9991
```
В цикле передаем порты и стучимся через nmap на указаный хост
```
#!/bin/bash
HOST=$1
shift
for ARG in "$@"
do
  nmap -Pn --max-retries 0 -p $ARG $HOST
done
```

📚Домашнее задание/проектная работа разработано(-на) для курса ["Administrator Linux. Professional"](https://otus.ru/lessons/linux-professional/)