# Личный VPN на Railway

Shadowsocks-over-WebSocket для [Outline Client](https://getoutline.org/) (v1.15+) с динамическим ключом `ssconf://`.

Railway не даёт прямой TCP/UDP, поэтому VPN работает через **WebSocket поверх HTTPS** — трафик выглядит как обычный веб.

## Что получится

После деплоя у вас будет ссылка вида:

```text
ssconf://your-app.up.railway.app/vanya/74ca7603-e010-4865-982f-64088c7bdc66
```

Клиент скачивает YAML-конфиг по HTTPS и подключается через `wss://`.

## Быстрый старт

### 1. Создайте проект на Railway

1. Зайдите на [railway.app](https://railway.app).
2. **New Project** → **Deploy from GitHub repo** (или загрузите этот репозиторий).
3. Railway соберёт `Dockerfile` автоматически.

### 2. Сгенерируйте публичный домен

1. Откройте сервис → **Settings** → **Networking**.
2. Нажмите **Generate Domain**.
3. Скопируйте домен, например `my-vpn-production.up.railway.app`.

### 3. Задайте переменные окружения

В **Variables** добавьте:

| Переменная | Обязательно | Описание |
|------------|-------------|----------|
| `VPN_DOMAIN` | **Да** | Публичный домен Railway |
| `VPN_SECRET` | Нет | Пароль Shadowsocks (автогенерация) |
| `WS_PATH` | Нет | Секретный путь WebSocket (автогенерация) |
| `KEY_PREFIX` | Нет | Префикс в URL, по умолчанию `vanya` |
| `KEY_UUID` | Нет | UUID в ссылке (автогенерация) |

После изменения `VPN_DOMAIN` сделайте **Redeploy**.

### 4. Возьмите ссылку из логов

Откройте **Deployments** → **View Logs**. При старте контейнер выведет:

```text
ssconf://your-app.up.railway.app/vanya/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Скопируйте и вставьте в **Outline Client** → «Добавить сервер».

### 5. Проверка

```bash
curl https://your-app.up.railway.app/vanya/YOUR-UUID
```

Должен вернуться YAML с `transport:` и `wss://` URL.

Проверьте IP: [ipinfo.io](https://ipinfo.io) — должен отличаться от домашнего.

## Клиент

- **Outline Client** 1.15.0+ (Android, iOS, Windows, macOS, Linux)
- Поддерживает `ssconf://` и Shadowsocks-over-WebSocket

## Ограничения Railway

- **Таймаут соединения ~15 минут** — клиент должен переподключаться автоматически.
- **Трафик платный** — следите за Usage в Railway.
- **Один порт** — всё (VPN + конфиг + заглушка) на одном домене.
- Массовые VPN-сервисы блокируют домены PaaS — для личного использования обычно достаточно.

## Локальная сборка

```bash
docker build -t my-vpn .
docker run --rm -p 8080:8080 \
  -e VPN_DOMAIN=localhost:8080 \
  -e KEY_UUID=74ca7603-e010-4865-982f-64088c7bdc66 \
  my-vpn
```

> Локально WebSocket без TLS (`ws://`) — Outline Client может не подключиться. Для теста конфига достаточно `curl`.

## Структура

```text
├── Dockerfile              # outline-ss-server + nginx
├── railway.toml            # настройки Railway
├── scripts/
│   └── docker-entrypoint.sh  # генерация конфигов и ssconf-ссылки
└── public/
    └── index.html          # страница-заглушка
```

## Смена сервера без новой ссылки

Отредактируйте переменные (`VPN_DOMAIN`, `VPN_SECRET`, `WS_PATH`) и сделайте Redeploy. Ссылка `ssconf://...` остаётся прежней — клиент подтянет новый YAML при подключении.

## Безопасность

- Не публикуйте `ssconf://` ссылку и логи с `VPN_SECRET`.
- Используйте длинный случайный `WS_PATH` и `KEY_UUID`.
- Храните секреты только в Railway Variables.
