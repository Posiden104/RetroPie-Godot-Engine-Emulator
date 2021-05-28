#!/usr/bin/env bash

# This file is part of The RetroPie Project
#
# The RetroPie Project is the legal property of its developers, whose names are
# too numerous to list here. Please refer to the COPYRIGHT.md file distributed with this source.
#
# See the LICENSE.md file at the top-level directory of this distribution and
# at https://raw.githubusercontent.com/RetroPie/RetroPie-Setup/master/LICENSE.md
#

# Scriptmodule variables ############################

rp_module_id="godot-engine"
rp_module_desc="Godot Engine (https://godotengine.org/)."
rp_module_help="Game extensions: .pck .zip."
rp_module_help+="\n\nCopy your games to $romdir/$rp_module_id."
rp_module_help+="\n\nAuthor: hiulit (https://github.com/hiulit)."
rp_module_help+="\n\nRepository: https://github.com/hiulit/RetroPie-Godot-Game-Engine-Emulator"
rp_module_help+="\n\nLicenses:"
rp_module_help+="\n- Source code, Godot Engine and FRT: MIT."
rp_module_help+="\n- Godot logo: CC BY 3.0."
rp_module_help+="\n- Godot pixel logo: CC BY-NC-SA 4.0."
rp_module_licence="MIT https://raw.githubusercontent.com/hiulit/RetroPie-Godot-Game-Engine-Emulator/master/LICENSE"
rp_module_section="opt"
rp_module_flags="x86 x86_64 aarch64 rpi1 rpi2 rpi3 rpi4"


# Global variables ##################################

RP_MODULE_ID="$rp_module_id"
TMP_DIR="$__tmpdir/$RP_MODULE_ID"
SETTINGS_DIR="$romdir/$RP_MODULE_ID/settings"
CONFIGS_DIR="/opt/retropie/configs/$RP_MODULE_ID"

SCRIPT_VERSION="1.8.0"

GODOT_VERSIONS=(
    "2.1.6"
    "3.0.6"
    "3.1.2"
    "3.3.2"
)

AUDIO_DRIVERS=(
    "ALSA"
    "PulseAudio"
)
AUDIO_DRIVER="ALSA"

VIDEO_DRIVERS=(
    "GLES2"
    "GLES3"
)
VIDEO_DRIVER="GLES2"

FRT_KEYBOARD=""
FRT_DRM_KMS=""

RESOLUTION=""

ES_THEMES_DIR="/etc/emulationstation/themes"
ES_DEFAULT_THEME="carbon"
GODOT_THEMES=(
    "$ES_DEFAULT_THEME"
    "pixel"
)

OVERRIDE_CFG_DEFAULTS_FILE="$SETTINGS_DIR/.override-defaults.cfg"
OVERRIDE_CFG_FILE="$romdir/$RP_MODULE_ID/override.cfg" # This file must be in the same folder as the games.
SETTINGS_CFG_DEFAULTS_FILE="$SETTINGS_DIR/.godot-engine-settings-defaults.cfg"
SETTINGS_CFG_FILE="$SETTINGS_DIR/godot-engine-settings.cfg"


# Flags ###############################

X11_FLAG="false"

if [[ -n "$(echo $DISPLAY)" ]]; then
    X11_FLAG="true"
fi


# Configuration dialog variables ####################

readonly DIALOG_OK=0
readonly DIALOG_CANCEL=1
readonly DIALOG_EXTRA=3
readonly DIALOG_ESC=255
readonly DIALOG_BACKTITLE="Godot Engine Configuration (v$SCRIPT_VERSION)"
readonly DIALOG_HEIGHT=8
readonly DIALOG_WIDTH=60

DIALOG_OPTIONS=()

# Configuration dialog functions ####################

