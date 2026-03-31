[app]
title = foc_studio
project_dir = .
input_file = main.py
exec_directory = deployment
icon = ui/assets/app.ico

[python]
packages = Nuitka==2.7.11
python_path = C:\Users\wallace.zhang\.pyenv\pyenv-win\versions\3.10.11\python.exe

[qt]
qml_files = ui/QMLFiles/CAN.qml,ui/QMLFiles/CHT.qml,ui/QMLFiles/Main.qml,ui/QMLFiles/MOT.qml,ui/QMLFiles/SYS.qml,ui/QMLFiles/TUNE.qml
modules = Core,Graphs,Gui,Qml,SerialPort
plugins = accessiblebridge,egldeviceintegrations,generic,iconengines,imageformats,platforminputcontexts,platforms,platforms/darwin,platformthemes,qmllint,qmltooling,xcbglintegrations

[nuitka]
mode = standalone
extra_args = --quiet --noinclude-qt-translations --static-libpython=no --mingw64 --assume-yes-for-downloads --windows-console-mode=disable

