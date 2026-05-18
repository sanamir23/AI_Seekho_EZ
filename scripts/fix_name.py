path = 'lib/screens/home/home_screen.dart'
with open(path, encoding='utf-8') as f:
    content = f.read()
content = content.replace("text: 'Ahmad'", 'text: _displayName')
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')
