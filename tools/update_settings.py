import os, re

path = os.path.expandvars(r'%APPDATA%\Godot\app_userdata\DroneFlames\settings.cfg')
if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    content = re.sub(r'dev_mode=.*', 'dev_mode=true', content)
    content = re.sub(r'my_money=.*', 'my_money=999999', content)
    content = re.sub(r'my_name=.*', 'my_name="reborn"', content)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Updated user settings.cfg')
