---
title: Первое приложение на dapp
sidebar: doc_sidebar
permalink: get_started.html
---

В этом руководстве описана сборка приложения с помощью утилиты dapp. Перед изучением dapp желательно представлять, что такое Dockerfile и его основные директивы https://docs.docker.io/.

Для запуска примеров понадобятся:

* dapp (Установка описана [здесь](./installation.html))
* docker версии не ниже 1.10
* git

## Сборка простого приложения

Начнём с простого приложения на php. Создайте директорию для тестов и склонируйте репозиторий:

```
git clone https://github.com/awslabs/opsworks-demo-php-simple-app
```

Это совсем небольшое приложение с одной страницей и статическими файлами. Чтобы приложение можно было запустить, нужно запаковать его в контейнер, например, с php и apache. Для этого достаточно такого Dockerfile.

```
$ vi Dockerfile
FROM php:7.0-apache

COPY . /var/www/html/

EXPOSE 80
EXPOSE 443
```

Чтобы собрать и запустить приложение нужно выполнить:

```
$ docker build -t simple-app-v1 .
$ docker run -d --name simple-app simple-app-v1
```

Проверить как работает приложение можно либо зайдя браузером на порт 80, либо локально через curl:

```
$ docker exec -ti simple-app bash
root@da234e2a7777:/var/www/html# curl 127.0.0.1
...
                <h1>Simple PHP App</h1>
                <h2>Congratulations!</h2>
...
```

## Сборка с dapp

Теперь соберём образ приложения с помощью dapp. Для этого нужно создать Dappfile.

* В репозитории могут находится одновременно и Dappfile и Dockerfile - они друг другу не мешают.
* Среди директив Dappfile есть семейство docker.* директив, которые повторяют аналогичные из Dockerfile.

```
$ vi Dappfile

dimg 'simple-php-app' do
  docker.from 'php:7.0-apache'

  git do
    add '/' do
      to '/var/www/html'
      include_paths '*.php', 'assets'
    end
  end

  docker do
    expose 80
    expose 443
  end
end
```

Рассмотрим подробнее этот файл.

`dimg` — эта директива определяет образ, который будет собран. Аргумент simple-php-app — имя этого образа, его можно увидеть, запустив `dapp dimg list`. Блок с вложенными директивами определяет шаги для сборки образа.

`docker.from` — аналог директивы `FROM`. Определяет базовый образ, на основе которого будет собираться образ приложения.

`git` — директива, на первый взгляд аналог директив `ADD` или `COPY`, но с более тесной интеграцией с git. Подробнее про то, как dapp работает с git, можно прочесть в отдельной главе, а сейчас главное увидеть, что директива `git` и вложенная директива `add` позволяют копировать содержимое локального git-репозитория в образ. Копирование производится из пути, указанного в `add`. `'/'` означает, что копировать нужно из корня репозитория. `to` задаёт конечную директорию в образе, куда попадут файлы. С помощью `include_paths` и `exclude_paths` можно задавать, какие именно файлы нужно скопировать или какие нужно пропустить.

`docker do` — директива `docker`, как и многие другие директивы `Dappfile`, имеет блочную запись, с помощью которой можно объединять несколько директив в короткой записи. Т.е. эти два определения эквивалентны:

```
# 1.
docker do
  expose 80
  expose 443
end
```

```
# 2.
docker.expose 80
docker.expose 443
```

Для сборки нужно выполнить команду `dapp dimg build`

```
$ dapp dimg build
simple-php-app
  From ...                                                   [OK] 0.55 sec
  Git artifacts dependencies ...                             [OK] 0.45 sec
  Git artifacts: create archive ...                          [OK] 0.52 sec
  Install group
    Git artifacts dependencies ...                           [OK] 0.39 sec
    Git artifacts: apply patches (after install) ...         [OK] 0.41 sec
  Setup group
    Git artifacts dependencies ...                           [OK] 0.42 sec
    Git artifacts: apply patches (before setup) ...          [OK] 0.69 sec
    Git artifacts dependencies ...                           [OK] 0.41 sec
    Git artifacts: apply patches (after setup) ...           [OK] 0.4 sec
  Git artifacts: latest patch ...                            [OK] 0.39 sec
  Docker instructions ...                                    [OK] 0.42 sec
```

Запустить собранный образ можно с помощью `dapp dimg run`.

```
$ dapp dimg run -d
59ae767d497b4e4fb8c32cd97110cc0f17e67d8e3c7f540cef73b713ef995e5a
```

Теперь можно проверить, как и ранее:

```
$ docker exec -ti simple-php-app bash
root@ef6a519b7e9c:/var/www/html# curl 127.0.0.1
...
                <h1>Simple PHP App</h1>
                <h2>Congratulations!</h2>
...
```

Ура! Первая сборка с помощью dapp прошла успешно.

## Зачем нужен dapp?

Простое приложение показало, что Dappfile может использоваться как замена Dockerfile. Но в чём же плюсы, кроме синтаксиса, немного похожего на Vagrantfile? Внутри dapp есть механизмы, которые незаметны на простом приложении, но для активно разрабатываемого приложения dapp может ускорить сборку и уменьшить размер финальных образов.

Узнать подробнее про возможности dapp можно по ссылками слева, либо продолжить ознакомление со списка возможностей ниже:

### patch вместо полного копирования

В отличие от ADD и COPY dapp переносит изменённые файлы в образ с помощью патчей, а не передачей всех файлов. Подробнее в главе [поддержка git](git_for_build.html).

### сборка образов по стадиям

dapp структурирует сборку, разбивая её на несколько стадий. Такое разбиение позволило ввести зависимости между сборкой стадии и изменениями файлов в репозитории. Например, сборка ассетов на стадии setup будет производиться, если изменились файлы в src, но более ранняя стадия install, где устанавливаются зависимости, будет пересобрана только, если изменился файл package.json. Подробнее в главе [сборка образов по стадиям](stages_for_build.html)

### несколько образов в одном Dappfile

dapp умеет собирать сразу несколько образов по разному описанию в Dappfile. Подробнее в главе [сборка нескольких образов](multiple_images_for_build.html).

### артефакты

Для уменьшения размера финального образа есть рекомендация использовать скачивание+удаление. Например так:

```
RUN “download-source && cmd && cmd2 && remove-source”
```

dapp вводит в сборку понятие артефакта, такие вещи, как компиляция ассетов с помощью внешних инструментов, можно выполнить в другом контейнере и скопировать в финальный только нужные файлы. Подробнее в главе [Артефакт](artifact_for_advanced_build.html).
