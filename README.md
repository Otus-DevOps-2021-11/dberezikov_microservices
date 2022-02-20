# ДЗ №11 Технология контейнеризации. Введение в Docker

1. Создаем новую вeтку ```docker-2``` в репозитории ```microservices```
```css
$ git checkout -b docker-2
```

2. В корне репозиторя создаем директорию ```docker-monolith```

3. Устанавливаем Docker на Debian 10

Установка Docker Engine
```css
$ sudo apt-get update

$ sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

$ curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

$ echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli containerd.io
```

Установка Docker Compose
```css
$ sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

$ sudo chmod +x /usr/local/bin/docker-compose
```

Установка Docker Machine
```css
$ curl -L https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine &&
    chmod +x /tmp/docker-machine &&
    sudo cp /tmp/docker-machine /usr/local/bin/docker-machine
```

4. Изучение на практике основных комманд docker
  - Команды по работе с контейнерами
  - Команды по работе с образами
  - Запуск, остановка контерйнеров, удаление, массовое удаление контейнеров
  - Запуск новых процессов внутри контейнеров
  - Создание образов из контейнера
  - Просмотр ресурсов занимаемых контейнерами и образами
  - Удаление образов по одному и массовое удаление

## Задания со ⭐

Сделать из запущенного контейнера образ 
```css
$ docker commit 66977d3bde70 appuser/ubuntu-tmp-file
```

Сохранить вывол команды ```docker images``` в файл ```docker-monolith/docker-1.log```
```css
$ docker images >> docker-monolith/docker-1.log
```

Сравниваем вывод команд для контейнера и образа
```css
$ docker inspect <u_container_id>
$ docker inspect <u_image_id> 
```

Отличие контерйнера от образа в виде собственного вывода записываем в файл ```docker-monolith/docker-1.log```

Docker machine

1. Создадим в Yndex Cloud хост
```css
yc compute instance create \
--name docker-host \
--zone ru-central1-a \
--network-interface subnet-name=otus-infra-net-ru-central1-a,nat-ip-version=ipv4 \
--create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
--ssh-key ~/.ssh/appuser.pub
```

2. Инициализируем окружение Docker
```css
docker-machine create \
--driver generic \
--generic-ip-address=130.193.39.88 \
--generic-ssh-user yc-user \
--generic-ssh-key ~/.ssh/appuser \
docker-host
```

3. Проверяем, что  окружение создано
```css
$ docker-machine ls
```

4. Сделаем созданное окружение активным
```css
$ eval $(docker-machine env docker-host) 
```

5. Создаем файлы необходмые для дальнейшей сборки образа

```mongod.conf```
```css
# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  bindIp: 127.0.0.1
```

```start.sh```
```css
#!/bin/bash

/usr/bin/mongod --fork --logpath /var/log/mongod.log --config /etc/mongodb.conf

source /reddit/db_config

cd /reddit && puma || exit
```

```db_config```
```css
DATABASE_URL=127.0.0.1
```

```Dockerfile```
```css
FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y mongodb-server ruby-full ruby-dev build-essential git
RUN gem install bundler
RUN git clone -b monolith https://github.com/express42/reddit.git
RUN sed -i "s/'mongo'$/'mongo', '~> 2.0.0'/" reddit/Gemfile

COPY mongod.conf /etc/mongod.conf
COPY db_config /reddit/db_config
COPY start.sh /start.sh

RUN cd /reddit && rm Gemfile.lock && bundle install
RUN chmod 0777 /start.sh

CMD ["/start.sh"]
```

Приложение не будет стартовать, если не добавить строку ```RUN sed -i "s/'mongo'$/'mongo', '~> 2.0.0'/" reddit/Gemfile``` в Dockerfile

6. Собираем образ
```css
$ docker build -t reddit:latest .
```

7. Запускаем контейнер
```css
$ docker run --name reddit -d --network=host reddit:latest
```

8. Проверяем работу приложения через браузер

9. Регистрируемся и авторизуемся в Docker Hub

10. Загрузим наш образ на docker hub
```css
$ docker tag reddit:latest <your-login>/otus-reddit:1.0
$ docker push <your-login>/otus-reddit:1.0
```

11. Проверяем запуск на новом виртуальном хосте или локальной машине 
```css
$ docker run --name reddit -d -p 9292:9292 <your-login>/otus-reddit:1.0
```

