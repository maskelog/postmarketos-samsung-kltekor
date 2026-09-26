python3 -m py_compile /usr/local/bin/phosh-brightness-bridge.py && echo SYNTAX_OK
python3 -c "import dbus.exceptions; print(dbus.exceptions.NameExistsException)"
