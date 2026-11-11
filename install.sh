#!/usr/bin/env bash
# ==============================================================================
#  DroneFlames Reborn - Universal Linux Installer & Environment Configurator
#  Supports: Arch, Ubuntu, Debian, Fedora, openSUSE, Void, Alpine, etc.
#  Desktop / WM: Hyprland (Wayland), Sway, XFCE, KDE Plasma, GNOME, and others.
#  Author: Reborn Team / Reborn Team
# ==============================================================================

set -eo pipefail

# --- Logging Initialization ---
LOG_FILE="${HOME}/droneflames-install.log"
TMP_LOG="/tmp/droneflames-install.log"
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/droneflames-install.log"

# Duplicate stdout and stderr to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

INSTALL_START_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# Text Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[1;32m"
C_BLUE="\033[1;34m"
C_CYAN="\033[1;36m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"

log_info() { echo -e "${C_CYAN}[INFO]${C_RESET} $*"; }
log_ok()   { echo -e "${C_GREEN}[ OK ]${C_RESET} $*"; }
log_warn() { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
log_err()  { echo -e "${C_RED}[FAIL]${C_RESET} $*"; }
log_step() { echo -e "\n${C_BOLD}${C_BLUE}==>${C_RESET} ${C_BOLD}$*${C_RESET}"; }

on_error() {
    local exit_code=$1
    local line_no=$2
    echo ""
    log_err "Произошла ошибка при установке DroneFlames!"
    echo -e "${C_RED}Строка ошибки: ${line_no}, Код завершения: ${exit_code}${C_RESET}"
    echo -e "${C_YELLOW}Подробный лог сохранен в: ${LOG_FILE}${C_RESET}"
    cp -f "$LOG_FILE" "$TMP_LOG" 2>/dev/null || true
    echo -e "Также резервная копия лога: ${TMP_LOG}"
    echo -e "\nПожалуйста, отправьте этот лог разработчику для решения проблемы:"
    echo -e "  Telegram:  Reborn Team / Reborn Team"
    echo -e "  GitHub:    https://github.com/makkaX2/DroneFlames-PC-Port/issues"
    echo "=================================================================="
    exit "$exit_code"
}

trap 'on_error $? $LINENO' ERR

echo "=================================================================="
echo -e "${C_BOLD}${C_GREEN}    Универсальный установщик DroneFlames Reborn для Linux${C_RESET}"
echo -e "${C_CYAN}    Время запуска: ${INSTALL_START_TIME}${C_RESET}"
echo "=================================================================="

# --- 1. System & Environment Detection ---
log_step "1. Определение параметров операционной системы и окружения..."

OS_ID="unknown"
OS_NAME="Linux"
OS_VERSION=""
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-$NAME}"
    OS_VERSION="${VERSION_ID:-}"
elif [ -f /etc/issue ]; then
    OS_NAME=$(head -n 1 /etc/issue | cut -d' ' -f1-3)
fi

ARCH=$(uname -m)
KERNEL=$(uname -r)

log_info "Дистрибутив: ${OS_NAME} (ID: ${OS_ID}, Версия: ${OS_VERSION:-N/A})"
log_info "Архитектура: ${ARCH}"
log_info "Ядро Linux:  ${KERNEL}"

if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    log_warn "Обнаружена архитектура $ARCH. Официальный бинарник Godot собран под x86_64."
    log_warn "Возможно, потребуется эмуляция (например, Box64 / FEX-Emu)."
fi

# Detect Graphical Environment / Window Manager / Compositor
DETECTED_WM="Generic / Unknown"
IS_HYPRLAND=false
IS_WAYLAND=false
IS_XFCE=false

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    DETECTED_WM="Hyprland (Wayland Compositor)"
    IS_HYPRLAND=true
    IS_WAYLAND=true
elif [ "${XDG_CURRENT_DESKTOP:-}" = "Hyprland" ]; then
    DETECTED_WM="Hyprland (Wayland)"
    IS_HYPRLAND=true
    IS_WAYLAND=true