## Задания с ⭐
1. Нужно реализовать в виде прототипа в директории /docker-monolith/infra/, 
2. Поднятие инстансов с помощью Terraform, их количество задается переменной,
3. Несколько плейбуков Ansible с использованием динамического инвентори для установки докера и запуска там образа приложения,
4. Шаблон пакера, который делает образ с уже установленным Docker.

Для выполнения данного задания пришлось перейти с образа Ubuntu 16.04 на Ubuntu 18.04, на версии 16.04 были проблемы с модулями Python3 при работе с Ansible

1. Делаем шаблон Packer с установкой Docker через Ansible  
Создаем шаблон ```app.json``` с следующим содержимым:
```css
{
    "builders": [
        {
            "type": "yandex",
            "service_account_key_file": "{{user `service_account_key_file_path`}}",
            "folder_id": "{{user `folder_id`}}",
            "source_image_family": "{{user `source_image_family`}}",
            "image_name": "reddit-base-app-{{timestamp}}",
            "image_family": "reddit-base",
            "ssh_username": "ubuntu",
            "platform_id": "{{user `platform_id`}}",
            "use_ipv4_nat": "true",
            "instance_cores": "{{user `instance_cores`}}",
            "instance_mem_gb": "{{user `instance_mem_gb`}}",
            "instance_name": "{{user `instance_name`}}-app"
        }
    ],
    "provisioners": [
        {
            "type": "ansible",
            "playbook_file": "ansible/playbooks/docker_install.yml"
        }
    ]
}
```

Содержимое Ansible плейбука ```ansible/playbooks/docker_install.yml```
```css
---
- name: Docker install
  hosts: all
  become: true
  tasks:
    - name: Install dependencies
      apt:
        update_cache: yes
        name:
        - apt-transport-https
        - ca-certificates
        - curl
        - software-properties-common
        - python3-pip
        - gnupg
        state: present

    - name: Add Docker apt key
      apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repo
      apt_repository:
        repo: deb https://download.docker.com/linux/ubuntu bionic stable
        state: present

    - name: Install Docker Engine
      apt:
        update_cache: yes
        name:
        - docker-ce
        - docker-ce-cli
        - containerd.io
        state: latest

    - name: Install Docker module for Python
      pip:
        name: docker
```

2. Подготавливаем конфиг для Terraform с учетом возможности выбора количества разворачиваемых инстансов  
Содержимое ```main.tf```
```css
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_compute_instance" "app" {
  count = var.instances_count
  name = "reddit-app${count.index}"
  zone = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  connection {
    type  = "ssh"
    host  = self.network_interface.0.nat_ip_address
    user  = "ubuntu"
    agent = false
    private_key = file(var.private_key_path)
  }
}
```

Остальные файлы берем по примеру из предыдущих проектов

3. Подготавливаем конфиги Ansible  
Содержимое ```ansible.cfg``` с указание динамического инвентори
```css
[defaults]
inventory = ./dynamic_inventory.sh
remote_user = ubuntu
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
```

Создаем плейбук ```playbooks/start_app.yml``` для деплоя приложения на развернутые инстансы
```css
---
- name: Start app in Docker
  hosts: all
  become: true
  tasks:
    - name: Deploy app docker container
      docker_container:
        image: seeker00837149/otus-reddit:1.0
        name: reddit
        state: started
        auto_remove: true
        ports:
          - "80:9292"
```

В плейбуке переопределяем порт порт 9292 на порт 80 для удобства проверки готового приложения из браузера

4. Запускаем поочередно все этапы

Сборка образа через Packer 
```css
$ packer build -var-file=packer/variables.json packer/app.json
```

Организация инстансов через Terraform  
Организуем 5 инстансов через явное указание переменной ```instances_count          = "5"``` в конфиге ```terraform/terraform.tfvars```

Запускаем организацию инстансов
```css
$ terraform apply -auto-approve
```

Проверим через динамический инвентори доступность все 5 организованных хостов   
Используем модуль ping
```css
$ ansible all -m ping
```

