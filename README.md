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
