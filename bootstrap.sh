#!/bin/bash
set -e

read -p "Имя пользователя: " USERNAME

while true; do
  read -s -p "Пароль пользователя: " USER_PASSWORD
  echo
  read -s -p "Повтори пароль: " USER_PASSWORD_CONFIRM
  echo

  [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]] && break
  echo "Пароли не совпадают, попробуй ещё раз"
done

