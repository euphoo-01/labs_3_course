#!/usr/bin/env bash
# Лабораторная работа №5, задания 17-20. Только диагностические команды.
# Arch Linux (хост) -> Oracle Database (Docker-контейнер).
# Использование: bash Lab05_Docker_Listener.sh ИМЯ_КОНТЕЙНЕРА
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo 'Использование: bash Lab05_Docker_Listener.sh ИМЯ_КОНТЕЙНЕРА'
  echo 'Текущие контейнеры:'
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
  exit 1
fi

container="$1"
echo '=== Docker: контейнер и порты ==='
docker ps --filter "name=$container" --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'

echo
echo '=== 17. Linux-процессы Oracle и Listener ==='
docker exec "$container" sh -c 'ps -ef | grep -E "[t]nslsnr|[o]ra_|[o]racle" || true'

echo
echo '=== 18. Параметры среды, Listener и поиск listener.ora ==='
docker exec "$container" sh -c '
  echo "ORACLE_HOME=${ORACLE_HOME:-<не задан>}"
  echo "TNS_ADMIN=${TNS_ADMIN:-<не задан>}"
  echo "PATH=$PATH"
  lsnr=$(command -v lsnrctl || true)
  if [ -z "$lsnr" ] && [ -n "${ORACLE_HOME:-}" ] && [ -x "$ORACLE_HOME/bin/lsnrctl" ]; then
    lsnr="$ORACLE_HOME/bin/lsnrctl"
  fi
  if [ -z "$lsnr" ]; then
    lsnr=$(find /opt/oracle /u01 -type f -name lsnrctl -print -quit 2>/dev/null || true)
  fi
  if [ -z "$lsnr" ]; then
    echo "lsnrctl не найден. Проверьте образ и ORACLE_HOME."
    exit 0
  fi
  echo "lsnrctl: $lsnr"
  echo "--- lsnrctl status ---"
  "$lsnr" status || true
  echo "--- listener.ora (поиск в известных каталогах) ---"
  for directory in "${TNS_ADMIN:-}" "${ORACLE_HOME:-}/network/admin" /opt/oracle/network/admin; do
    if [ -n "$directory" ] && [ -f "$directory/listener.ora" ]; then
      echo "Файл: $directory/listener.ora"
      sed -n "1,160p" "$directory/listener.ora"
    fi
  done
  echo "ПРИМЕЧАНИЕ: listener.ora может отсутствовать при динамической регистрации сервисов."
  echo "--- 19-20. lsnrctl services ---"
  "$lsnr" services || true
'

cat <<'END'

Пояснения для защиты:
  - tnslsnr: процесс Listener в контейнере (аналог Windows-сервиса).
  - STATUS: состояние, адреса/порты и сводка сервисов.
  - SERVICES: сервисы, экземпляры, обработчики и их состояние.
  - LISTENER.ORA: статическая конфигурация; отсутствие файла не исключает работу.
  - Listener не равен самой БД и не является серверным процессом SQL-сессии.
  - Команды start/stop/reload НЕ выполнялись, чтобы не нарушить подключения.
END