function _main_config_dialog() {
    local i=1
    local options=()
    local commands=()
    local cmd
    local choice

    for option in "${DIALOG_OPTIONS[@]}"; do
        case "$option" in
            "virtual_keyboard")
                if [[ -n "$FRT_KEYBOARD" ]]; then
                    options+=("$i" "GPIO/Virtual keyboard ($FRT_KEYBOARD)")
                else
                    options+=("$i" "GPIO/Virtual keyboard")
                fi
                commands+=("$i" "_gpio_virtual_keyboard_dialog")
                ;;
            "drm_kms_driver")
                if [[ -n "$FRT_DRM_KMS" ]]; then
                    options+=("$i" "DRM/KMS driver ("$(basename "$FRT_DRM_KMS")")")
                else
                    options+=("$i" "DRM/KMS driver")
                fi
                commands+=("$i" "_drm_kms_driver_dialog")
                ;;
            "audio_driver")
                options+=("$i" "Audio driver ("$AUDIO_DRIVER")")
                commands+=("$i" "_audio_driver_dialog")
                ;;
            "video_driver")
                options+=("$i" "Video driver ("$VIDEO_DRIVER")")
                commands+=("$i" "_video_driver_dialog")
                ;;
            "edit_override")
                options+=("$i" "Edit \"override.cfg\"")
                commands+=("$i" "_edit_override_cfg_dialog")
                ;;
            "install_themes")
                options+=("$i" "Install themes")
                commands+=("$i" "_install_themes_dialog")
                ;;
        esac
        ((i++))
    done

    cmd=(dialog \
            --backtitle "$DIALOG_BACKTITLE" \
            --title "" \
            --ok-label "OK" \
            --cancel-label "Back" \
            --menu "Choose an option." \
            15 "$DIALOG_WIDTH" 15)
    choice="$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)"
    local return_value="$?"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        if [[ -n "$choice" ]]; then
            eval "${commands[choice*2-1]}"
        fi
    fi
}


function _gpio_virtual_keyboard_dialog() {
    local i=1
    local options=()
    local cmd
    local choice
    local message

    options+=("$i" "None")

    while IFS= read -r line; do
        ((i++))
        line="$(echo "$line" | sed -e 's/^"//' -e 's/"$//')" # Remove leading and trailing double quotes.
        options+=("$i" "$line")
    done < <(cat "/proc/bus/input/devices" | grep "N: Name" | cut -d= -f2)

    cmd=(dialog \
        --backtitle "$DIALOG_BACKTITLE" \
        --title "GPIO/Virtual keyboard" \
        --ok-label "OK" \
        --cancel-label "Back" \
        --menu "Choose an option." \
        15 "$DIALOG_WIDTH" 15)

    choice="$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        if [[ -n "$choice" ]]; then
            if [[ "$FRT_KEYBOARD" == "None" ]]; then
                FRT_KEYBOARD=""
                message="The GPIO/Virtual keyboard has been unset."
            else
                FRT_KEYBOARD="${options[choice*2-1]}"
                message="The GPIO/Virtual keyboard ($FRT_KEYBOARD) has been set."
            fi

            _set_config "gpio_virtual_keyboard" "$FRT_KEYBOARD"

            configure_godot-engine

            dialog \
                --backtitle "$DIALOG_BACKTITLE" \
                --title "" \
                --ok-label "OK" \
                --msgbox "$message" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty

            _main_config_dialog
        else
            # If there is no choice that means the user selected "Back".
            _main_config_dialog
        fi
    elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
        _main_config_dialog
    elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
        _main_config_dialog
    fi
}


function _audio_driver_dialog() {
    local i=1
    local options=()
    local cmd
    local choice

    for audio_driver in "${AUDIO_DRIVERS[@]}"; do
        options+=("$i" "$audio_driver")
        ((i++))
    done

    cmd=(dialog \
        --backtitle "$DIALOG_BACKTITLE" \
        --title "Audio driver" \
        --ok-label "OK" \
        --cancel-label "Back" \
        --menu "Choose an option." \
        15 "$DIALOG_WIDTH" 15)

    choice="$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        if [[ -n "$choice" ]]; then
            AUDIO_DRIVER="${options[choice*2-1]}"

            _set_config "audio_driver" "$AUDIO_DRIVER"

            configure_godot-engine

            dialog \
                --backtitle "$DIALOG_BACKTITLE" \
                --title "" \
                --ok-label "OK" \
                --msgbox "The audio driver ($AUDIO_DRIVER) has been set." "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty

            _main_config_dialog
        else
            # If there is no choice that means the user selected "Back".
            _main_config_dialog
        fi
    elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
        _main_config_dialog
    elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
        _main_config_dialog
    fi
}