elif [ -n "${SWAYSOCK:-}" ] || [ "${XDG_CURRENT_DESKTOP:-}" = "sway" ]; then
    DETECTED_WM="Sway (Wayland Compositor)"
    IS_WAYLAND=true
elif [ "${XDG_CURRENT_DESKTOP:-}" = "XFCE" ] || [ "${DESKTOP_SESSION:-}" = "xfce" ]; then
    DETECTED_WM="XFCE Desktop Environment"
    IS_XFCE=true
elif echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "kde\|plasma"; then
    DETECTED_WM="KDE Plasma (${XDG_SESSION_TYPE:-x11})"
    [ "${XDG_SESSION_TYPE:-}" = "wayland" ] && IS_WAYLAND=true
elif echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "gnome"; then
    DETECTED_WM="GNOME Desktop (${XDG_SESSION_TYPE:-x11})"
    [ "${XDG_SESSION_TYPE:-}" = "wayland" ] && IS_WAYLAND=true
elif echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "cinnamon"; then
    DETECTED_WM="Cinnamon Desktop"
elif echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "mate"; then
    DETECTED_WM="MATE Desktop"
elif echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "lxqt\|lxde"; then
    DETECTED_WM="LXQt / LXDE Desktop"
elif [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
    DETECTED_WM="${XDG_CURRENT_DESKTOP} (${XDG_SESSION_TYPE:-unknown})"
fi

[ "${XDG_SESSION_TYPE:-}" = "wayland" ] && IS_WAYLAND=true

log_ok "Определено графическое окружение: ${DETECTED_WM}"
[ "$IS_HYPRLAND" = true ] && log_info "Режим Hyprland: включена поддержка rofi/wofi/waybar и запуск под Wayland/XWayland."
[ "$IS_XFCE" = true ] && log_info "Режим XFCE: включена генерация иконок для Whisker Menu и рабочего стола."

# Hardware / GPU Detection
log_info "Определение графического ускорителя:"
if command -v lspci >/dev/null 2>&1; then
    lspci | grep -Ei "vga|3d|display" | while read -r line; do
        echo "       $line"
    done
elif [ -d /sys/class/drm ]; then
    ls -1 /sys/class/drm | grep -v "-" | while read -r card; do
        echo "       /sys/class/drm/$card"
    done
else
    echo "       (информация о GPU недоступна)"
fi

# --- 2. Package Manager & Dependencies ---
log_step "2. Проверка и установка системных зависимостей..."

has_cmd() { command -v "$1" >/dev/null 2>&1; }

SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
    if has_cmd sudo; then
        SUDO_CMD="sudo"
    elif has_cmd doas; then
        SUDO_CMD="doas"
    fi
fi

# Check sudo capability
CAN_SUDO=false
if [ -n "$SUDO_CMD" ]; then
    if $SUDO_CMD -n true 2>/dev/null; then
        CAN_SUDO=true
    elif [ -t 0 ] || [ -e /dev/tty ]; then
        CAN_SUDO=true
    fi
fi

MISSING_CORE_TOOLS=()
for tool in curl unzip tar git; do
    if ! has_cmd "$tool"; then
        MISSING_CORE_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_CORE_TOOLS[@]} -gt 0 ]; then
    log_info "Отсутствуют утилиты: ${MISSING_CORE_TOOLS[*]}"
fi

PKG_MANAGER="unknown"
if has_cmd pacman; then
    PKG_MANAGER="pacman"
elif has_cmd apt-get; then
    PKG_MANAGER="apt"
elif has_cmd dnf; then
    PKG_MANAGER="dnf"
elif has_cmd zypper; then
    PKG_MANAGER="zypper"
elif has_cmd apk; then
    PKG_MANAGER="apk"
elif has_cmd xbps-install; then
    PKG_MANAGER="xbps"
fi

log_info "Менеджер пакетов системы: ${PKG_MANAGER}"

