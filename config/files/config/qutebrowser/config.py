# Documentation:
#   qute://help/configuring.html
#   qute://help/settings.html

c.aliases = {'q': 'quit', 'w': 'session-save', 'wq': 'quit --save', 'x': 'quit --save', "socks-on":"set content.proxy socks://localhost:9090/", "socks-off":"unset content.proxy", "pop-up":"set content.javascript.can_open_tabs_automatically true"}
c.qt.args = ['ppapi-widevine-path=/usr/lib64/qt5/plugins/ppapi/libwidevinecdmadapter.so']
c.auto_save.session = True

c.content.cookies.accept = 'all'
c.content.geolocation = False
c.content.plugins = True
c.content.headers.referer = 'same-domain'
c.content.headers.user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.230 Safari/537.36'

config.set('content.javascript.enabled', True, 'file://*')
config.set('content.javascript.enabled', True, 'chrome://*/*')
config.set('content.javascript.enabled', True, 'qute://*/*')

c.downloads.location.directory = None
c.editor.command = ['urxvt', '-e', 'vim', '-f', '{file}', '-c', 'normal {line}G{column0}l']
c.spellcheck.languages = ['en-US', 'fr-FR']

c.tabs.background = True
c.tabs.close_mouse_button_on_bar = 'new-tab'
c.tabs.position = 'left'
c.tabs.width = '10%'
c.tabs.min_width = 50
c.tabs.max_width = 150

c.url.default_page = 'https://epheo.eu/empty.html'
c.url.start_pages = 'https://epheo.eu/empty.html'
# c.colors.webpage.bg = 'white'
