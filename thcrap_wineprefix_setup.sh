#!/bin/bash

# Wineprefix setup script for thcrap - https://github.com/thpatch/thcrap
# This script is intended to supplement/replace thcrap's install_dotnet480.sh, creating a wineprefix automatically and ensuring the presence of everything needed to run.
# It assumes Wine 9.0 and the presence of winetricks. This may not even be necessary for Wine 10.0, but I can't test that right now. Let me know.

# Check if winetricks is installed
if ! command -v winetricks &> /dev/null; then
    echo -e "\
==ERROR: Winetricks could not be found.==
==Please install it first.==\n\
https://github.com/Winetricks/winetricks"
    exit 1
fi

# Check if wine is installed
if ! command -v wine &> /dev/null; then
    echo -e "\
==ERROR: Wine could not be found. You... Might be lost.==\n\
==Hey, happens to the best of us.==\n\
https://wiki.winehq.org/Download"
    exit 1
fi

# Ask the user where to put the wineprefix and what to call it
echo -e "Where do you keep your wineprefixes, usually? (If you don't know, then the default is fine; we put it where winetricks can see it.)"
read -rei "$HOME/.local/share/wineprefixes" WINEPREFIX_DIR
echo -e "What do you want to call the wineprefix? (If you don't know, just 'thcrap' should be fine.)"
read -rei "thcrap" WINEPREFIX_NAME

# i have a path; i have a folder!
export WINEPREFIX="$WINEPREFIX_DIR/$WINEPREFIX_NAME"
# uh - folder path!

# i should not be allowed around computers

# Handle an already-existing wineprefix
if [ -d "$WINEPREFIX_DIR/$WINEPREFIX_NAME" ]; then
    # Initialize PREFIXIS32BIT to false
    PREFIXIS32BIT=false
    # Check if the existing wineprefix is a 32-bit prefix by looking in system.reg
    if grep -q "arch=win32" "$WINEPREFIX_DIR/$WINEPREFIX_NAME/system.reg"; then PREFIXIS32BIT=true; fi
    echo -e "==WARNING: A wineprefix already exists at $WINEPREFIX.=="
    if $PREFIXIS32BIT; then # give a nice warning
        echo -e "==It appears to be a 32-bit prefix. We can use it if you'd like, but dirty-installing over an existing prefix may cause other, funnier problems.=="
    else # give a *less nice* warning
        echo -e "==!!This wineprefix appears to be 64-bit!!==\n==We can try to use it if you'd like, but unless Winetricks **finally works properly with 64-bit prefixes in $(date +%Y),** it is unlikely that this script will fix it!!=="
    fi
    echo -e "==On the other hand, there's no guarantee that nuking the prefix WON'T take your saves/scores/replay data with it!==\n==It may be worth making a backup.==\n"
    echo -e "Wipe prefix? (y/n) [n]:"
    read -r DELETE_WINEPREFIX
    DELETE_WINEPREFIX=${DELETE_WINEPREFIX:-n}
    if [[ "$DELETE_WINEPREFIX" =~ ^[Yy]$ ]]; then
        rm -rf "$WINEPREFIX"
        echo "--NOTE-- Deleting $WINEPREFIX and starting anew."
    elif [[ "$DELETE_WINEPREFIX" =~ ^[Nn]$ ]]; then
        echo "--NOTE-- Keeping $WINEPREFIX and dirty-installing over it. Godspeed."
        if ! $PREFIXIS32BIT; then echo -e "You poor soul."; fi
    else
        echo -e "--NOTE-- Invalid input, quitting..."
        exit 125
    fi
fi

function winepfx_init(){
	echo -e "--NOTE--\nInitializing wineprefix, setting Windows version to Windows 7.\n--------"
    WINEARCH="win32" wine winecfg -v win7
	wineserver -w
    export SYSTEM32="$WINEPREFIX/drive_c/windows/system32"
}

# Install vcrun2019 (good practice but optional)
function vcrun2019(){
	echo -e "--NOTE--\n\
As a matter of good practice, we're going to install Visual C++ Runtime and Corefonts.\n\
Corefonts installation may take a while, and errors related to it can typically be ignored.\n\
We can skip this step, just hit \"n\" within 5 seonds.\n\
--------"
	read -rt 5 -n 1 INSTALL_VCRUN2019
    if [[ "$INSTALL_VCRUN2019" =~ ^[Nn]$ ]]; then
        echo "--NOTE--Skipping vcrun2019 installation."
        return 1
    else
	winetricks -q corefonts vcrun2019
    wineserver -w
    fi
    if ! [ -f "$SYSTEM32/msvcp140.dll" ]; then return 2; else return 0; fi
}

function dotnet48(){
	echo -e "--NOTE--\nNow installing dotnet48.\n\
==Watch this installation process, and this terminal window, like a *hawk*, beacuse this tends to break in messy, complex ways.==\n\
==See https://github.com/Winetricks/winetricks/blob/e73c4d8f71801fe842c0276b603d9c8024d6d957/src/winetricks#L8627 ==\n\
Continuing automatically in 5 seconds...\n--------"
	read -rt 5
	winetricks dotnet48
    wineserver -w
    if ! [ -f "$SYSTEM32/mscoree.dll" ]; then return 1; else return 0; fi
}

function d3dcompiler_47(){
    echo "--NOTE-- Installing d3dcompiler_47."
    winetricks -q d3dcompiler_47
    wineserver -w
    if ! [ -f "$SYSTEM32/d3dcompiler_47.dll" ]; then return 1; else return 0; fi
}

winepfx_init
vcrun_status=$?
case $vcrun_status in
    0)
        echo "--NOTE-- vcrun2019 installed successfully."
        ;;
    1)
        echo "--NOTE-- vcrun2019 installation skipped."
        ;;
    2)
        echo -e "\
==ERROR: vcrun2019 installation encountered an unexpected issue.==\n\
==Please check the logs above for more details.=="
        exit 1
        ;;
    *)
        echo -e "\
==ERROR: vcrun2019 returned an unhandled value.==\n\
==well that's.... fuckin weird. Have a look at that?=="
        exit 2
        ;;
esac

dotnet48
dotnet_status=$?

if [ $dotnet_status -ne 0 ]; then # Moment Of Truth
    echo -e "\
==ERROR: mscoree.dll wasn't found in $SYSTEM32/.==\n\
==Installing dotnet48 apparently went pear-shaped. Check the logs above.=="
    exit 1
else
    echo "--NOTE-- dotnet48 installed successfully."
fi


d3dcompiler_47
d3d_status=$?

if [ $d3d_status -eq 0 ]; then
    echo "--NOTE-- d3dcompiler_47 installed successfully."
else
    echo -e "\
==ERROR: d3dcompiler_47.dll wasn't found in $SYSTEM32/.==\n\
==Weird, because usually this one's pretty well-behaved? Check the logs.=="
    exit 1
fi

echo -e "--NOTE-- If we got this far, everything should have installed successfully.\n\
You may consider appending something like the following to your ~/.[bash,zsh,fish,etc]rc to make using the prefix easier:\n\n\
alias thwine=\"WINEPREFIX=$WINEPREFIX wine\"\n\
(so then you can just run \"thwine whatever.exe\"\n)\
OKAY GO HAVE FUN BYEEEEE
"