install_dependencies() {
    if [ "$CAN_SUDO" = false ] && [ "$(id -u)" -ne 0 ]; then
        log_warn "Установка пакетов требует прав sudo. Если у вас нет sudo, убедитесь что установлены: curl, unzip, git."
        return 0
    fi

    log_info "Автоматическая установка необходимых библиотек через $PKG_MANAGER..."
    case "$PKG_MANAGER" in
        pacman)
            $SUDO_CMD pacman -Sy --needed --noconfirm git git-lfs curl unzip tar ca-certificates alsa-lib libx11 libxcursor libxinerama libxrandr libxi libxkbcommon wayland libglvnd || true
            ;;
        apt)
            $SUDO_CMD apt-get update -y || true
            local asound_pkg="libasound2"
            if apt-cache show libasound2t64 >/dev/null 2>&1; then
                asound_pkg="libasound2t64"
            fi
            DEBIAN_FRONTEND=noninteractive $SUDO_CMD apt-get install -y git git-lfs curl unzip tar ca-certificates libgl1 "$asound_pkg" libx11-6 libxcursor1 libxinerama1 libxext6 libxrandr2 libxi6 libwayland-client0 libwayland-cursor0 libwayland-egl1 libxkbcommon0 || true
            ;;
        dnf)
            $SUDO_CMD dnf install -y git git-lfs curl unzip tar ca-certificates alsa-lib libX11 libXcursor libXinerama libXrandr libXi libxkbcommon libwayland-client mesa-libGL || true
            ;;
        zypper)
            $SUDO_CMD zypper --non-interactive install -y git git-lfs curl unzip tar ca-certificates libasound2 libX11-6 libXcursor1 libXinerama1 libXrandr2 libXi6 libxkbcommon0 libwayland-client0 Mesa-libGL1 || true
            ;;
        apk)
            $SUDO_CMD apk add git git-lfs curl unzip tar ca-certificates alsa-lib libx11 libxcursor libxinerama libxrandr libxi libxkbcommon wayland mesa-gl || true
            ;;
        xbps)
            $SUDO_CMD xbps-install -Sy git git-lfs curl unzip tar ca-certificates alsa-lib libx11 libxcursor libxinerama libxrandr libXi libxkbcommon wayland || true
            ;;
        *)
            log_warn "Менеджер пакетов не распознан. Убедитесь, что графические библиотеки X11/Wayland и ALSA установлены."
            ;;
    esac
}