Наблюдаем вывод в консоль
```css
178.154.201.96 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
178.154.204.60 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
178.154.206.130 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
178.154.203.95 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
84.201.157.158 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

Теперь запустим плейбук по деплою приложения на организованные инстансы
```css
$ ansible-playbook playbooks/start_app.yml
```

Вывод в консоль
```css
PLAY [Start app in Docker] *********************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] *************************************************************************************************************************************************************************************************************************************
ok: [178.154.204.60]
ok: [178.154.201.96]
ok: [84.201.157.158]
ok: [178.154.206.130]
ok: [178.154.203.95]

TASK [Deploy app docker container] *************************************************************************************************************************************************************************************************************************
changed: [178.154.204.60]
changed: [178.154.201.96]
changed: [84.201.157.158]
changed: [178.154.206.130]
changed: [178.154.203.95]

PLAY RECAP *************************************************************************************************************************************************************************************************************************************************
178.154.201.96             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
178.154.203.95             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
178.154.204.60             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
178.154.206.130            : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
84.201.157.158             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

5. Проверка работы приложения  
Возьмем на выбор пару ip из списка и проверим через браузер работу приложения по порту 80

# ДЗ №12 Docker-образы. Микросервисы

1. Создаем новую ветку ```docker-3```
```css
$ git checkout -b docker-3
```

2. Устанавливаем linter
```css
$ sudo wget -O /bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.8.0/hadolint-Linux-x86_64
$ sudo chmod +x /bin/hadolint
```

3. Создаем новый виртуальный хост и подключаемся к нему через docker-machine
```css
docker-machine create \
--driver generic \
--generic-ip-address=62.84.113.48 \
--generic-ssh-user ubuntu \
--generic-ssh-key ~/.ssh/appuser \
docker-host
```

```css
eval $(docker-machine env docker-host)
```

4. Скачиваем и распаковываем архив внутри репозитория
```css
$ wget https://github.com/express42/reddit/archive/microservices.zip
$ unzip microservices.zip
$ rm microservices.zip
$ mv reddit-microservices src
```

5. Создаем файл ```./post-py/Dockerfile``` для сервиса post с следующим содержимым
```css
FROM python:3.6.0-alpine

WORKDIR /app
ADD . /app

RUN apk --no-cache --update add build-base && \
    pip install -r /app/requirements.txt && \
    apk del build-base

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
```

6. Создаем файл ```./comment/Dockerfile``` для сервиса comment с следующим содержимым
```css
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

CMD ["puma"]
```

7. Создаем файл ```./ui/Dockerfile``` для сервиса ui с следующим сорержимым
```css
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```


8. Собираем приложение
```css
$ docker pull mongo:latest
$ docker build -t seeker00837149/post:1.0 src/post-py
$ docker build -t seeker00837149/comment:1.0 src/comment
$ docker build -t seeker00837149/ui:1.0 src/ui
```

> Сборка ```ui``` началась не с первого шага, т.к. образ ruby:2.2 и build-essential скачивались в предыдущем шаге и в момент сборки ```ui``` беруться из кеша

9. Запуск приложения
```css
$ docker network create reddit
$ docker run -d --network=reddit \
 --network-alias=post_db --network-alias=comment_db mongo:latest
$ docker run -d --network=reddit \
 --network-alias=post seeker00837149/post:1.0
$ docker run -d --network=reddit \
 --network-alias=comment seeker00837149/comment:1.0
$ docker run -d --network=reddit \
 -p 80:9292 seeker00837149/ui:1.0
```

> Для удобства проверки работы приложения в браузере сделаем проброс внутреннего порта 9292 на внешний порт 80

## Задания со ⭐

10. Останавливаем контейнеры
```css
$ docker kill $(docker ps -q)
```

11. Запустим контейнеры с другими сетевыми алиасами и зададим пременные окружения не пересоздавая образ
```css
$ docker run -d --network=reddit \
--network-alias=db_host --name mongo_db mongo:latest
$ docker run -d --network=reddit --env POST_DATABASE_HOST='db_host' \
--network-alias=post_host --name post seeker00837149/post:1.0
$ docker run -d --network=reddit \
--env COMMENT_DATABASE_HOST='db_host' --network-alias=comment_host --name comment seeker00837149/comment:1.0
$ docker run -d --network=reddit --env POST_SERVICE_HOST='post_host' --env COMMENT_SERVICE_HOST='comment_host' \
-p 80:9292 --name ui seeker00837149/ui:1.0
```

12. Проверим работу приложения из браузера

