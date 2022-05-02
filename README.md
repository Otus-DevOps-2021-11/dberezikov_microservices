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

7. Повторно запускаем ```docker run --network none -d nginx``` указывая сетевой драйвер ```none```  
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
```

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

# ДЗ №14 Устройство Gitlab CI. Построение процесса непрерывной поставки

1. Создаем новую ветку
```css
$ git checkout -b gitlab-ci-1
```

2. Создаем новую vm при помощи Yandex.Cloud CLI
```css
$ yc compute instance create \
--name gitlab-host \
--hostname gitlab-host \
--platform standard-v2 \
--cores 2 \
--core-fraction 50 \
--memory=8 \
--create-disk size=50 \
--zone ru-central1-a \
--network-interface subnet-name=otus-infra-net-ru-central1-a,nat-ip-version=ipv4 \
--create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
--ssh-key ~/.ssh/appuser.pub
``

3. Установка Docker на новый хост  

3.1 Подготовим необходимые каталоги
```css
$ mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs
```

3.2 Подготовим конфигурацию для Ansible
Содержимое ```ansible.cfg```
```css
[defaults]
inventory = ./dynamic-inventory.sh
remote_user = yc-user
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
``` 
Используем скрипт динамического инвентори из прошлых ДЗ

3.3 Подготовим скрипт по установке Docker  
Содержимое ```playbooks/docker_install.yml```
```css
---
- name: Docker Install
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

3.4 Задания со ⭐  
Подготовим Ansible скрипт для развертывания GitLab контейнера  
Содержимое ```playbooks/gitlab_install.yml```
```css
---
- name: Gitlab install
  hosts: all
  become: true
  tasks:
    - name: Pull GitLab image
      docker_image:
        name: gitlab/gitlab-ce:latest
        source: pull

    - name: Create a GitLab container
      community.docker.docker_container:
        name: Gitlab
        image: gitlab/gitlab-ce:latest
        volumes:
          - /srv/gitlab/config:/etc/gitlab
          - /srv/gitlab/logs:/var/log/gitlab
          - /srv/gitlab/data:/var/opt/gitlab
        ports:
          - "80:80"
          - "443:443"
          - "2222:22"
          - "9292:9292"
        env:
          GITLAB_OMNIBUS_CONFIG: "external_url 'http://51.250.11.11'"
```

3.5 Получение пароля root для авторизации в GitLab  
```css
$ ansible all -m shell -a 'sudo docker exec -it <id gitlab контейнера> grep 'Password:' /etc/gitlab/initial_root_password'
```

4. Создаем проект в GitLab по заданию

4.1 Подключаем remote к локальному репозиторию  

Зададим локальные настройки для подкелючения к gitlab хоступ  
Содержимое ```~/.ssh/config```
```css
# GitLab
Host gitlab
  HostName 51.250.11.11
  Port 2222
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/appuser
```

4.2 Подключение remote
```css
$ git remote add gitlab git@gitlab/homework/example.git
```

4.3 Выполняем push в remote
```css
$ git push gitlab gitlab-ci-1
```

5. Определение CI/CD Pipeline  

5.1 В корне репозитория создает файл ```.gitlab-ci.yml```
```css
stages:
  - build
  - test
  - deploy

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  script:
    - echo 'Testing 1'

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_job:
  stage: deploy
  script:
    - echo 'Deploy'
```  

5.2 Отправка изменений в remote
```css
$ git add .gitlab-ci.yml
$ git commit -m 'add pipeline definition'
$ git push gitlab gitlab-ci-1
```

5.3 Добавляем gitlab runner
```css
docker run -d --name gitlab-runner --restart always -v /srv/gitlabrunner/config:/etc/gitlab-runner -v /var/run/docker.sock:/var/run/docker.sock gitlab/gitlab-runner:latest
```

5.4 Регистрация gitlab runner
```css
$ sudo docker exec -it gitlab-runner gitlab-runner register \
--url http://51.250.11.11/ \
--non-interactive \
--locked=false \
--name DockerRunner \
--executor docker \
--docker-image alpine:latest \
--registration-token psc9a2j_bwbWgoenxy8b \
--tag-list "linux,bionic,ubuntu,docker" \
--run-untagged
```

6. Добавим reddit в проект
```css
$ git clone https://github.com/express42/reddit.git && rm -rf ./reddit/.git
$ git add reddit/
$ git commit -m "Add reddit app"
$ git push gitlab gitlab-ci-1
```

7. Изменим описание ```.gitlab-ci.yml```, добавим тесты, dev, stage, prod и динамические окружения
```css
image: ruby:2.4.2