if [ ${#MISSING_CORE_TOOLS[@]} -gt 0 ] || [ "$CAN_SUDO" = true ]; then
    install_dependencies
fi

# Verify core tools after package install
for tool in curl unzip tar git; do
    if ! has_cmd "$tool"; then
        log_err "Критическая ошибка: утилита '$tool' не найдена и не была установлена."
        log_err "Пожалуйста, установите её через ваш менеджер пакетов и перезапустите установку."
        exit 1
    fi
done
log_ok "Базовые утилиты готовы к работе."

# --- 3. Determine Installation Path & Source ---
log_step "3. Подготовка директории файлов DroneFlames..."

REPO_URL="https://github.com/makkaX2/DroneFlames-PC-Port.git"
BRANCH="test"

IN_PLACE_INSTALL=false
CURRENT_DIR="$(pwd)"

if [ "${1:-}" = "--in-place" ] || { [ -f "$CURRENT_DIR/project.godot" ] && [ -f "$CURRENT_DIR/watermark.gd" ]; }; then
    IN_PLACE_INSTALL=true
    INSTALL_DIR="$CURRENT_DIR"
    log_info "Используется текущая рабочая директория (in-place): $INSTALL_DIR"
else
    XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    INSTALL_DIR="${XDG_DATA_HOME}/droneflames"
    log_info "Целевая директория установки: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

if [ "$IN_PLACE_INSTALL" = false ]; then
    # Skip huge Windows executables (DroneFlames.exe ~180MB) during git clone
    export GIT_LFS_SKIP_SMUDGE=1

    if [ -d "$INSTALL_DIR/.git" ]; then
        log_info "Обновление существующего репозитория в $INSTALL_DIR..."
        cd "$INSTALL_DIR"
        git fetch origin "$BRANCH" --depth 1 || true
        git checkout "$BRANCH" || true
        git reset --hard "origin/$BRANCH" || true
    else
        log_info "Клонирование репозитория (ветка $BRANCH)..."
        git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
else
    cd "$INSTALL_DIR"
fi

# --- 4. Resolve & Verify Assets (Git LFS) ---
log_step "4. Проверка и загрузка игровых ресурсов (assets.sparsepck)..."

SPARSE_FILE="$INSTALL_DIR/assets.sparsepck"
NEEDS_ASSET_DOWNLOAD=false

if [ ! -f "$SPARSE_FILE" ]; then
    NEEDS_ASSET_DOWNLOAD=true
else
    # Check if file is a Git LFS text pointer
    if head -n 2 "$SPARSE_FILE" | grep -q "git-lfs.github.com"; then
        log_info "assets.sparsepck является текстовым указателем Git LFS, скачиваем реальный файл..."
        NEEDS_ASSET_DOWNLOAD=true
    fi
fi

if [ "$NEEDS_ASSET_DOWNLOAD" = true ]; then
    if has_cmd git-lfs; then
        log_info "Попытка загрузки через git-lfs pull..."
        git lfs install 2>/dev/null || true
        (cd "$INSTALL_DIR" && git lfs pull --include="assets.sparsepck" --exclude="*.exe" 2>/dev/null || true)
    fi

    # Direct fallback via GitHub Media
    if [ ! -f "$SPARSE_FILE" ] || head -n 2 "$SPARSE_FILE" | grep -q "git-lfs.github.com"; then
        log_info "Прямая загрузка assets.sparsepck через curl fallback..."
        curl -fSL --retry 3 "https://media.githubusercontent.com/media/makkaX2/DroneFlames-PC-Port/${BRANCH}/assets.sparsepck" -o "$SPARSE_FILE"
    fi
fi

if [ -f "$SPARSE_FILE" ]; then
    MAGIC=$(head -c 4 "$SPARSE_FILE" 2>/dev/null || true)
    if [ "$MAGIC" = "GDPC" ]; then
        log_ok "Файл assets.sparsepck успешно проверен (GDPC сигнатура подтверждена)!"
    else
        log_warn "Сигнатура assets.sparsepck отличается от GDPC, но файл загружен (${SPARSE_FILE})."
    fi
else
    log_err "Не удалось загрузить assets.sparsepck!"
    exit 1
fi

# --- 5. Download & Setup Godot Linux Runtime Engine ---
log_step "5. Настройка нативного движка DroneFlames (Godot 4.7.2 Linux x86_64)..."

ENGINE_BIN="$INSTALL_DIR/DroneFlames.x86_64"
GODOT_ZIP_URL="https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"

ENGINE_ALREADY_VALID=false
if [ -f "$ENGINE_BIN" ] && [ -x "$ENGINE_BIN" ]; then
    if "$ENGINE_BIN" --version --headless >/dev/null 2>&1; then
        ENGINE_ALREADY_VALID=true
        log_ok "Движок DroneFlames.x86_64 уже установлен и готов к запуску."
    fi
fi

if [ "$ENGINE_ALREADY_VALID" = false ]; then
    log_info "Загрузка официального бинарника Godot 4.7.2 Linux..."
    TMP_ZIP="/tmp/godot_linux_x86_64.zip"
    TMP_EXTRACT="/tmp/godot_linux_extracted"
    rm -rf "$TMP_ZIP" "$TMP_EXTRACT"
    mkdir -p "$TMP_EXTRACT"

    curl -fL --retry 5 --retry-delay 2 --progress-bar -o "$TMP_ZIP" "$GODOT_ZIP_URL"
    log_info "Распаковка архива..."
    unzip -q -o "$TMP_ZIP" -d "$TMP_EXTRACT"

    EXTRACTED_BIN=$(find "$TMP_EXTRACT" -type f -name "Godot*" | head -n 1)
    if [ -n "$EXTRACTED_BIN" ]; then
        mv -f "$EXTRACTED_BIN" "$ENGINE_BIN"
        chmod +x "$ENGINE_BIN"
        log_ok "Бинарник успешно установлен в: $ENGINE_BIN"
    else
        log_err "Не удалось найти распакованный исполняемый файл Godot!"
        exit 1
    fi
    rm -rf "$TMP_ZIP" "$TMP_EXTRACT"
fi

# Run engine verification test
log_info "Тестирование запуска движка..."
TEST_OUTPUT=$("$ENGINE_BIN" --version --headless 2>&1 || true)
if [ $? -eq 0 ] || echo "$TEST_OUTPUT" | grep -qi "4.7"; then
    log_ok "Движок успешно отвечает: $TEST_OUTPUT"
else
    log_warn "Движок вернул предупреждение: $TEST_OUTPUT"
    if has_cmd ldd; then
        MISSING_LIBS=$(ldd "$ENGINE_BIN" 2>/dev/null | grep "not found" || true)
        if [ -n "$MISSING_LIBS" ]; then
            log_err "Обнаружены отсутствующие системные библиотеки:"
            echo "$MISSING_LIBS"
            log_warn "Установите недостающие пакеты через ваш менеджер пакетов."
        fi
    fi
fi

# --- 6. Create Universal Launcher Script ---
log_step "6. Создание универсального скрипта запуска (droneflames)..."

USER_BIN_DIR="${HOME}/.local/bin"
mkdir -p "$USER_BIN_DIR"

LAUNCHER_SCRIPT="$USER_BIN_DIR/droneflames"
LOCAL_LAUNCHER="$INSTALL_DIR/droneflames.sh"

cat << 'EOF' > "$LAUNCHER_SCRIPT"
#!/usr/bin/env bash
# ==============================================================================
# DroneFlames Reborn - Unified Linux Launcher
# ==============================================================================
set -e

GAME_DIR="__INSTALL_DIR__"
ENGINE_BIN="$GAME_DIR/DroneFlames.x86_64"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/droneflames"
mkdir -p "$STATE_DIR"
GAME_LOG="$STATE_DIR/game.log"

# Optimize audio latency for PulseAudio / PipeWire
export PULSE_PROP_media.role="game"
export PIPEWIRE_LATENCY="512/48000"

# Arguments handling
RUN_ARGS=()
if [ -n "$DRONEFLAMES_DRIVER" ]; then
    RUN_ARGS+=(--display-driver "$DRONEFLAMES_DRIVER")
fi

# Hyprland / Wayland checks
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland,x11}"
elif [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland,x11}"
fi

cd "$GAME_DIR"

if [ -t 1 ]; then
    echo "[DroneFlames] Запуск игры... (лог: $GAME_LOG)"
fi

# Run engine. If Wayland driver fails with display error, fallback to X11 (XWayland)
set +e
"$ENGINE_BIN" --path "$GAME_DIR" "${RUN_ARGS[@]}" "$@" 2>&1 | tee "$GAME_LOG"
EXIT_CODE="${PIPESTATUS[0]}"

if [ "$EXIT_CODE" -ne 0 ] && [ -z "$DRONEFLAMES_DRIVER" ] && ([ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]); then
    echo "[!] Обнаружена ошибка запуска под Wayland. Пробуем fallback через XWayland (--display-driver x11)..."
    "$ENGINE_BIN" --path "$GAME_DIR" --display-driver x11 "$@" 2>&1 | tee -a "$GAME_LOG"
    EXIT_CODE=$?
fi

exit "$EXIT_CODE"
EOF

sed -i "s|__INSTALL_DIR__|$INSTALL_DIR|g" "$LAUNCHER_SCRIPT"
chmod +x "$LAUNCHER_SCRIPT"
cp -f "$LAUNCHER_SCRIPT" "$LOCAL_LAUNCHER"
chmod +x "$LOCAL_LAUNCHER"

# Ensure ~/.local/bin is in PATH
PATH_ALREADY_SET=false
if echo "$PATH" | grep -q "$USER_BIN_DIR"; then
    PATH_ALREADY_SET=true
fi

if [ "$PATH_ALREADY_SET" = false ]; then
    for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$profile" ] && ! grep -q 'PATH=.*\.local/bin' "$profile"; then
            echo -e '\n# Added by DroneFlames Installer\nexport PATH="$HOME/.local/bin:$PATH"' >> "$profile"
            log_info "Добавлен ~/.local/bin в $profile"
        fi
    done
fi

log_ok "Скрипт запуска создан: $LAUNCHER_SCRIPT"

# --- 7. Desktop Integration (Hyprland, XFCE, GNOME, KDE) ---
log_step "7. Создание ярлыков, иконок и интеграция в меню приложений..."

# Icons setup
ICON_PNG="$INSTALL_DIR/icon.png"
ICON_SVG="$INSTALL_DIR/icon.svg"

HICOLOR_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
mkdir -p "$HICOLOR_DIR/256x256/apps" "$HICOLOR_DIR/scalable/apps" "${XDG_DATA_HOME:-$HOME/.local/share}/pixmaps"

if [ -f "$ICON_PNG" ]; then
    cp -f "$ICON_PNG" "$HICOLOR_DIR/256x256/apps/droneflames.png"
    cp -f "$ICON_PNG" "${XDG_DATA_HOME:-$HOME/.local/share}/pixmaps/droneflames.png"
fi

if [ -f "$ICON_SVG" ]; then
    cp -f "$ICON_SVG" "$HICOLOR_DIR/scalable/apps/droneflames.svg"
fi

# Application Menu Entry (.desktop)
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS_DIR"
DESKTOP_FILE="$APPS_DIR/droneflames.desktop"

cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Version=1.0
Name=DroneFlames
GenericName=Военно-стратегический симулятор
Comment=DroneFlames Reborn (Official Linux Port)
Exec=$LAUNCHER_SCRIPT %u
Icon=$INSTALL_DIR/icon.png
Path=$INSTALL_DIR
Terminal=false
Categories=Game;StrategyGame;Simulation;
Keywords=droneflames;game;strategy;war;drones;
StartupWMClass=DroneFlames
Actions=Wayland;X11;

[Desktop Action Wayland]
Name=Запуск в нативном Wayland
Exec=env DRONEFLAMES_DRIVER=wayland $LAUNCHER_SCRIPT

[Desktop Action X11]
Name=Запуск через X11 / XWayland
Exec=env DRONEFLAMES_DRIVER=x11 $LAUNCHER_SCRIPT
EOF

chmod +x "$DESKTOP_FILE"
log_ok "Файл приложения создан: $DESKTOP_FILE"

# Desktop Shortcut (XFCE, KDE, Mint, etc.)
DESKTOP_DIR=""
if has_cmd xdg-user-dir; then
    DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null || true)
