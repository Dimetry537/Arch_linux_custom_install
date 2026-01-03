# Полная инструкция по установке Arch Linux с KDE Plasma

Инструкция для установки Arch Linux на ноутбук с UEFI, KDE Plasma и базовой настройкой системы.

## Требования

- Загрузочная флешка с Arch Linux
- Подключение к интернету
- UEFI система с GPT разметкой

## Возможно применение скриптовой установки

curl -O https://your-url/arch-install.sh
chmod +x arch-install.sh
./arch-install.sh

## 1. Разметка диска

Загрузитесь с установочного образа и определите диск:

```bash
lsblk
```

Запустите fdisk:

```bash
fdisk /dev/sda    # замените на ваш диск
```

### Удаление старых разделов

```
p                          # посмотреть текущую разметку
d                          # удалить раздел (повторить для каждого лишнего)
```

> Если разделы заняты: `umount /dev/sdaX` и `swapoff -a`

### Создание новых разделов

Если EFI раздел уже есть — оставьте его. Создайте только swap и root:

```
n                          # новый раздел (swap)
2                          # номер раздела
[Enter]                    # начало по умолчанию
+16G                       # размер (8-16 ГБ в зависимости от RAM)

t                          # сменить тип
2                          # номер раздела
19                         # Linux swap

n                          # новый раздел (root)
3                          # номер раздела
[Enter]                    # начало по умолчанию
[Enter]                    # всё оставшееся место

w                          # записать и выйти
```

> При вопросе "contains a ext4 signature, do you want to remove?" — отвечайте `Y`

## 2. Форматирование разделов

```bash
mkswap /dev/sda2
swapon /dev/sda2
mkfs.ext4 /dev/sda3
```

EFI раздел не трогаем — он уже отформатирован.

## 3. Монтирование

```bash
mount /dev/sda3 /mnt
mount --mkdir /dev/sda1 /mnt/boot
```

## 4. Установка базовой системы

```bash
pacstrap -K /mnt base linux linux-firmware
```

## 5. Генерация fstab

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

## 6. Вход в новую систему

```bash
arch-chroot /mnt
```

## 7. Настройка системы

### Часовой пояс

```bash
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc
```

### Локализация

```bash
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

### Имя компьютера

```bash
echo "archlinux" > /etc/hostname
```

### Пароль root

```bash
passwd
```

## 8. Установка KDE Plasma и необходимых пакетов

```bash
pacman -S plasma-desktop sddm networkmanager konsole dolphin sudo nano openssh
```

### Включение сервисов

```bash
systemctl enable sddm
systemctl enable NetworkManager
```

## 9. Создание пользователя

```bash
useradd -m -G wheel -s /bin/bash username
passwd username
```

### Настройка sudo

```bash
EDITOR=nano visudo
```

Раскомментируйте строку:

```
%wheel ALL=(ALL:ALL) ALL
```

## 10. Установка загрузчика GRUB

```bash
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

## 11. Выход и перезагрузка

```bash
exit
umount -R /mnt
reboot
```

Извлеките флешку при перезагрузке.

---

## Настройка после установки

### Подключение к сети

Если сеть не подключилась автоматически:

```bash
sudo systemctl start NetworkManager
nmtui
```

Для автоподключения:

```bash
nmcli connection modify "Wired connection 1" autoconnect yes
```

### Установка звука

```bash
sudo pacman -S pipewire pipewire-pulse pipewire-alsa wireplumber plasma-pa
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

### Установка Wi-Fi апплета

```bash
sudo pacman -S networkmanager-qt plasma-nm
```

### Установка шрифтов

```bash
sudo pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-liberation ttf-dejavu
fc-cache -fv
```

### Установка zsh и oh-my-zsh

```bash
sudo pacman -S zsh
chsh -s /usr/bin/zsh
```

Установка oh-my-zsh:

```bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Настройка редактора по умолчанию

Добавьте в `~/.zshrc`:

```bash
export EDITOR=nvim
```

Для git:

```bash
git config --global core.editor nvim
```

### Установка yay (AUR helper)

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Установка Google Chrome

```bash
yay -S google-chrome
```

### Установка дополнительных утилит

```bash
sudo pacman -S xorg-xrandr playerctl
```

## Настройка русской раскладки

System Settings → Keyboard → Layouts:

1. Включите "Configure layouts"
2. Добавьте Russian
3. Внизу выберите "Alt+Shift" для переключения

### Добавление индикатора раскладки в трей

1. ПКМ на панели → "Enter Edit Mode"
2. "Add Widgets" → найдите "Keyboard Layout"
3. Перетащите на панель

## Отключение меню GRUB

```bash
sudo nano /etc/default/grub
```

Измените:

```
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
```

Обновите GRUB:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

> Для вызова меню при загрузке зажмите Shift или нажимайте Esc

## Отключение запроса пароля KDE Wallet

Установите kwallet-pam для автоматической разблокировки:

```bash
sudo pacman -S kwallet-pam kwalletmanager
```

Или установите пустой пароль через KWalletManager.

## Отключение восстановления сессии

Чтобы приложения не запускались автоматически при входе:

```bash
kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession
```

Или: System Settings → Startup and Shutdown → Desktop Session → "Start with an empty session"

## Обновление системы

Официальные пакеты:

```bash
sudo pacman -Syu
```

С AUR пакетами:

```bash
yay -Syu
```

---

## Полезные команды

| Команда                            | Описание                           |
| ---------------------------------- | ---------------------------------- |
| `lsblk`                            | Показать диски и разделы           |
| `ip link`                          | Показать сетевые интерфейсы        |
| `nmtui`                            | Текстовый интерфейс настройки сети |
| `kscreen-doctor -o`                | Информация о дисплее               |
| `fc-cache -fv`                     | Обновить кэш шрифтов               |
| `systemctl --user list-unit-files` | Пользовательские сервисы           |

## Решение проблем

### "Device or resource busy" при удалении разделов

```bash
umount /dev/sdaX
swapoff -a
dmsetup remove_all
```

### Нет интернета после установки

```bash
sudo systemctl start NetworkManager
sudo systemctl enable NetworkManager
```

### Квадратики вместо символов

```bash
sudo pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji
fc-cache -fv
```

### Ошибка локали "Cannot set LC_CTYPE"

```bash
sudo nano /etc/locale.gen
# Раскомментируйте en_US.UTF-8 UTF-8 и ru_RU.UTF-8 UTF-8
sudo locale-gen
```