function _video_driver_dialog() {
    local i=1
    local options=()
    local cmd
    local choice

    for video_driver in "${VIDEO_DRIVERS[@]}"; do
        options+=("$i" "$video_driver")
        ((i++))
    done

    cmd=(dialog \
        --backtitle "$DIALOG_BACKTITLE" \
        --title "Video driver" \
        --ok-label "OK" \
        --cancel-label "Back" \
        --menu "Choose an option." \
        15 "$DIALOG_WIDTH" 15)

    choice="$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        if [[ -n "$choice" ]]; then
            VIDEO_DRIVER="${options[choice*2-1]}"

            _set_config "video_driver" "$VIDEO_DRIVER"

            configure_godot-engine

            dialog \
                --backtitle "$DIALOG_BACKTITLE" \
                --title "" \
                --ok-label "OK" \
                --msgbox "The video driver ($VIDEO_DRIVER) has been set." "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty

            _main_config_dialog
        else
            # If there is no choice that means the user selected "Back".
            _main_config_dialog
        fi
    elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
        _main_config_dialog
    elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
        _main_config_dialog
    fi
}


function _drm_kms_driver_dialog() {
    local i=1
    local options=()
    local cmd
    local choice
    local message

    options+=("$i" "None")

    for file in "/dev/dri/"*; do
        if [[ ! -d "$file" ]]; then
            ((i++))
            options+=("$i" "$(basename "$file")")
        fi
    done

    cmd=(dialog \
        --backtitle "$DIALOG_BACKTITLE" \
        --title "DRM/KMS driver" \
        --ok-label "OK" \
        --cancel-label "Back" \
        --menu "Choose an option." \
        15 "$DIALOG_WIDTH" 15)

    choice="$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        if [[ -n "$choice" ]]; then
            if [[ "${options[choice*2-1]}" == "None" ]]; then
                FRT_DRM_KMS=""
                message="The DRM/KMS driver has been unset."
            else
                FRT_DRM_KMS="/dev/dri/${options[choice*2-1]}"
                message="The DRM/KMS driver ("$(basename "$FRT_DRM_KMS")") has been set."
            fi

            _set_config "drm_kms_driver" "$FRT_DRM_KMS"

            configure_godot-engine

            dialog \
                --backtitle "$DIALOG_BACKTITLE" \
                --title "" \
                --ok-label "OK" \
                --msgbox "$message" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty

            _main_config_dialog
        else
            # If there is no choice that means the user selected "Back".
            _main_config_dialog
        fi
    elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
        _main_config_dialog
    elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
        _main_config_dialog
    fi
}


function _edit_override_cfg_dialog() {
    local override_cfg

    override_cfg="$(dialog \
                    --backtitle "$DIALOG_BACKTITLE" \
                    --title "Edit \"override.cfg\"" \
                    --ok-label "Save" \
                    --cancel-label "Back" \
                    --extra-button \
                    --extra-label "Reset" \
                    --editbox "$OVERRIDE_CFG_FILE" 15 "$DIALOG_WIDTH" 2>&1 >/dev/tty)"
    local return_value="$?"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        echo "$override_cfg" > "$OVERRIDE_CFG_FILE"

        dialog \
            --backtitle "$DIALOG_BACKTITLE" \
            --title "" \
            --ok-label "OK" \
            --msgbox "\"override.cfg\" updated successfully!" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty

        _main_config_dialog
    elif [[ "$return_value" -eq "$DIALOG_EXTRA" ]]; then
        dialog \
            --backtitle "$DIALOG_BACKTITLE" \
            --title "" \
            --yesno "Would you like to reset \"override.cfg\" to the default values?" "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty
        local return_value="$?"

        if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
            cat "$OVERRIDE_CFG_DEFAULTS_FILE" > "$OVERRIDE_CFG_FILE"

            dialog \
                --backtitle "$DIALOG_BACKTITLE" \
                --title "" \
                --ok-label "OK" \
                --msgbox "\"override.cfg\" has been reset to the default values." "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty

            _edit_override_cfg_dialog
        elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
            _edit_override_cfg_dialog
        elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
            _edit_override_cfg_dialog
        fi
    elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
        _main_config_dialog
    elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
        _main_config_dialog
    fi
}


