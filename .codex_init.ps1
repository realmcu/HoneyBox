 # Codex Python environment setup
 $pythonDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
 $scriptsDir = "$pythonDir\Scripts"
 $launcherDir = "$env:LOCALAPPDATA\Programs\Python\Launcher"
 
 # Prepend Python paths to PATH (takes priority over WindowsApps)
 $env:Path = "$pythonDir;$scriptsDir;$launcherDir;$env:Path"
 
 # Bypass Windows App Execution Aliases for python and py
 function python { & "$pythonDir\python.exe" @args }
 function py { & "$launcherDir\py.exe" @args }
 Set-Alias pip "$pythonDir\Scripts\pip.exe" -Scope Global