fi
if [ -z "$DESKTOP_DIR" ] || [ ! -d "$DESKTOP_DIR" ]; then
    if [ -d "$HOME/Desktop" ]; then
        DESKTOP_DIR="$HOME/Desktop"
    elif [ -d "$HOME/Рабочий стол" ]; then
        DESKTOP_DIR="$HOME/Рабочий стол"
    fi
fi

if [ -n "$DESKTOP_DIR" ] && [ -d "$DESKTOP_DIR" ]; then
    SHORTCUT_PATH="$DESKTOP_DIR/droneflames.desktop"
    cp -f "$DESKTOP_FILE" "$SHORTCUT_PATH"
    chmod +x "$SHORTCUT_PATH"
    # Mark trusted in GNOME / XFCE
    if has_cmd gio; then
        gio set "$SHORTCUT_PATH" metadata::trusted true 2>/dev/null || true
    fi
    log_ok "Ярлык на рабочем столе создан: $SHORTCUT_PATH"
fi

# Update desktop and icon databases
if has_cmd update-desktop-database; then
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
fi
if has_cmd gtk-update-icon-cache; then
    gtk-update-icon-cache -f -t "$HICOLOR_DIR" 2>/dev/null || true
fi
if has_cmd kbuildsycoca5; then
    kbuildsycoca5 2>/dev/null || true
