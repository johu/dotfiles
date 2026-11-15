hl.on('hyprland.start', function()
  hl.exec_cmd '/etc/profile.d/flatpak.sh'
  hl.exec_cmd 'systemctl --user start portage-sync.timer'
  hl.exec_cmd '~/.config/hypr/scripts/xdg-desktop-portal.sh'
  hl.exec_cmd '~/.config/hypr/scripts/wallpaper.sh'
  hl.exec_cmd '~/.config/hypr/scripts/cleanup.sh'
  hl.exec_cmd '~/.config/hypr/scripts/apply-qt-theme.sh'
  hl.exec_cmd 'hyprctl setcursor Bibata-Modern-Ice 20'
  hl.exec_cmd 'gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"'
  hl.exec_cmd 'gsettings set org.gnome.desktop.interface cursor-size 20'
end)