stages:
  - build
  - test
  - review
  - stage
  - production

variables:
  DATABASE_URL: 'mongodb://mongo/user_posts'

before_script:
  - cd reddit
  - bundle install

build_job:
  stage: build
  script:
    - echo 'Building'

test_unit_job:
  stage: test
  services:
    - mongo:latest
  script:
    - ruby simpletest.rb

test_integration_job:
  stage: test
  script:
    - echo 'Testing 2'

deploy_dev_job:
  stage: review
  script:
    - echo 'Deploy'
  environment:
    name: dev
    url: http://dev.example.com

branch review:
  stage: review
  script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
  environment:
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except:
    - master

staging:
  stage: stage
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: beta
    url: http://beta.example.com

production:
  stage: production
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
  environment:
    name: production
    url: http://example.com
```

Отправка изменений в remote
```css
$ git add .gitlab-ci.yml
$ git commit -m 'add tests'
$ git push gitlab gitlab-ci-1
```

> Так же в pipeline были добавлены условия для задач и проведен push с тегами

## Задания со ⭐  
Запуск reddit в контейнере

> Для выполнения этого задания пришлось перерегистрировать gitlab-runner с другими параметрами, иначе в pipeline выдавалась ошибка:  
> ```ERROR: error during connect: Get http://docker:2375/v1.40/info: dial tcp: lookup docker on 10.128.0.2:53: no such host```

1. Перерегистрация pipeline
```css
$ docker exec -it gitlab-runner gitlab-runner register \
 --url http://51.250.11.11/ \
 --registration-token psc9a2j_bwbWgoenxy8b \
  --executor docker \
  --description "My Docker Runner" \
  --docker-image "docker:19.03.12" \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock
```

2. Создаем Dockerfile в корне репозитория
```css
FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y mongodb-server ruby-full ruby-dev build-essential git
RUN gem install bundler
RUN git clone -b monolith https://github.com/express42/reddit.git
RUN sed -i "s/'mongo'$/'mongo', '~> 2.0.0'/" reddit/Gemfile

COPY files/mongod.conf /etc/mongod.conf
COPY files/db_config /reddit/db_config
COPY files/start.sh /start.sh

RUN cd /reddit && rm Gemfile.lock && bundle install
RUN chmod 0777 /start.sh

CMD ["/start.sh"]
```

3. Создаем файловую структуру для сборки Dockerfile
```css
files
├── db_config
├── mongod.conf
└── start.sh
```

4. Что бы контейнер деплоился на динамическое окружение, создаваемое для каждой ветки, необходимо добавить следующий код
```css
stages:
  - build

services:
  - docker:19.03.12-dind

deploy_app:
  image: docker:19.03.12
  stage: build
  before_script:
    - docker info
  script:
    - docker build -t reddit:latest .
    - docker run --name reddit reddit:latest
  environment:
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except:
    - master
```

## Задания со ⭐  
Автоматизация развёртывания GitLab Runner через Ansible playbook

Создаем playbook с именем ```runner_register.yml```
Сожержимое playbook
```css
---
- name: Docker runner register
  hosts: all
  become: true
  vars:
    - runner_name: "{{ my_runner_name }}"
    - runner_token: "{{ my_runner_token }}"
  tasks:
    - name: Pull GitLab runner image
      docker_image:
        name: gitlab/gitlab-runner:latest
        source: pull

    - name: Create a GitLab runner
      community.docker.docker_container:
        name: "{{ runner_name }}"
        image: gitlab/gitlab-runner:latest
        volumes:
          - /srv/gitlabrunner/config:/etc/gitlab-runner
          - /var/run/docker.sock:/var/run/docker.sock gitlab/

    - name: Run a simple command (command)
      community.docker.docker_container_exec:
        container: "{{ runner_name }}"
        command: gitlab-runner register --url http://51.250.11.11/ --non-interactive --locked=false --name DockerRunner --executor docker --docker-image alpine:latest --registration-token "{{ runner_token }}" --tag-list "linux,bionic,ubuntu,docker" --run-untagged
      register: result

    - name: Print stderr lines
      debug:
        var: result.stderr_lines
```

> Для playbook используем входящие переменные имени раннера и токена

