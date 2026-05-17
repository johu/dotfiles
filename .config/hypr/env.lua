-- session
hl.env('XDG_CURRENT_DESKTOP', 'Hyprland')
hl.env('XDG_SESSION_TYPE', 'wayland')
hl.env('XDG_SESSION_DESKTOP', 'Hyprland')

-- cursor
hl.env('HYPRCURSOR_THEME', 'Bibata-Modern-Ice')
hl.env('HYPRCURSOR_SIZE', '20')
hl.env('XCURSOR_THEME', 'Bibata-Modern-Ice')
hl.env('XCURSOR_SIZE', '20')

-- qt
hl.env('QT_QPA_PLATFORM', 'wayland;xcb')
hl.env('QT_QPA_PLATFORMTHEME', 'qt6ct')
hl.env('QT_WAYLAND_DISABLE_WINDOWDECORATION', '1')
hl.env('QT_AUTO_SCREEN_SCALE_FACTOR', '1')

-- gtk
hl.env('GDK_SCALE', '1')
hl.env('GDK_BACKEND', 'wayland,x11,*')

-- firefox & co
hl.env('MOZ_ENABLE_WAYLAND', 1)

-- chrome & co
hl.env('ELECTRON_OZONE_PLATFORM_HINT', 'wayland')

-- screenshots
hl.env('HYPRSHOT_DIR', 'pics/screenshots')

hl.env(
  'XDG_DATA_DIRS',
  '/usr/local/share:/usr/share:/etc/eselect/wine/share:/usr/share/gdm:/var/lib/flatpak/exports/share:~/.local/share/flatpak/exports/share'
)

hl.config {
  xwayland = {
    force_zero_scaling = true,
  },
  ecosystem = {
    no_update_news = true,
  },
}
