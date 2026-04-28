[README.MD](https://github.com/user-attachments/files/27176524/README.MD)

Sony Meta Warrior B1.3.0

A DaVinci Resolve Lua Script for Sony Camera Metadata
Automatically syncs Sony camera metadata (ISO, FPS, LUT, gamut, shutter, aperture, lens, white balance, and more) into DaVinci Resolve clip properties using a dedicated Rust-based resolver.

Install (macOS)
To ensure the script has permission to move files and execute the resolver binary, you must grant sudo access during installation.

Open Terminal.

Type sudo chmod +x  (make sure there is a space after +x).

Drag the install.sh file from your folder directly into the Terminal window to auto-fill the path.

Press Enter, type your macOS password, and press Enter again.

Now run the installer by draging it again into the terminal, Then press Enter.


Perform a system audit of your DaVinci Resolve Utility folder.

Automatically download the resolver binary from GitHub.

Deploy and rename your Lua script to "Sony Meta Warrior.lua".

Set the necessary execution permissions for the binary.

📦 Package Contents
SonyMetaWarrior/
├── Sony Meta Warrior B1.lua   
├── install.sh                 ← Automated installer
└── README.md                  ← This file
