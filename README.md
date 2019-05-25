# Dumb Game Mode

A dumb script to emulate Game Mode.

## Features

* Overheat your AMD CPU
* Overheat your Nvidia GPU
* Annoy you with pop-up notifications
* Useless DXVK/D9VK detectors
* Endless loop
* Wine/Proton ready

## How to use

Just drop it into autostart. Or launch in terminal emulator.


## Configuration

Basic. Just edit file.


## Requirements

* sh
* sleep
* pidof
* (g)awk
* grep
* lsof
* sudo
* ... and many more, I bet you don't have 'em

* cpupower (optional, sudo)
* notify-send (optional)
* nvidia-settings (optional)
* nvidia-smi (optional, disabled, sudo)


## NOTE

Some programs may require `sudo`, add them to the sudoers config file, e.g.

```
username        ALL=(ALL) NOPASSWD: /usr/bin/cpupower
```
or don't use such commands.


## Thanks

Original script was stolen from https://github.com/Lurkki14/gamedetector