Пример запуска playbook с указанием входящих переменных
```css
$ ansible-playbook playbooks/runner_register.yml --extra-vars "my_runner_name=Runner2 my_runner_token=psc9a2j_bwbWgoenxy8b"
```

## Задания со ⭐    
Настройка оповещений в Slack  

Настройка производилась по инструкции https://docs.gitlab.com/ee/user/project/integrations/slack.html  
Ссылка на канал, где можно посмотреть результат настроенной интеграции https://devops-team-otus.slack.com/archives/C02QYLV14KE

# ДЗ №15 Введение в мониторинг. Системы мониторинга.

1. Создаем новую ветку ```monitoring-1```
```css
$ git checkout -b monitoring-1
```

2. Создаем новый хост через yc
```css
yc compute instance create \
--name docker-host \
--hostname docker-host \
--platform standard-v2 \
--cores 2 \
--core-fraction 50 \
--memory=4 \
--create-disk size=50 \
--zone ru-central1-a \
--network-interface subnet-name=otus-infra-net-ru-central1-a,nat-ip-version=ipv4 \
--create-boot-disk image-folder-id=standard-images,image-family=ubuntu-1804-lts,size=15 \
--ssh-key ~/.ssh/appuser.pub
```

Устанавливаем на нем docker через docker machine
```css
docker-machine create \
--driver generic \
--generic-ip-address=178.154.240.54 \
--generic-ssh-user yc-user \
--generic-ssh-key ~/.ssh/appuser \
docker-host
```

Делаем хост активным для docker-machine
```css
$ eval $(docker-machine env docker-host)
```

3. Запускаем Prometheus внутри docker контейнера
```css
$ docker run --rm -p 9090:9090 -d --name prometheus prom/prometheus
```

4. Ознакамливаемся и интерфейсом Prometheus и метриками которые уже собираются с самого Prometheus

5. Подготавливаем свой docker образ Prometheus  
Создаем файл ```monitoring/prometheus/Dockerfile``` с содержимым:
```css
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
```

6. Создаем конфигурацию для сбора метрик, файл ```monitoring/prometheus/prometheus.yml``` с содержимым
```css
---
global:
  scrape_interval: '5s'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets:
        - 'localhost:9090'

  - job_name: 'ui'
    static_configs:
      - targets:
        - 'ui:9292'

  - job_name: 'comment'
    static_configs:
      - targets:
        - 'comment:9292'
```

7. Создаем образ с Prometheus
```css
$ export USER_NAME=seeker00837149
$ docker build -t $USER_NAME/prometheus .
```

Отправляем образ в docker hub
```css
$ docker push $USER_NAME/prometheus
```

8. Собираем образы микросервисов
```css
$ for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done
```

9. Определяем в docker compose новый сервис
```css
version: '3.3'
services:
  post_db:
    image: mongo:${MONGO_TAG}
    volumes:
      - post_db:/data/db
    networks:
      back_net:
        aliases:
          - post_db
  comment_db:
    image: mongo:${MONGO_TAG}
    volumes:
      - comment_db:/data/db
    networks:
      back_net:
        aliases:
          - comment_db
  ui:
    build: ./ui
    image: ${USERNAME_HUB}/ui:${SERVICE_VER}
    ports:
      - 80:9292/tcp
    networks:
      front_net:
        aliases:
          - ui
  post:
    build: ./post-py
    image: ${USERNAME_HUB}/post:${SERVICE_VER}
    container_name: post
    networks:
      front_net:
        aliases:
          - post
      back_net:
        aliases:
          - post
  comment:
    build: ./comment
    image: ${USERNAME_HUB}/comment:${SERVICE_VER}
    networks:
      front_net:
        aliases:
          - comment
      back_net:
        aliases:
          - comment
  prometheus:
    image: ${USERNAME_HUB}/prometheus
    ports:
      - '9090:9090'
    volumes:
      - prometheus_data:/prometheus
    command: # Передаем доп параметры в командной строке
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d' # Задаем время хранения метрик в 1 день
    networks:
      mon_net:
        aliases:
          - mon
      front_net:
        aliases:
          - mon
      back_net:
        aliases:
          - mon

volumes:
  post_db:
  comment_db:
  prometheus_data:

networks:
  front_net:
    driver: bridge
    ipam:
      config:
        - subnet: ${FRONT_NET_SUBNET}
  back_net:
    driver: bridge
    ipam:
      config:
        - subnet: ${BACK_NET_SUBNET}
  mon_net:
    driver: bridge
    ipam:
      config:
        - subnet: ${MON_NET_SUBNET}
```