elif has_cmd kbuildsycoca6; then
    kbuildsycoca6 2>/dev/null || true
fi

# --- 8. Generate Clean Uninstaller ---
log_step "8. Создание скрипта удаления (uninstall.sh)..."

UNINSTALL_SCRIPT="$INSTALL_DIR/uninstall.sh"
cat << EOF > "$UNINSTALL_SCRIPT"
#!/usr/bin/env bash
echo "=== Удаление DroneFlames Reborn ==="
rm -f "$LAUNCHER_SCRIPT"
rm -f "$DESKTOP_FILE"
rm -f "$HOME/Desktop/droneflames.desktop" 2>/dev/null || true
rm -f "$HOME/Рабочий стол/droneflames.desktop" 2>/dev/null || true
rm -f "$HICOLOR_DIR/256x256/apps/droneflames.png"
rm -f "$HICOLOR_DIR/scalable/apps/droneflames.svg"
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/pixmaps/droneflames.png"
echo "Ярлыки и исполняемые файлы удалены."
read -p "Удалить саму директорию игры ($INSTALL_DIR)? [y/N]: " ans
if [ "\$ans" = "y" ] || [ "\$ans" = "Y" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Директория игры удалена."
fi
echo "Удаление завершено!"
EOF
chmod +x "$UNINSTALL_SCRIPT"

# --- 9. Final Summary ---
cp -f "$LOG_FILE" "$TMP_LOG" 2>/dev/null || true
cp -f "$LOG_FILE" "$INSTALL_DIR/install.log" 2>/dev/null || true

echo ""
echo "=================================================================="
echo -e "${C_BOLD}${C_GREEN}    УСТАНОВКА DRONEFLAMES УСПЕШНО ЗАВЕРШЕНА! 🎉${C_RESET}"
echo "=================================================================="
echo -e " Дистрибутив:       ${C_CYAN}${OS_NAME}${C_RESET}"
echo -e " Окружение/WM:      ${C_CYAN}${DETECTED_WM}${C_RESET}"
echo -e " Папка игры:        ${C_YELLOW}${INSTALL_DIR}${C_RESET}"
echo -e " Бинарник движка:   ${C_YELLOW}${ENGINE_BIN}${C_RESET}"
echo -e " Команда запуска:   ${C_GREEN}droneflames${C_RESET} (или ${LAUNCHER_SCRIPT})"
echo "------------------------------------------------------------------"
echo -e "${C_BOLD}Способы запуска:${C_RESET}"
echo -e " 1. ${C_CYAN}Меню приложений:${C_RESET} найдите 'DroneFlames' в Rofi, Wofi, Whisker Menu (XFCE), GNOME или KDE"
[ -n "$DESKTOP_DIR" ] && echo -e " 2. ${C_CYAN}С рабочего стола:${C_RESET} дважды кликните по ярлыку 'DroneFlames'"
echo -e " 3. ${C_CYAN}Из терминала:${C_RESET} просто введите:  ${C_GREEN}droneflames${C_RESET}"
if [ "$IS_HYPRLAND" = true ]; then
    echo "------------------------------------------------------------------"
    echo -e "${C_BOLD}Совет для пользователей Hyprland:${C_RESET}"
    echo -e " Игра доступна в вашем лаунчере (rofi / wofi / fuzzel)"
    echo -e " или добавьте бинд в ~/.config/hypr/hyprland.conf:"
    echo -e "   ${C_GREEN}bind = \$mainMod, D, exec, droneflames${C_RESET}"
fi
echo "------------------------------------------------------------------"
echo -e " Лог установки сохранен в:  ${C_BOLD}${LOG_FILE}${C_RESET}"
echo -e " Лог работы игры пишется в: ${C_BOLD}${HOME}/.local/state/droneflames/game.log${C_RESET}"
echo "=================================================================="
exit 0