function _install_themes_dialog() {
    local i=1
    local options=()
    local themes=()
    local cmd
    local choice

    for theme in "${GODOT_THEMES[@]}"; do
        themes+=("$theme")
        if [[ -d "$ES_THEMES_DIR/$theme/godot-engine" ]]; then
            if [[ "$theme" == "$ES_DEFAULT_THEME" ]]; then
                options+=("$i" "Update $theme (installed)")
            else
                options+=("$i" "Update or uninstall $theme (installed)")
            fi
        else
            options+=("$i" "Install $theme")
        fi
        ((i++))
    done

    cmd=(dialog \
        --backtitle "$DIALOG_BACKTITLE" \
        --title "Install themes" \
        --ok-label "OK" \
        --cancel-label "Back" \
        --menu "Choose an option." \
        15 "$DIALOG_WIDTH" 15)

    choice="$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        if [[ -n "$choice" ]]; then
            local theme="${themes[choice-1]}"

            if [[ "${options[choice*2-1]}" =~ "(installed)" ]] ; then
                _update_uninstall_themes_dialog "$theme"
            else
                if [[ ! -d "$ES_THEMES_DIR/$theme" ]]; then
                    dialog \
                        --backtitle "$DIALOG_BACKTITLE" \
                        --title "" \
                        --ok-label "OK" \
                        --msgbox "The '$theme' theme must be installed on EmulationStation before installing the 'godot-engine' system in it." "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty
                else
                    echo "Installing $theme theme..."
                    action="installed"
                    _install_update_theme "$theme"

                    dialog \
                        --backtitle "$DIALOG_BACKTITLE" \
                        --title "" \
                        --ok-label "OK" \
                        --msgbox "The $theme theme has been installed." "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty
                fi

                _install_themes_dialog
            fi
        else
            # If there is no choice that means the user selected "Back".
            _main_config_dialog
        fi
    elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
        _main_config_dialog
    elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
        _main_config_dialog
    fi
}


function _update_uninstall_themes_dialog() {
    local theme="$1"
    local options=()
    local cmd
    local choice

    if [[ "$theme" == "$ES_DEFAULT_THEME" ]]; then
        _install_update_theme "$theme"
        _install_themes_dialog
    fi

    options=(
        1 "Update $theme"
        2 "Uninstall $theme"
    )

    cmd=(dialog \
        --backtitle "$DIALOG_BACKTITLE" \
        --title "Update or uninstall theme" \
        --ok-label "OK" \
        --cancel-label "Back" \
        --menu "Choose an option." \
        15 "$DIALOG_WIDTH" 15)

    choice="$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)"

    if [[ "$return_value" -eq "$DIALOG_OK" ]]; then
        if [[ -n "$choice" ]]; then
            local action

            case "$choice" in
                1)
                    echo "Updating $theme theme..."
                    action="updated"
                    _install_update_theme "$theme"
                    ;;
                2)
                    action="uninstalled"
                    _uninstall_theme "$theme"
                    ;;
            esac

            dialog \
                --backtitle "$DIALOG_BACKTITLE" \
                --title "" \
                --ok-label "OK" \
                --msgbox "The $theme theme has been $action." "$DIALOG_HEIGHT" "$DIALOG_WIDTH" 2>&1 >/dev/tty

            _install_themes_dialog
        else
            # If there is no choice that means the user selected "Back".
            _install_themes_dialog
        fi
    elif [[ "$return_value" -eq "$DIALOG_CANCEL" ]]; then
        _install_themes_dialog
    elif [[ "$return_value" -eq "$DIALOG_ESC" ]]; then
        _install_themes_dialog
    fi
}


# Helper functions ##################################

function _set_config() {
    sed -i "s|^\($1\s*=\s*\).*|\1\"$2\"|" "$SETTINGS_CFG_FILE"
}


function _get_config() {
    local config
    config="$(grep -Po "(?<=^$1 = ).*" "$SETTINGS_CFG_FILE")"
    config="${config%\"}"
    config="${config#\"}"
    echo "$config"
}