10. Поднимаем сервисы определенные в docker-compose.yml
```css
$ docker-compose up -d
```

11. Теперь в Prometheus добавились enpoint-ты по сервисам ui и comment, они в состянии UP

12. Проверяем метрики по healtcheck, тестируем поэтапное отключение docker контейнеров с сервисами и наблюдаем результат по графикам

13. Настройка экспортеров  
Добавляем в ```docker-compose.yml``` настройки для экспортера
```css
node-exporter:
  image: prom/node-exporter:v0.15.2
  user: root
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /:/rootfs:ro
  command:
    - '--path.procfs=/host/proc'
    - '--path.sysfs=/host/sys'
    - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
```

В ```monitoring/prometheus/prometheus.yml``` добавляем новый job
```css
- job_name: 'node'
  static_configs:
    - targets:
      - 'node-exporter:9100'
```

14. Собираем новый образ Prometheus и отправляем его в Docker Hub
```css
$ docker build -t $USER_NAME/prometheus .
$ docker push $USER_NAME/prometheus
```

15. Пересоздаем сервисы
```css
$ docker-compose down
$ docker-compose up -d
``` 

16. Проверяем в Prometheus график CPU нагрузив docker host через ```yes > /dev/null```

17. Ссылки на образы в Docker Hub
```css
https://hub.docker.com/repository/docker/seeker00837149/prometheus
https://hub.docker.com/repository/docker/seeker00837149/post
https://hub.docker.com/repository/docker/seeker00837149/comment
https://hub.docker.com/repository/docker/seeker00837149/ui
https://hub.docker.com/repository/docker/seeker00837149/otus-reddit
```

## Задания со ⭐
Добавить в Prometheus мониторинг MongoDB с использованием необходимого экспортера.  


2. Обновляем код в директории /src кодом по ссылке из методички

