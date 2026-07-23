# mdbci
Репозиторий: https://github.com/mariadb-corporation/mdbci
Документация: https://mdbe-ci-repo.mariadb.net/MDBCI/doc/index.html

## Окружение
Версия ruby: 3.3.10
Для упрощения установки нужной версии можно использовать утилиту [chruby](https://github.com/postmodern/chruby?ysclid=mrsz0hvbb7887987193).
Работу над приложением удобно выполнять в IDE [VS Code](https://code.visualstudio.com/).

В `~/config/mdbci/config.yaml` нужно поместить ключи:
```
---
rhel:
  username: username
  password: password
mdbe:
  key: key
docker:
  username: username
  password: password
  ci-server: server
suse:
  email: email
  key: key
  registration_proxy_url:  registration_proxy_url
mdbe_ci:
  mdbe_ci_repo:
    username: username
    password: password
  es_repo:
    username: username
    password: password
  pergamon_repo:
    username: username
    password: password
force: true
mdbci:
  image_address: image_address
  mdbci_directory: mdbci_directory
```

Ключи требуется запросить у менеджера.

## Сборка
1. Загрузить репозиторий https://github.com/mariadb-corporation/mdbci
2. Перейти в директорию mdbci
3. Установить gem bundler: `gem install bundler`. (Делается один раз)
4. Загрузить зависимости: `bundler install`. (Делается один раз и при каждом обновлении зависимостей)

## Пример использования

Для примера рассмотрим развёртывание виртуальной машины и установку продукта.
Для установки продукта сначала нужно запустить сканер. В корне проекта нужно выполнить команду
```
./mdbci generate-product-repositories --product mdbe
```
Далее нужно развернуть виртуальную машину.
Для этого нужно создать в корне проекта директорию `vms` и добавить туда конфигурационный файл в формате json. Например, создадим файл `libvirt_rhel_10.json` с содержимым:
```
{
  "node012":
  {
    "hostname" : "node012",
    "box" : "rhel_10_libvirt",
    "memory_size" : "4024"
  }
}
```
Название бокса нужно брать [отсюда](https://github.com/mariadb-corporation/mdbci/tree/integration/config/boxes), в зависимости от целевой платформы и архитектуры.

Создадим машину и поднимем её:
```
./mdbci generate --template vms/libvirt_rhel_10.json vms/libvirt_rhel_10
./mdbci up vms/libvirt_rhel_10
```

Установим продукт:
```
./mdbci install_product --product 'mdbe' --product-version latest vms/libvirt_rhel_10/node012
```

Когда машина больше не нужна удаляем её:
```
./mdbci destroy --keep-template vms/libvirt_rhel_10
```

## Релиз обновления mdbeci
После слития изменений в основную ветку следует выложить обновления на сервер. Для этого нужно в gcloud выполнить:
1. Перейти https://mdbe-buildbot.mariadb.net/#/builders?tags=%2Bmaintenance
2. Выбрать build_mdbci
3. Нажать Force в правом верхнем углу и дождаться окончания
4. на gcloud вызвать ./mdbci-devel/andrey/mdbci-update-script/update.sh
5. При необходимости обновить файлы конфигураций на серверах hetzner через ssh:
csadmin@116.202.194.94
csadmin@116.202.197.17
csadmin@116.202.197.12


## Ключевые директории и файлы

| Директория / файл | Назначение |
|-------------------|------------|
| [`core/commands/`](core/commands) | Реализация CLI-команд |
| [`core/commands/generate_repository_partials/`](core/commands/generate_repository_partials/) | Парсеры, которые сканируют удалённые репозитории продуктов и формируют JSON-конфигурации в каталоге `repo.d`. |
| [`core/commands/generate_product_repositories_command.rb`](core/commands/generate_product_repositories_command.rb) | Диспетчер, который разбирает команду `generate-product-repositories`, определяет продукт, вызывает нужный парсер |
| [`assets/chef-recipes/cookbooks/mariadb/recipes/mdberepos.rb`](assets/chef-recipes/cookbooks/mariadb/recipes/mdberepos.rb) | Chef-рецепт добавления репозитория и импорта GPG-ключей |
| [`assets/chef-recipes/cookbooks/`](assets/chef-recipes/cookbooks/) | Все Chef-рецепты |
| [`config/generate_repository_config.yaml`](config/generate_repository_config.yaml) | Основной конфиг для команды `generate-product-repositories`. Задаёт описание путей и ключей для каждого продукта |
| [`core/session.rb`](core/session.rb) | Диспетчер CLI-команд |
| [`core/commands/partials/`](core/commands/partials/) | Генераторы и конфигураторы инфраструктуры: Vagrant, Terraform (AWS/GCP/IBM/DigitalOcean) и др. |
| [`config/boxes/`](config/boxes/) | JSON-файлы с описанием виртуальных машин для разных провайдеров |
| [`core/services/`](core/services/) | Сервисы взаимодействия с облаками, репозиториями, генерация конфигураций |


## Как добавить новый сканер

1. В `config/generate_repository_config.yaml` добавьте конфиг продукта по примеру других продуктов, например, так:
```yaml
new_product:
  repo:
    path: https://repo.mariadb.net/new_product/
    auth_key: new_product_auth
    keys: [https://repo.mariadb.net/new_product/GPG-KEY]
```
2. В `core/commands/generate_repository_partials/` создать файл парсера (имя = lowercase + `_parser.rb`) и добавьте реализацию:
	- Наследуйте `RepositoryParserCore`
	- Реализуйте `self.parse(config, product_version, product_config, log, logger)`
	- Используйте методы из `RepositoryParserCore`: `parse_repository(...)`, `parse_repository_recursive(...)`, `append_url(...)`

В качестве примера можно смотреть на [`mdbe_ci_parser.rb `](core/commands/generate_repository_partials/mdbe_ci_parser.rb) или другие парсеры.

3. В файле `core/commands/generate_product_repositories_command.rb` зарегистрируйте парсер. Обновите:
	- метод `parse_repository`
	- список `PRODUCTS_DIR_NAMES`

## Как добавить новый продукт

1. В `assets/chef-recipes/cookbooks` создайте директорию с названием продукта и структурой:
```
cookbook_name/
├── recipes/          # Ruby-рецепты (install, purge, repos и т.д.)
└── metadata.rb       # Метаданные cookbook (название, версия, автор, зависимости, список рецептов)
```
Для примера можно ориентироваться на рецепт [`mariadb`](assets/chef-recipes/cookbooks/mariadb)

2. В `recipes/` в файле new_product_install.rb реализуйте шаги по установке продукта. При необходимости выделяйте специфичные под каждый дистрибутив шаги.
В `recipes/` new_product_repos.rb при необходимости реализуйте настройку сертификатов и ключей для репозитория, в зависимости от системы.

3. Зарегистрируйте продукт в файле [`core/services/product_attributes.rb`](core/services/product_attributes.rb).

## Как добавить новый дистрибутив (OS / архитектура)

1. Добавьте новую платформу в файл [`core/commands/generate_repository_partials/repository_parser_core.rb`](core/commands/generate_repository_partials/repository_parser_core.rb) в:
	- В список `PLATFORMS`.
	- В список `DEB_VERSIONS` (при необходимости).
	- В список `RPM_PLATFORMS` (при необходимости).
  - В метод `platform_to_repo_name`.
2. В файле `config/generate_repository_config.yaml` в продукты mdbe, mdbe_staging.
3. Во все рецепты в `assets/chef-recipes/cookbooks/`. В рецептах может потребоваться:
	- Выбор дистрибутива:
		```ruby
		case node[:platform]
			`when 'debian'`,
		```
	- Выбор версии дистрибутива:
		```ruby
		case node[:platform_version].to_i
		  when 8
		```
	- Выбор архитектуры:
		```ruby
		node.attributes['kernel']['machine'] == 'aarch64'
		```
4. При необходимости добавьте новый бокс.
5. Пройтись по рецептам и убедиться, что подукты ставятся на новый дистрибутив.
6. Пройтись поиском по проекту по названию старых дистрибутивов, например 'resolute', и при необходимости обновить найденные проверки.

## Добавление нового бокса

Новый бокс добавляется в файлы в `config/boxes/` в зависимости от архитектуры и провайдера.

## Что делать, если появились проблемы с сертификатами/ключами?

Проблемы с ключами обычно можно определить по появлению в логе фрагмента, похожего на этот:
```
2026-07-07T07:50:21 DEBUG: ssh:       ================================================================================
2026-07-07T07:50:21 DEBUG: ssh:       Error executing action `update` on resource 'apt_update[mariadb]'
2026-07-07T07:50:21 DEBUG: ssh:       ================================================================================
2026-07-07T07:50:21 DEBUG: ssh:       Mixlib::ShellOut::ShellCommandFailed
2026-07-07T07:50:21 DEBUG: ssh:       ------------------------------------
2026-07-07T07:50:21 DEBUG: ssh:       execute[apt-get -q update] (mariadb::mdberepos line 81) had an error: Mixlib::ShellOut::ShellCommandFailed: Expected process to exit with [0], but received '100'
2026-07-07T07:50:21 DEBUG: ssh:       ---- Begin output of ["apt-get", "-q", "update"] ----
2026-07-07T07:50:21 DEBUG: ssh:       STDOUT: Get:1 https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease [12.0 kB]
2026-07-07T07:50:21 DEBUG: ssh:       Err:1 https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease
2026-07-07T07:50:21 DEBUG: ssh:         The following signatures couldn't be verified because the public key is not available: NO_PUBKEY A4E98FB7A1F3788F
2026-07-07T07:50:21 DEBUG: ssh:       Hit:3 http://security.ubuntu.com/ubuntu jammy-security InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:2 https://dlm.mariadb.com/repo/<enterpriseToken>/mariadb-enterprise-unsupported/10.6.24-20/deb jammy InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:4 http://us-central1.gce.archive.ubuntu.com/ubuntu jammy InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:5 http://us-central1.gce.archive.ubuntu.com/ubuntu jammy-updates InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Hit:6 http://us-central1.gce.archive.ubuntu.com/ubuntu jammy-backports InRelease
2026-07-07T07:50:21 DEBUG: ssh:       Reading package lists...
2026-07-07T07:50:21 DEBUG: ssh:       STDERR: W: GPG error: https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease: The following signatures couldn't be verified because the public key is not available: NO_PUBKEY A4E98FB7A1F3788F
2026-07-07T07:50:21 DEBUG: ssh:       E: The repository 'https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/columnstore-release-10.6.27-23-stable-23.10-07-06-2026--09-38-13-combined/apt jammy InRelease' is not signed.
2026-07-07T07:50:21 DEBUG: ssh:       ---- End output of ["apt-get", "-q", "update"] ----
2026-07-07T07:50:21 DEBUG: ssh:       Ran ["apt-get", "-q", "update"] returned 100
```

Для решения проблемы, нужно:
1. Убедиться, что в файле `config/generate_repository_config.yaml` у соответствующего продукта актуальный ключ.
2. Убедиться, что в файле `*_repos.rb` продукта ключи поставляются на машину в правильном формате. Для debian-подобных систем в виде `*.gpg`.

## Как понять, где проблема?

В логе обычно указывается команда/метод, который вызывает падение.
Например, в логе:
```
Error executing action `create` on resource 'docker_installation_package[default]'
================================================================================

Errno::ENOENT
-------------
apt_repository[Docker] (docker::default line 37) had an error: Errno::ENOENT: execute[apt-key add /tmp/provision/https___download_docker_com_linux_ubuntu_gpg] (docker::default line 301) had an error: Errno::ENOENT: No such file or directory - apt-key

Cookbook Trace: (most recent call first)
----------------------------------------
/tmp/provision/cookbooks/docker/libraries/docker_installation_package.rb:37:in `block in <class:DockerInstallationPackage>'

Resource Declaration:
```
видно, что у продукта Docker на этапе apt_repository пошло что-то не так. Ищем место в коде и исправляем, как [тут](https://github.com/mariadb-corporation/mdbci/pull/826/changes#diff-be95af79b788274a5d5272bc8b1207b8aa6ecf16a6bb9982258a4bea5c1a894dL37)

Иногда бывают проблемы с приоритетом репозиториев. Обычно проявляется тем, что ставится не указанная версия продукта, а другая.
В этом случае следует зайти на машину и проверить приоритеты репозиториев. Если действительно они сбиты, то поправить можно [следующим способом](https://github.com/mariadb-corporation/mdbci/pull/827/changes#diff-cb3fc0c5e408d1b50295871bed9b15c9c73710dfc7c224d162f4421f90c7fa13R30).