function _get_available_screen_resolution() {
    if [[ "$X11_FLAG" == "true" ]]; then
        local available_screen_resolution
        local current_screen_width
        local current_screen_height
        available_screen_resolution=$(xprop -root | grep -e 'NET_WORKAREA(CARDINAL)') # get available screen dimensions.
        available_screen_resolution=${available_screen_resolution##*=} # strip off beginning text.
        current_screen_width=$(echo $available_screen_resolution | cut -d ',' -f3 | sed -e 's/^[ \t]*//')
        current_screen_height=$(echo $available_screen_resolution | cut -d ',' -f4 | sed -e 's/^[ \t]*//')
        available_screen_resolution="${current_screen_width}x${current_screen_height}"
        echo "$available_screen_resolution"
    else
        local available_screen_resolution
        available_screen_resolution="$(fbset -s | grep -e 'mode ' | cut -d'"' -f2)"
        echo "$available_screen_resolution"
    fi
}


function _install_update_theme() {
    local theme="$1"
    local tmp_dir="$TMP_DIR/themes"
    mkUserDir "$tmp_dir"
    rmDirExists "$ES_THEMES_DIR/$theme/godot-engine"
    gitPullOrClone "$tmp_dir" "https://github.com/hiulit/RetroPie-Godot-Engine-Emulator"
    cp -r "$tmp_dir/themes/$theme/godot-engine" "$ES_THEMES_DIR/$theme"
    rmDirExists "$tmp_dir"
}


function _uninstall_theme() {
    local theme="$1"
    rmDirExists "$ES_THEMES_DIR/$theme/godot-engine"
}


# Scriptmodule functions ############################

function sources_godot-engine() {
    local url="https://github.com/hiulit/RetroPie-Godot-Game-Engine-Emulator/releases/download/v${SCRIPT_VERSION}"

    for version in "${GODOT_VERSIONS[@]}"; do
        if isPlatform "x86"; then
            downloadAndExtract "${url}/godot_${version}_x11_32.zip" "$md_build"
        elif isPlatform "x86_64"; then
            downloadAndExtract "${url}/godot_${version}_x11_64.zip" "$md_build"
        elif isPlatform "aarch64"; then
            downloadAndExtract "${url}/frt_${version}_arm64.zip" "$md_build"
        elif isPlatform "rpi1"; then
            downloadAndExtract "${url}/frt_${version}_pi1.zip" "$md_build"
        elif isPlatform "rpi2" || isPlatform "rpi3" || isPlatform "rpi4"; then
            downloadAndExtract "${url}/frt_${version}_pi2.zip" "$md_build"
        fi
    done
}


function install_godot-engine() {
    if [[ -d "$md_build" ]]; then
        md_ret_files=($(ls "$md_build"))
    else
        echo "ERROR: Can't install '$RP_MODULE_ID'." >&2
        echo "There must have been a problem downloading the sources." >&2
        exit 1
    fi

    # Install the "godot-engine" system for the default EmulationStation theme.
    echo
    echo "Installing the '$RP_MODULE_ID' system for the '$ES_DEFAULT_THEME' theme..."
    echo
    _install_update_theme "$ES_DEFAULT_THEME"

    # Create the "godot-engine" ROM folder.
    mkRomDir "$RP_MODULE_ID"
    
    if [[ -d "$TMP_DIR" ]]; then
        # Create the "settings" folder inside the "godot-engine" folder.
        mkUserDir "$SETTINGS_DIR"

        # Install the "default settings" files.
        cp "$TMP_DIR/override.cfg" "$OVERRIDE_CFG_DEFAULTS_FILE" && chown -R "$user:$user" "$OVERRIDE_CFG_DEFAULTS_FILE"
        cp "$TMP_DIR/godot-engine-settings.cfg" "$SETTINGS_CFG_DEFAULTS_FILE" && chown -R "$user:$user" "$SETTINGS_CFG_DEFAULTS_FILE"

        # Install the "user settings" files.
        if [[ ! -f "$OVERRIDE_CFG_FILE" ]]; then
            cp "$TMP_DIR/override.cfg" "$OVERRIDE_CFG_FILE" && chown -R "$user:$user" "$OVERRIDE_CFG_FILE"
        fi
        if [[ ! -f "$SETTINGS_CFG_FILE" ]]; then
            cp "$TMP_DIR/godot-engine-settings.cfg" "$SETTINGS_CFG_FILE" && chown -R "$user:$user" "$SETTINGS_CFG_FILE"
        fi
    else
        echo "ERROR: Can't install the settings files for '$RP_MODULE_ID'." >&2
        echo "There must have been a problem when installing/updating the setup script." >&2
        exit 1
    fi
}


function remove_godot-engine() {
    # Remove the "godot-engine" configs folder.
    rmDirExists "$CONFIGS_DIR"
    # Remove the "godot-engine" system for the default EmulationStation theme.
    _uninstall_theme "$ES_DEFAULT_THEME"
    # Remove the "settings" folder in "godot-engine" ROM folder.
    rmDirExists "$SETTINGS_DIR"
    # Remove the "override.cfg" file in "godot-engine" ROM folder.
    rm "$OVERRIDE_CFG_FILE"
    # Remove the "godot-engine" temporary folder.
    rmDirExists "$TMP_DIR"
}


function configure_godot-engine() {
    local bin_file_tmp
    local bin_files=()
    local bin_files_tmp=()
    local default
    local index
    local version
    local audio_driver_string
    local main_pack_string
    local resolution_string
    local video_driver_string

    if [[ -d "$md_inst" ]]; then
        # Get all the files in the installation folder.
        bin_files_tmp=($(ls "$md_inst"))

        # Remove the extra "retropie.pkg" file and create the final array with the needed files.
        for bin_file_tmp in "${bin_files_tmp[@]}"; do
            if [[ "$bin_file_tmp" != "retropie.pkg" ]]; then
                bin_files+=("$bin_file_tmp")
            fi
        done
    else
        echo "ERROR: Can't configure '$RP_MODULE_ID'." >&2
        echo "There must have been a problem installing the binaries." >&2
        exit 1
    fi

    # Remove the file that contains all the configurations for the different Godot "emulators".
    # It will be created from scratch when adding the emulators in the "addEmulator" functions below.
    [[ -f "$CONFIGS_DIR/emulators.cfg" ]] && rm "$CONFIGS_DIR/emulators.cfg"

    RESOLUTION="$(_get_available_screen_resolution)"

    for index in "${!bin_files[@]}"; do
        default=0
        [[ "$index" -eq "${#bin_files[@]}-1" ]] && default=1 # Default to the last item (greater version) in "bin_files".
        
        # Get the version from the file name.
        version="${bin_files[$index]}"
        # Cut between "_".
        version="$(echo $version | cut -d'_' -f 2)"

        if [[ "$version" == "2.1.6" ]]; then
            audio_driver_string="-ad"
            main_pack_string="-main_pack"
            resolution_string="-r"
            video_driver_string="-vd"
        else
            audio_driver_string="--audio-driver"
            main_pack_string="--main-pack"
            resolution_string="--resolution"
            video_driver_string="--video-driver"
        fi

        if isPlatform "x86" || isPlatform "x86_64"; then
            addEmulator "$default" "$md_id-$version" "$RP_MODULE_ID" "$md_inst/${bin_files[$index]} $main_pack_string %ROM% $resolution_string $RESOLUTION $audio_driver_string $AUDIO_DRIVER $video_driver_string $VIDEO_DRIVER"
        else
            addEmulator "$default" "$md_id-$version" "$RP_MODULE_ID" "FRT_X11_UNDECORATED=$X11_FLAG FRT_KEYBOARD_ID='$FRT_KEYBOARD' FRT_KMSDRM_DEVICE='$FRT_DRM_KMS' $md_inst/${bin_files[$index]} $main_pack_string %ROM% $resolution_string $RESOLUTION $audio_driver_string $AUDIO_DRIVER $video_driver_string $VIDEO_DRIVER --frt exit_on_shiftenter=true"
        fi
    done

    addSystem "$RP_MODULE_ID" "Godot Engine" ".pck .zip"
}

function gui_godot-engine() {
    # Reset the dialog options.
    DIALOG_OPTIONS=()

    # Add the options only available for FRT.
    if ! isPlatform "x86" || ! isPlatform "x86_64"; then
        DIALOG_OPTIONS+=(
            "virtual_keyboard"
        )

        FRT_KEYBOARD_ID="$(_get_config "gpio_virtual_keyboard")"

        if [[ -d "/dev/dri" ]]; then
            DIALOG_OPTIONS+=(
                "kms_drm_driver"
            )

            FRT_KMSDRM_DEVICE="$(_get_config "kms_drm_driver")"
        fi
    fi

    # Add the options available for all the systems.
    DIALOG_OPTIONS+=(
        "audio_driver"
        "video_driver"
        "edit_override"
        "install_themes"
    )

    AUDIO_DRIVER="$(_get_config "audio_driver")"
    VIDEO_DRIVER="$(_get_config "video_driver")"

    _main_config_dialog
}
