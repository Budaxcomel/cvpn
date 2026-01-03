from regis import bot
from importlib import import_module
from regis.modules import ALL_MODULES

# Import semua modul bot
for module_name in ALL_MODULES:
    import_module("regis.modules." + module_name)

# Jalankan bot
bot.run_until_disconnected()