13. Улучшаем образ для ```ui``` сервиса  
Зименяем содержимое ./ui/Dockerfile на следующии
```css
FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y ruby-full ruby-dev build-essential \
    && gem install bundler --no-ri --no-rdoc

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```

14. После пересборки образа видим, что образ на основе ubuntu:16.04 имеет значительно меньший размер по сравнению с образом ruby:2.2

## Задания со ⭐

14. Собираем образ на основе Alpine Linux и производим прочие улучшения

14.1 Для проверки кода Dockerfile воспользуемся установленным ранее линтером  
Пример проверки файла и результат проверки
```css
$ hadolint ./ui/Dockerfile
```

Пример вывода результата проверки
```
./ui/Dockerfile:2 DL3008 warning: Pin versions in apt get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`
./ui/Dockerfile:2 DL3009 info: Delete the apt-get lists after installing something
./ui/Dockerfile:2 DL3015 info: Avoid additional packages by specifying `--no-install-recommends`
./ui/Dockerfile:8 DL3020 error: Use COPY instead of ADD for files and folders
./ui/Dockerfile:10 DL3020 error: Use COPY instead of ADD for files and folders
```

На основе выводов линтера производим улучшения Dockerfile для сервисов

14.2 Пример ```Dockerfile``` сервиса ```ui``` с образа Alpine
```css
FROM alpine:3.14

WORKDIR /app
ADD . /app

RUN apk update \
    && apk add ruby ruby-dev ruby-full g++ make \
    && gem install bundler:1.17.2 \
    && bundle install \
    && apk del ruby-dev g++ make

ENV POST_SERVICE_HOST=post \
    POST_SERVICE_PORT=5000 \
    COMMENT_SERVICE_HOST=comment \
    COMMENT_SERVICE_PORT=9292

CMD ["puma"]
```

Все команды по обновлению и установке приложений собраны в один слой  
Все переменные собраны в один слой

> Версии ```Dockerfile``` с улучшениями находятся в директориях с сервисами и обозначены ```Dockerfile.<цифра>```

15. Для возможности сохранения информации после выключения контейнеров создадим Docker volume и подключим его к контейнеру с MongoDB
```css
$ docker volume create reddit_db
```

Выключаем старые контейнеры
```css
$ docker kill $(docker ps -q)
```

Запускаем новые контейнеры с примапливанием Docker volume
```css
$ docker run -d --network=reddit --network-alias=post_db \
 --network-alias=comment_db -v reddit_db:/data/db mongo:latest
$ docker run -d --network=reddit \
 --network-alias=post seeker00837149/post:3.0
$ docker run -d --network=reddit \
 --network-alias=comment seeker00837149/comment:3.0
$ docker run -d --network=reddit \
 -p 80:9292 seeker00837149/ui:3.0
```

После проверки приложения и написание тестового поста, для проверки сохранности поста, снова останавливаем контейнеры и запускаем новые.

# ДЗ №13 Docker: сети, docker-compose

1. Создаем новую ветку 
```css
$ git checkout -b docker-4
```

2. Подключаемся к ранее созданному хосту
```css
$ eval $(docker-machine env docker-host)
```

3. Запустим контейнер и передадим внутрь него команду ```ipconfig```
```css
$ docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig
```
В выводе информация по трем сетевым интерйейсам docker0, eth0 и lo

4. Запустим команду ```iconfig``` и передадим ее на сам хост (не в контейнер)
```css
$ docker-machine ssh docker-host ifconfig
```
В выводе информация о том, что команда не найдена. Команда из пункта №3 запускала контейнер с его последующим уничтожением после отработки команды ```ifconfig```, на самом сервере утилиты net-tools не установлены, поэтому и команды ```ifconfig``` была не найдена после выполнения команды из пункта №4

5. Запустим команду ```docker run --network host -d nginx``` 4 раза  
В выводе ```docker ps``` через несколько секунд останется только вызыванный первым контейнер. Так происходит по причине того, что сеть при запуске контейнеров мы указываем ```host```, т.е. сетевой стек не изолирован от хоста и в момент поднятия второго контейнера система видит, что порт 80 уже занят и контейнер останавливается.

6. Повторно запускаем ```docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig``` указывая сетовой драйвер ```none```  
В выводе видим только интерфейс lo, т.к. сетевой драйвер ```none``` отключает всю сеть для контейнера

7. Повторно щапускаем ```docker run --network none -d nginx``` указывая сетевой драйвер ```none```  
В выводе ```docker ps``` видим столько контейнеров, сколько раз запустили команду, теперь контейнеры не останавливаются, т.к. сеть для них отключена и порт 80 самого хоста никто из них не занимает

8. Bridge network driver  
Выполнены все команды из методической литературы. Контейнеры распределены по двум сетям. Итоговый результат, приложение работает.

9. Docker-compose  
Создадим файл ```docker-compose.yml``` в директории ```src``` с следующим содержимым
```css
version: '3.3'
services:
  post_db:
    image: mongo:3.2
    volumes:
      - post_db:/data/db
    networks:
      - reddit
  ui:
    build: ./ui
    image: ${USERNAME_HUB}/ui:1.0
    ports:
      - 9292:9292/tcp
    networks:
      - reddit
  post:
    build: ./post-py
    image: ${USERNAME_HUB}/post:1.0
    networks:
      - reddit
  comment:
    build: ./comment
    image: ${USERNAME_HUB}/comment:1.0
    networks:
      - reddit