3. > За основу взял [экспортер от Percona](https://github.com/percona/mongodb_exporter)

Добавляем в ```docker-compose.yml``` инструкции по экспортеру указав нужные сети
```css
  mongodb-exporter:
    image: percona/mongodb_exporter:0.20
    command:
      - '--mongodb.uri=mongodb://post_db:27017'
    networks:
      back_net:
        aliases:
          - mongo_exporter
      mon_net:
        aliases:
          - mongo_exporter
```

В ```monitoring/prometheus/prometheus.yml``` добавляем новый job
```css
  - job_name: 'mongodb'
    static_configs:
      - targets:
        - 'mongodb-exporter:9216'
```

Пересобираем образ Prometheus и отправляем его в Docker Hub
```css
$ docker build -t $USER_NAME/prometheus .
$ docker push $USER_NAME/prometheus
```

Запускаем docker-compose
```css
$ docker-compose up -d
```

Новые метрики по мониторингу mongodb можно найти в интерфейсе Prometheus Graph, введя в поиске ключевое слово ```mongo``` 

## Задания со ⭐
Добавьте в Prometheus мониторинг сервисов comment, post, ui с помощью blackbox экспортера  
> За основу взят [экспортер от Percona](https://github.com/prometheus/blackbox_exporter)

Создаем каталог ```monitoring/blackbox_exporter```
```css
$ mkdir monitoring/blackbox_exporter
```

В каталоге ```blackbox_exporter``` создаем файл ```blackbox.yml``` с следующим содержимым
```css
modules:
  http_2xx:
    prober: http
  http_post_2xx:
    prober: http
    http:
      method: POST
  tcp_connect:
    prober: tcp
  pop3s_banner:
    prober: tcp
    tcp:
      query_response:
      - expect: "^+OK"
      tls: true
      tls_config:
        insecure_skip_verify: false
  grpc:
    prober: grpc
    grpc:
      tls: true
      preferred_ip_protocol: "ip4"
  grpc_plain:
    prober: grpc
    grpc:
      tls: false
      service: "service1"
  ssh_banner:
    prober: tcp
    tcp:
      query_response:
      - expect: "^SSH-2.0-"
      - send: "SSH-2.0-blackbox-ssh-check"
  irc_banner:
    prober: tcp
    tcp:
      query_response:
      - send: "NICK prober"
      - send: "USER prober prober prober :prober"
      - expect: "PING :([^ ]+)"
        send: "PONG ${1}"
      - expect: "^:[^ ]+ 001"
  icmp:
    prober: icmp
```

Рядом создаем файл ```Dockerfile``` с содержимым
```css
FROM prom/blackbox-exporter:master
COPY blackbox.yml /etc/blackbox_exporter/config.yml
```

Собираем образ экспортера и отправляем его в Docker Hub
```css
$ docker build -t $USER_NAME/blackbox_exporter .
$ docker push $USER_NAME/blackbox_exporter
```

Добавляем в файл ```monitoring/prometheus/prometheus.yml``` новый job с экспортером
```css
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [tcp_connect]
    static_configs:
      - targets:
        - ui:9292
        - comment:9292
        - post:27017
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

Пересобираем образ Prometheus и отправляем его в Docker Hub
```css
$ docker build -t $USER_NAME/prometheus .
$ docker push $USER_NAME/prometheus
```

Добавялем в ```docker-compose.yml``` информацию о новом эскпортере, в раздел сети добавляем новую сеть blackbox_net
```css
...
  blackbox-exporter:
    image: ${USERNAME_HUB}/blackbox_exporter
    ports:
      - "9115:9115"
    volumes:
      - blackbox_config:/etc/blackbox_exporter/
    command:
      - '--config.file=/etc/blackbox_exporter/blackbox.yml'
    networks:
      blackbox_net:
        aliases:
          - blackbox_exporter
      front_net:
        aliases:
          - blackbox_exporter
      back_net:
        aliases:
          - blackbox_exporter
      mon_net:
        aliases:
          - blackbox_exporter

...
```

Запускаем docker-compose
```css
$ docker-compose up -d
```

Новые метрики по мониторингу comment, post и ui можно найти в интерфейсе Prometheus Graph, введя в поиске ключевое слово ```probe``` :w

# ДЗ №16 Логирование и распределенная трассировка  

1. Создаем новую ветку ```logging-1```
```css
$ git checkout -b logging-1
```

2. Обновляем код в директории /src кодом по ссылке из методички

3. Собираем обновленный код приложений в Docker образы и отправляем их в Docker Hub
```css
$ export USER_NAME=seeker00837149
$ cd ./src/ui && bash docker_build.sh && docker push $USER_NAME/ui:logging
$ cd ../post-py && bash docker_build.sh && docker push $USER_NAME/post:logging
$ cd ../comment && bash docker_build.sh && docker push $USER_NAME/comment:logging
```

4. Создаем Docker-хост с именем logging и настраиваем локальное окружение на работу с ним

5. Собираем инфраструктуру мониторинга ElasticSearch, Kibana, Fluentd и Zipkin    
   Создаем ```docker-compose-logging.yml``` с следующим содержимым:
```css
version: '3'
services:

  zipkin:
    image: openzipkin/zipkin:2.21.0
    ports:
      - "9411:9411"
    networks:
      - front_net
      - back_net

  fluentd:
    image: seeker00837149/fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"

  elasticsearch:
    image: mrgreyves/elasticsearch:7.13.1
    environment:
      - ELASTIC_CLUSTER=false
      - CLUSTER_NODE_MASTER=true
      - CLUSTER_MASTER_NODE_NAME=es01
      - discovery.type=single-node
    expose:
      - 9200
    ports:
      - "9200:9200"

  kibana:
    image: mrgreyves/kibana:7.13.1
    ports:
      - "5601:5601"

networks:
  back_net:
  front_net:
```

6. Собираем инфраструктуру приложения  
   Содержимое файла ```docker-compose.yml```
```css
version: '3.3'
services:

  post_db:
    image: mongo:${MONGO_TAG}
    volumes:
      - post_db:/data/db
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    networks:
      back_net:
        aliases:
          - post_db

  comment_db:
    image: mongo:${MONGO_TAG}
    volumes:
      - comment_db:/data/db
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    networks:
      back_net:
        aliases:
          - comment_db

  ui:
#    build: ./ui
    image: ${USERNAME_HUB}/ui:${SERVICE_VER}
    ports:
      - 80:9292/tcp
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.ui
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    networks:
      front_net:
        aliases:
          - ui

  post:
#    build: ./post-py
    image: ${USERNAME_HUB}/post:${SERVICE_VER}
    container_name: post
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.post
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    networks:
      front_net:
        aliases:
          - post
      back_net:
        aliases:
          - post

  comment:
#    build: ./comment
    image: ${USERNAME_HUB}/comment:${SERVICE_VER}
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    networks:
      front_net:
        aliases:
          - comment
      back_net:
        aliases:
          - comment

volumes:
  post_db:
  comment_db:

networks:
  front_net:
    driver: bridge
    ipam:
      config:
        - subnet: ${FRONT_NET_SUBNET}
  back_net:
    driver: bridge
    ipam:
      config:
        - subnet: ${BACK_NET_SUBNET}
```

## Задания со ⭐
7. Создаем конфиг fluentd с grok-шаблонами для неструктурированных логов с разбором логов UI-сервиса  
   Содержимое файла ```/docker/fluentd/fluent.conf```

```css
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<filter service.post>
 @type parser
 format json
 key_name log
</filter>

<filter service.ui>
  @type parser
  key_name log
  <parse>
    @type grok
    <grok>
      pattern %{RUBY_LOGGER}
    </grok>
  </parse>
</filter>

<filter service.ui>
  @type parser
  reserve_data true
  key_name message
  <parse>
    @type grok
    <grok>
      pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message=%{GREEDYDATA:message}
    </grok>
    <grok>
      pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{GREEDYDATA:request_id} \| remote_addr=%{IPV4:remote_addr} \| method=\s*%{WORD:method} \| response_status=%{INT:response_status}
    </grok>
  </parse>
</filter>

<match *.**>
  @type copy

  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>

  <store>
    @type stdout
  </store>
</match>
```

8. Собираем образ fluentd с конфигом
```css
$ cd ../logging/fluentd && docker build -t $USER_NAME/fluentd .
```

9 . Поднимаем инфраструктуру приложения и мониторинга
```css
$ cd ../../docker && docker-compose -f docker-compose-logging.yml -f docker-compose.yml up -d
```

10. В интерфейсе Kibana создаем индекс ```fluentd-*``` и указываем поле @timestamp для Time filter.  
- Создаем несколько постов и активностей в приложении, что бы видеть эффект в Kibana,  
- Введя в поисковой строке KQL запрос ```event: post_create``` получаем в выдаче логи момента создания постов в прилождении,  
- Введя в поисковой строке KQL запрос ```@log_name: service.ui``` наблюдаем распарсенные по полям логи        

11. В конфигурациях указанных выше мы уже подключили Zipkin, теперь можно через его интерфейс проверить трейсы запросов и время отработки запросов

## Задания со ⭐
12. Траблшутинг UI-экспириенса  
К сожалению это задание выполнить не удалось. Скачал git репозиторий по ссылке, сбилдил образы приложений и отправил их в Docker Hub с тегом ```bugged```. В ```.env``` файле изменил переменную ```SERVICE_VER``` с ```logging``` на ```bugged```. Поднял приложение из образов с тегом ```bugged```, но в web интерфейсе UI обнаружил ошибку: "Can't show blog posts, some problems with the post service.". Судя по логам UI сервиса он (сервис) не мог подсоединится к post сервису по адресу 127.0.0.1:4567. Переписал Dockerfile для post сервиса добавив в него обновление pip, пересобрал образ, но это не помогло. В данный момет разбираться нет времени, поэтому оставляю второе задание со звездочкой невыполненным.

# ДЗ №17 Введение в kubernetes  

1. Создаем новую верку в репозитории
```css
$ git checkout -b  kubernetes-1
```
2. Создаем необходимые директории
```css
$ mkdir -p kubernetes/reddit
```
3. Создаем файл ```post-deployment.yml``` с следующим содержимым:
```css
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: post-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: post
  template:
    metadata:
      name: post
      labels:
        app: post
    spec:
      containers:
      - image: chromko/post
        name: post
``` 
4. Создадим файлы ```ui-deployment.yml```, ```comment-deployment.yml```, ```mongo-deployment.yml``` по примеру ```post-deployment.yml```

## Задания со ⭐

## Создадим инфраструктуру для k8s кластера через terraform и ansible

5. Создаем каталог ```terraform```
```css
$ mkdir terraform
```

6. Создаем файл ```variables.tf``` с описанием переменных, которые будем использовать
```css
variable token {
  description = "OAuth"
}
variable cloud_id {
  description = "Cloud"
}
variable folder_id {
  description = "Folder"
}
variable zone {
  description = "Zone"
  default = "ru-central1-a"
}
variable region {
  description = "Region"
  default = "ru-central1"
}
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
variable private_key_path {
  description = "Path to the private key used for ssh access"
}
variable subnet_id {
  description = "Subnet"
}
variable service_account_key_file {
  description = "key .json"
}
variable count_of_instances {
  description = "Count of instances"
  default     = 1
}
```

7. Создаем файл ```terraform.tfvars``` с значением переменных
```css
token                    = "***"
cloud_id                 = "***"
folder_id                = "***"
zone                     = "ru-central1-a"
region                   = "ru-central1"
public_key_path          = "~/.ssh/appuser.pub"
private_key_path         = "~/.ssh/appuser"
subnet_id                = "***"
service_account_key_file = "~/key/terraform_key.json"
count_of_instances       = "2"
```

8. Создаем файл ```outputs.tf``` что бы получить ip адреса хостов по завершению развертывания
```css
output "external_ip_address_k8s" {
  value = yandex_compute_instance.k8s[*].network_interface.0.nat_ip_address
}
```

9. Создаем файл манифеста ```main.tf``` с описание подклчения к провайдеру и описанием создаваемых хостов
```css
terraform {
  required_providers {
    yandex = {
      source = "terraform-registry.storage.yandexcloud.net/yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token                    = var.token
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

data "yandex_compute_image" "ubuntu-image" {
  family = "ubuntu-1804-lts"
}

resource "yandex_compute_instance" "k8s" {
  name = "node${1+count.index}"
  count = var.count_of_instances

  resources {
    core_fraction = 20
    cores  = 4
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-image.image_id
      size     = 40
      type     = "network-ssd"
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

10. Проводим инициализацию конфигурации terraform и деплоим хосты в Yandex Cloud
```css
$ terraform init
$ terraform apply --auto-approve
```

11. Создаем каталог ```ansible``` рядом с каталогом ```terraform```
```css
$ mkdir ansible
```

12. Создаем конфиг ```ansible.cfg```
```css
[defaults]
inventory = ./dynamic-inventory.sh
remote_user = ubuntu
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
```

13. Создаем файл ```dynamic-inventory.sh``` динамического инвентори
```css
#!/bin/bash

if [ "$1" == "--list" ] ; then
  if [ -e $inventory_temp ]; then
          echo "[all]" > inventory_temp
  else
          touch inventory_temp
          echo "[all]" > inventory_temp
  fi
  yc compute instance list | grep RUNNING | awk '{print$10}' | grep -v '^|' | sed -E '/^$/d' >> inventory_temp
  if [ -e $inventory.json ]; then
          ansible-inventory --list -i inventory_temp > inventory.json
  else
          touch inventory.json
          ansible-inventory --list -i inventory_temp > inventory.json
  fi
  ansible-inventory --list -i inventory_temp
  rm inventory_temp
elif [ "$1" == "--host" ]; then
          echo '{"_meta": {"hostvars": {}}}'
  else
          echo "{ }"
fi
```

14. Создаем playbook ```docker_v19.03_install.yml``` для установки docker нужной версии (версию пришлось находить опытным путем)
```css
---
- name: Docker Install
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
        - docker-ce=5:19.03.15~3-0~ubuntu-bionic
        - docker-ce-cli=5:19.03.15~3-0~ubuntu-bionic
        - containerd.io

    - name: Install Docker module for Python
      pip:
        name: docker
```

15. Создаем playbook ```kube_install.yml``` для установки Kubernetes
```css
---
- name: Kubelet Kubeadm Kubectl Install
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

    - name: Add Kubernetes apt key
      apt_key:
        url: https://packages.cloud.google.com/apt/doc/apt-key.gpg
        state: present

    - name: Add Kuber repo
      apt_repository:
        repo: deb https://apt.kubernetes.io/ kubernetes-xenial main
        state: present

    - name: Install Kube utils
      apt:
        update_cache: yes
        name:
        - kubelet=1.19.14-00
        - kubeadm=1.19.14-00
        - kubectl=1.19.14-00

    - name: Disable swap memory
      ansible.builtin.shell:
        cmd: swapoff -a
```

16. Проверка работы динамического инвентори
```css
$ ansible all -m ping
```

Вывод резуьтата команды
```css
51.250.77.222 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
51.250.77.185 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

17. Запускаем установку на хосты Docker и Kubernates
```css
$ ansible-playbook playbooks/docker_v18.09_install.yml
$ ansible-playbook playbooks/kube_install.yml
```

18. Заходим на master ноду и инициируем создание Kubernetes кластера
```css
$ ssh -i ~/.ssh/appuser ubuntu@51.250.77.222
$ sudo kubeadm init --pod-network-cidr=10.244.0.0/16
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

После выполнинея команды ```kubeadm init``` получили строку для подключения воркеров к мастеру

19. Переходим на worker ноду и подключаем ее к master
```css
$ ssh -i ~/.ssh/appuser ubuntu@51.250.77.185
$ kubeadm join 10.128.0.16:6443 --token 78ovmg.3du9ygy60tgzvx2o \
    --discovery-token-ca-cert-hash sha256:4701d21f304c04f88ac59fa6cbba5708af2b8e79e46a05c6014b59654d7bf506
```

20. Возвращаемся на master ноду и проверяем статус нод
```css
$ ssh -i ~/.ssh/appuser ubuntu@51.250.77.222
$ kubectl get nodes
```

Ноды в статусе NotReady  

Воспользуемся командой  ```kubectl describe node fhm98pjglkrktvrjpj8h``` и видим, что проблема в неустановленном сетевом плагине  
```runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized```

21. Скачаем и установим сетевой плагин calico
```css
$ curl https://docs.projectcalico.org/manifests/calico.yaml -O
```

Раскоментируем и изменим в файле calico.yaml значение переменной ```CALICO_IPV4POOL_CIDR``` на ```10.244.0.0/16```

Установим плагин
```css
$ kubectl apply -f calico.yaml
```

22. Проверим результат установки сетевого плагина
```css
$ kubectl get nodes
```

Примерно через 15-20 секунд ноды перейдут в состояние Ready
```css
NAME                   STATUS   ROLES    AGE    VERSION
fhm98pjglkrktvrjpj8h   Ready    master   6h6m   v1.19.14
fhmktm3jdra6gcre5oiu   Ready    <none>   6h4m   v1.19.14
```

23. Проверяем установку подов
```css
$ kubectl get pods --all-namespaces
```

```css
NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-6fcb5c5bcf-s68jl       1/1     Running   0          6h4m
kube-system   calico-node-dk9ll                              1/1     Running   0          6h4m
kube-system   calico-node-t97sx                              1/1     Running   0          6h4m
kube-system   coredns-f9fd979d6-ls65g                        1/1     Running   0          6h8m
kube-system   coredns-f9fd979d6-wkhmp                        1/1     Running   0          6h8m
kube-system   etcd-fhm98pjglkrktvrjpj8h                      1/1     Running   0          6h8m
kube-system   kube-apiserver-fhm98pjglkrktvrjpj8h            1/1     Running   0          6h8m
kube-system   kube-controller-manager-fhm98pjglkrktvrjpj8h   1/1     Running   0          6h8m
kube-system   kube-proxy-4t64w                               1/1     Running   0          6h8m
kube-system   kube-proxy-jcpnp                               1/1     Running   0          6h6m
kube-system   kube-scheduler-fhm98pjglkrktvrjpj8h            1/1     Running   0          6h8m
```

24. Скачаем и установим манифесты созданные ранее
```css
$ curl https://raw.githubusercontent.com/Otus-DevOps-2021-11/dberezikov_microservices/kubernetes-1/kubernetes/reddit/ui-deployment.yml -O
$ curl https://raw.githubusercontent.com/Otus-DevOps-2021-11/dberezikov_microservices/kubernetes-1/kubernetes/reddit/post-deployment.yml -O
$ curl https://raw.githubusercontent.com/Otus-DevOps-2021-11/dberezikov_microservices/kubernetes-1/kubernetes/reddit/comment-deployment.yml -O
$ curl https://raw.githubusercontent.com/Otus-DevOps-2021-11/dberezikov_microservices/kubernetes-1/kubernetes/reddit/mongo-deployment.yml -O

$ kubectl apply -f ui-deployment.yml
$ kubectl apply -f post-deployment.yml
$ kubectl apply -f mongo-deployment.yml
$ kubectl apply -f comment-deployment.yml
```

25. Проверка подов через ```kubectl get pods```
```css
NAME                                  READY   STATUS    RESTARTS   AGE
comment-deployment-6fd5474494-n4mt2   1/1     Running   0          6h10m
mongo-deployment-796dd87796-s6g5q     1/1     Running   0          6h10m
post-deployment-799c77ffb-jwghf       1/1     Running   0          6h10m
ui-deployment-7998b8c4c6-mz6nr        1/1     Running   0          6h11m
```

26. Удаляем ноды 
```css
$ terraform destroy
```


К сожалению нет времени делать поднятие k8s кластера полностью автоматичеким средствами ansible и terraform...