volumes:
  post_db:

networks:
  reddit:
```

Сделаем экспорт переменной ```USERNAME_HUB```
```css
$ export USERNAME_HUB=seeker00837149
```

Теперь можно запустить docker-compose
```css
$ docker-compose up -d
```

10. Задание  

Изменим docker-compose под кейс с множеством сетей; параметризируем с помощью переменных окружения внешний порт, версию сервисов, tag для mongo образа, подсети для сетей front_net и back_net, все переменные разместим в файле ```.env```

Содержимое скорректированного файла ```docker-compose.yml```
```css
version: '3.3'
services:
  post_db:
    image: mongo:${MONGO_TAG}
    container_name: db
    volumes:
      - post_db:/data/db
    networks:
      - back_net
  ui:
    build: ./ui
    image: ${USERNAME_HUB}/ui:${SERVICE_VER}
    container_name: ui
    ports:
      - 80:9292/tcp
    networks:
      - front_net
  post:
    build: ./post-py
    image: ${USERNAME_HUB}/post:${SERVICE_VER}
    container_name: post
    networks:
      - front_net
      - back_net
  comment:
    build: ./comment
    image: ${USERNAME_HUB}/comment:${SERVICE_VER}
    container_name: comment
    networks:
      - front_net
      - back_net

volumes:
  post_db:

networks:
    front_net:
        name: front_net
        driver: bridge
        ipam:
            config:
                - subnet: ${FRONT_NET_SUBNET}
    back_net:
        name: back_net
        driver: bridge
        ipam:
            config:
                - subnet: ${BACK_NET_SUBNET}
``

Содержимое файла ```.env```
```css
USERNAME_HUB=seeker00837149
EXT_PORT=80
SERVICE_VER=1.0
MONGO_TAG=3.2
FRONT_NET_SUBNET=10.0.1.0/24
BACK_NET_SUBNET=10.0.2.0/24
```

При запуске проекта все сущности получают префикс от имени каталога, в котором запускается docker-compose.  
Изменить имена сущностей можно несколькими способами:
1) Указав в файле ```docker-compose.yml``` префиксы для контейнеров через ```container_name```, для сетей через ```name```

2) Задать имя проекта можно при запуске docker-compose через ключ -p, пример
```css
$ docker-compose -p reddit up -d
```

3) С помощью переменной окружения ```COMPOSE_PROJECT_NAME```

## Задания со ⭐  

Создаем файл ```docker-compose.override.yml```, который будет переопределять действующие контейнеры  
Создадим volumes для монтирования каталогов с приложением на хост машину в каталог по умолчанию
В сервисы ```ui``` и ```comment``` допишем запуск приложения ```puma``` с флагами ```--debug``` и ```-w 2```

Содержимое файла
```css
version: '3.3'
services:
  ui:
    volumes:
      - ui_vol:/app
    command: puma --debug -w 2

  post:
    volumes:
      - post_vol:/app

  comment:
    volumes:
      - comment_vol:/app
    command: puma --debug -w 2

volumes:
  ui_vol:
  post_vol:
  comment_vol:
```

Проверяем, что переопределение для контейнеров подхватится системой
```css
$ docker-compose config
```

Запускаем ```docker-compose```
```css
$ docker-compose up -d
```

Проверяем работу приложения из браузера
